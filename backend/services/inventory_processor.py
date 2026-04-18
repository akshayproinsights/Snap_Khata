"""
Inventory processor service with Gemini AI integration.
Uses vendor_gemini prompt for vendor invoice extraction.
"""
import os
import json
import time
import logging
import uuid
from typing import List, Dict, Any, Optional, Callable
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor, as_completed
import threading

from google import genai
from google.genai import types
from PIL import Image
import tempfile

from services.processor import (
    calculate_image_hash,
    RateLimiter,
    calculate_accuracy,
    calculate_cost_inr
)
from services.storage import get_storage_client
from database import get_database_client
from config import get_google_api_key
from config_loader import get_user_config
from utils.date_helpers import normalize_date, format_to_db, get_ist_now_str

logger = logging.getLogger(__name__)

# Rate limiter for API calls — Gemini Flash supports 250+ RPM
limiter = RateLimiter(rpm=int(os.getenv('GEMINI_RPM_LIMIT', '250')))

# Model Configuration  (3-tier cascade: Lite → Flash → Pro)
LITE_MODEL    = "gemini-3.1-flash-lite-preview"   # cheapest / fastest
FLASH_MODEL   = "gemini-3-flash-preview"  # mid-tier
# PRO_MODEL     = "gemini-3.1-pro-preview"    # highest quality
PRO_MODEL     = None # Keeping variable to prevent NameError
ACCURACY_THRESHOLD = 50.0  # escalate if accuracy < 50%

# ── v2.1 Mathematical Processing Engine ──────────────────────────────────────
from decimal import Decimal, ROUND_HALF_UP

TOLERANCE_LIMIT = Decimal('2.00')  # Rs. tolerance for line-total mismatch


def clean_numeric(value) -> Decimal:
    """Convert any currency/numeric string to Decimal. Strips Rs, commas, spaces."""
    if value is None or value == 'N/A' or value == '':
        return Decimal('0')
    if isinstance(value, (int, float, Decimal)):
        return Decimal(str(value))
    cleaned = (
        str(value)
        .replace('\u20b9', '')  # ₹
        .replace('Rs', '').replace('rs', '')
        .replace(',', '').replace(' ', '')
        .strip()
    )
    try:
        return Decimal(cleaned) if cleaned else Decimal('0')
    except Exception:
        return Decimal('0')


def route_combined_gst(item_data: Dict) -> Dict:
    """
    Route COMBINED_GST to CGST+SGST split (always 50/50, intra-state default).
    Phase 1: No inter-state detection — COMBINED_GST always treated as intra-state.
    """
    item = dict(item_data)  # work on a copy, never mutate caller's dict
    if item.get('tax_type') != 'COMBINED_GST':
        return item
    rate = float(item.get('combined_gst_percent', 0) or 0)
    item['tax_type'] = 'CGST_SGST'
    item['cgst_percent'] = rate / 2
    item['sgst_percent'] = rate / 2
    item['igst_percent'] = 0
    return item


def calculate_discounts(
    gross: Decimal, disc_pct: Decimal, disc_amt: Decimal
) -> tuple:
    """
    Resolve discount — always from GROSS amount (not taxable).

    Scenarios:
      - pct only  → compute amount from gross
      - amt only  → back-calculate pct from gross
      - both      → validate; trust extracted amount if mismatch > Rs.1
      - neither   → taxable = gross

    Returns (disc_pct, disc_amt, taxable_amount).
    """
    if disc_pct > 0 and disc_amt == 0:
        disc_amt = (gross * disc_pct / 100).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
    elif disc_amt > 0 and disc_pct == 0:
        disc_pct = (
            (disc_amt / gross * 100).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
            if gross > 0 else Decimal('0')
        )
    elif disc_pct > 0 and disc_amt > 0:
        # Both provided — validate and trust amount if there's a discrepancy
        calculated_amt = (gross * disc_pct / 100).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
        if abs(calculated_amt - disc_amt) > Decimal('1'):
            disc_pct = (
                (disc_amt / gross * 100).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
                if gross > 0 else Decimal('0')
            )

    taxable = (gross - disc_amt).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
    return disc_pct, disc_amt, taxable


def classify_printed_total(
    gross: Decimal,
    taxable: Decimal,
    net: Decimal,
    printed_total: Decimal,
) -> tuple:
    """
    Determine whether the printed line total matches GROSS, TAXABLE, or NET.

    Indian B2B invoices print different values as the per-line "total":
      GROSS    – Qty × Rate (pre-discount, pre-tax). Common in dealer invoices
                 where the discount is a header-level "Part Discount".
      TAXABLE  – After discount, before GST. Seen when GST is shown only in footer.
      NET      – After discount AND after GST. Standard retail/B2C invoices.
      NOT_PRINTED – Vendor did not print a per-line total (printed_total = 0).
                    Backend math is source-of-truth; never flag as mismatch.
      MISMATCH – Printed value doesn't match any candidate within tolerance.
                 Genuine data-entry or OCR error; must be reviewed.

    Returns:
        (mismatch_amount: Decimal, needs_review: bool, match_type: str)
    """
    if printed_total <= 0:
        # Column not visible in image or vendor omitted it — trust our math
        return Decimal('0'), False, 'NOT_PRINTED'

    candidates = [
        (gross,   'GROSS'),
        (taxable, 'TAXABLE'),
        (net,     'NET'),
    ]
    for candidate, label in candidates:
        diff = abs(printed_total - candidate)
        if diff <= TOLERANCE_LIMIT:
            return diff, False, label

    # None of the three candidates match — genuine mismatch
    # Use |net - printed| as the mismatch amount shown in the UI
    return abs(net - printed_total), True, 'MISMATCH'


def process_invoice_item(item_data: Dict) -> Dict:
    """
    Full per-line v2.1 calculation pipeline.

    Handles:
      - COMBINED_GST routing (50/50 CGST/SGST split)
      - Discount from GROSS (not taxable amount)
      - IGST / CGST+SGST / NONE tax paths
      - Missing printed line total (needs_review = False if not printed)

    Returns a dict with v2_ prefixed computed fields and _compat_ fields
    for backward-compatible DB columns.
    """
    # Route combined GST first
    item = route_combined_gst(item_data)

    qty   = clean_numeric(item.get('quantity', 0))
    rate  = clean_numeric(item.get('rate', 0))
    gross = (qty * rate).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)

    # Classify disc_type from ORIGINAL extracted values (before math derives new ones)
    orig_disc_pct = clean_numeric(item.get('disc_percent', 0))
    orig_disc_amt = clean_numeric(item.get('disc_amount', 0))

    if orig_disc_pct > 0 and orig_disc_amt > 0:
        disc_type = 'BOTH'
    elif orig_disc_pct > 0:
        disc_type = 'PERCENT'
    elif orig_disc_amt > 0:
        disc_type = 'AMOUNT'
    else:
        disc_type = 'NONE'

    # Discounts — always from GROSS
    disc_pct, disc_amt, taxable = calculate_discounts(gross, orig_disc_pct, orig_disc_amt)

    # Tax rates
    cgst_pct = clean_numeric(item.get('cgst_percent', 0))
    sgst_pct = clean_numeric(item.get('sgst_percent', 0))
    igst_pct = clean_numeric(item.get('igst_percent', 0))

    cgst_amt = (taxable * cgst_pct / 100).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
    sgst_amt = (taxable * sgst_pct / 100).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
    igst_amt = (taxable * igst_pct / 100).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)

    tax_total  = cgst_amt + sgst_amt + igst_amt
    net_amount = (taxable + tax_total).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)

    # ── Smart printed-total comparison ──────────────────────────────────────
    # Indian invoices print GROSS, TAXABLE, or NET as the per-line total.
    # Blindly comparing net vs printed causes false positives.
    # classify_printed_total() checks all three candidates and only flags a
    # genuine mismatch when the printed value matches none of them.
    # printed_total = 0 → vendor didn't print a line total → NOT_PRINTED, no review.
    printed_total = clean_numeric(item.get('printed_total_amount', 0))
    mismatch, needs_review, printed_total_type = classify_printed_total(
        gross, taxable, net_amount, printed_total
    )

    # Discount type label is already set from original extracted values above

    return {
        # v2 computed fields — stored in extra_fields (Phase 2 will add proper columns)
        'v2_gross_amount':   float(gross),
        'v2_disc_type':      disc_type,
        'v2_disc_percent':   float(disc_pct),
        'v2_disc_amount':    float(disc_amt),
        'v2_taxable_amount': float(taxable),
        'v2_cgst_percent':   float(cgst_pct),
        'v2_cgst_amount':    float(cgst_amt),
        'v2_sgst_percent':   float(sgst_pct),
        'v2_sgst_amount':    float(sgst_amt),
        'v2_igst_percent':   float(igst_pct),
        'v2_igst_amount':    float(igst_amt),
        'v2_net_amount':          float(net_amount),
        'v2_printed_total':       float(printed_total),
        'v2_mismatch_amount':     float(mismatch),
        'v2_needs_review':        needs_review,
        'v2_printed_total_type':  printed_total_type,   # GROSS|TAXABLE|NET|NOT_PRINTED|MISMATCH
        'v2_printed_total_col_header': item_data.get('printed_total_col_header', 'N/A'),  # Fix 3
        'v2_tax_type':            item.get('tax_type', 'UNKNOWN'),
        # Legacy compat values (map to existing DB columns)
        '_compat_disc_percent':   float(disc_pct),
        '_compat_cgst_percent':   float(cgst_pct),
        '_compat_sgst_percent':   float(sgst_pct),
        '_compat_taxable_amount': float(taxable),
        '_compat_net_bill':       float(net_amount),
    }


# ── Gemini client singleton ───────────────────────────────────────────────────
# Thread-safe: genai.Client is stateless and safe to share across threads.
_gemini_client: Optional["genai.Client"] = None
_gemini_client_lock = threading.Lock()

def _get_gemini_client() -> "genai.Client":
    """Return a cached module-level Gemini client (created once, reused everywhere)."""
    global _gemini_client
    if _gemini_client is None:
        with _gemini_client_lock:
            if _gemini_client is None:  # double-checked locking
                api_key = get_google_api_key()
                if not api_key:
                    raise RuntimeError("No Google API key configured")
                _gemini_client = genai.Client(api_key=api_key)
                logger.info("Gemini client singleton created")
    return _gemini_client


def process_vendor_invoice(
    image_bytes: bytes,
    filename: str,
    receipt_link: str,
    username: str
) -> Optional[Dict[str, Any]]:
    """
    Process a vendor invoice image using Gemini AI with vendor_gemini prompt.
    
    Args:
        image_bytes: Image data
        filename: Original filename
        receipt_link: R2 presigned URL
        username: Username for config lookup
        
    Returns:
        Extracted invoice data dictionary or None
    """
    logger.info(f"Processing vendor invoice: {filename}")
    
    # Get user config with vendor_gemini prompt
    user_config = get_user_config(username)
    if not user_config:
        logger.error(f"No config found for user: {username}")
        return None
    
    vendor_prompt = user_config.get("vendor_gemini", {}).get("system_instruction")
    if not vendor_prompt:
        logger.error(f"No vendor_gemini prompt found for user: {username}")
        return None
    
    # Use singleton Gemini client
    try:
        client = _get_gemini_client()
    except RuntimeError as e:
        logger.error(str(e))
        return None

    # Convert bytes to PIL Image
    import io
    img = Image.open(io.BytesIO(image_bytes))

    def _run_model(model_name: str, tier_label: str):
        """Call Gemini and return (extracted_data, items, accuracy, input_tokens, output_tokens, cost_inr)."""
        logger.info(f"Trying {model_name} ({tier_label}) for vendor invoice extraction...")
        try:
            cfg = types.GenerateContentConfig(
                system_instruction=vendor_prompt,
                response_mime_type="application/json",
                temperature=0.1
            )
            # Add timeout to prevent hanging
            resp = client.models.generate_content(
                model=model_name,
                contents=[img, "Extract all vendor invoice data according to the instructions."],
                config=cfg
            )
            json_text = resp.text.strip() if resp.text else "{}"
            
            # Robust JSON cleaning (remove markdown blocks if present)
            json_text = json_text.removeprefix("```json").removeprefix("```").removesuffix("```").strip()

            try:
                data = json.loads(json_text)
            except json.JSONDecodeError:
                preview = str(json_text)
                if len(preview) > 200:
                    preview = preview[:200] + "..."
                logger.error(f"{tier_label}: JSON Decode Error. Response: {preview}")
                return None, [], 0.0, 0, 0, 0.0
            
            # Ensure data is a dictionary
            if not isinstance(data, dict):
                if isinstance(data, list):
                    data = {"invoice_type": "Printed", "invoice_date": "", "invoice_number": "", "items": data}
                else:
                    data = {"invoice_type": "Printed", "invoice_date": "", "invoice_number": "", "items": []}
            
            # Ensure data is a dictionary for the linter and safe access
            working_data: Dict[str, Any] = data if isinstance(data, dict) else {}
            
            _items = working_data.get("items", [])
            acc = calculate_accuracy(_items)

            # Quality checks
            hdr = working_data.get("header", {}) if isinstance(working_data.get("header"), dict) else {}
            vname = working_data.get("vendor_name", "") or hdr.get("vendor_name", "")
            if not vname or not str(vname).strip():
                logger.warning(f"{tier_label}: Missing Vendor Name — forcing escalation.")
                # We don't set acc=0 here anymore, let the specific check handle it
                # to allow returning partial data if Pro also fails
            
            if _items:
                valid = sum(
                    1 for it in _items
                    if isinstance(it, dict) and (
                        (str(it.get("description", "")).strip() and str(it.get("description", "")).strip().lower() != "n/a")
                        or (str(it.get("part_number", "")).strip() and str(it.get("part_number", "")).strip().lower() != "n/a")
                    )
                )
                if valid == 0:
                    logger.warning(f"{tier_label}: All items empty/N/A — forcing escalation.")
                    acc = min(acc, 30.0) # Penalty for no items

            usage = resp.usage_metadata
            in_tok  = (usage.prompt_token_count or 0) if usage else 0
            out_tok = (usage.candidates_token_count or 0) if usage else 0
            cost    = calculate_cost_inr(in_tok, out_tok, model_name)
            return data, _items, acc, in_tok, out_tok, cost
        except Exception as e:
            logger.error(f"Error in _run_model for {tier_label}: {e}")
            return None, [], 0.0, 0, 0, 0.0

    try:
        best_res_stored: Optional[Dict[str, Any]] = None
        accuracy = 0.0
        
        # ── Tier 1: Lite ──────────────────────────────────
        try:
            l_data, l_items, l_acc, l_in, l_out, l_cost = _run_model(LITE_MODEL, "Lite")
            if l_data:
                extracted_data, items, accuracy, input_tokens, output_tokens, cost_inr = \
                    l_data, l_items, l_acc, l_in, l_out, l_cost
                model_used = "Lite"
                best_res_stored = {
                    "data": l_data, "items": l_items, "acc": l_acc,
                    "in": l_in, "out": l_out, "cost": l_cost, "model": "Lite"
                }
        except Exception as e:
            logger.error(f"Lite tier crash: {e}")
            # Ensure accuracy is initialized for the next tier check
            accuracy = 0.0

        # ── Tier 2: Flash (if Lite failed or accuracy < threshold) ────────────
        if accuracy < ACCURACY_THRESHOLD or not best_res_stored:
            logger.warning(f"Lite finished with {accuracy}% accuracy. Escalating to Flash...")
            try:
                f_data, f_items, f_acc, f_in, f_out, f_cost = _run_model(FLASH_MODEL, "Flash")
                if f_data:
                    extracted_data, items, accuracy, input_tokens, output_tokens, cost_inr = \
                        f_data, f_items, f_acc, f_in, f_out, f_cost
                    model_used = "Flash"
                    best_res_stored = {
                        "data": f_data, "items": f_items, "acc": f_acc,
                        "in": f_in, "out": f_out, "cost": f_cost, "model": "Flash"
                    }
            except Exception as e:
                logger.error(f"Flash tier crash: {e}")

        if not best_res_stored:
            logger.error("All models (Lite, Flash) failed to return a result.")
            return None

        # Re-assign from best result for consistency
        extracted_data = best_res_stored["data"]
        items = best_res_stored["items"]
        accuracy = best_res_stored["acc"]
        input_tokens = best_res_stored["in"]
        output_tokens = best_res_stored["out"]
        cost_inr = best_res_stored["cost"]
        model_used = best_res_stored["model"]

        total_tokens = input_tokens + output_tokens
        
        # Transform to match expected format
        result = {
            "header": {
                "invoice_type": extracted_data.get("invoice_type", "Printed"),
                "invoice_number": extracted_data.get("invoice_number", ""),
                "date": extracted_data.get("invoice_date", ""),
                "vendor_name": extracted_data.get("vendor_name", ""),
                # v2.1 new header fields
                "vendor_gstin": extracted_data.get("vendor_gstin"),
                "place_of_supply": extracted_data.get("place_of_supply"),
                "tax_type": extracted_data.get("tax_type", "UNKNOWN"),
                "header_adjustments": extracted_data.get("header_adjustments", []),
                "source_file": filename
            },
            "items": items,
            "receipt_link": receipt_link,
            "upload_date": get_ist_now_str(),
            "model_used": model_used,
            "model_accuracy": accuracy,
            "input_tokens": input_tokens,
            "output_tokens": output_tokens,
            "total_tokens": total_tokens,
            "cost_inr": cost_inr
        }
        
        logger.info(f"✓ Vendor invoice processed: {filename} (Model: {model_used}, Accuracy: {accuracy}%)")
        return result
        
    except Exception as e:
        logger.error(f"Error processing vendor invoice {filename}: {e}")
        import traceback
        logger.error(f"Traceback: {traceback.format_exc()}")
        return None

def convert_to_inventory_rows(
    invoice_data: Dict[str, Any],
    username: str,
    image_hash: str  # Add image_hash parameter
) -> List[Dict[str, Any]]:
    """
    Convert extracted invoice data to inventory_items table rows.
    Similar to convert_to_dataframe_rows but for inventory schema.
    
    Args:
        invoice_data: Extracted data from Gemini
        username: Username for RLS
        image_hash: Image hash for duplicate detection
        
    Returns:
        List of row dictionaries for inventory_items table
    """
    header = invoice_data.get("header", {})
    items = invoice_data.get("items", [])
    receipt_link = invoice_data.get("receipt_link", "")
    upload_date = invoice_data.get("upload_date", "")
    
    # Model metadata
    model_used = invoice_data.get("model_used", "")
    model_accuracy = invoice_data.get("model_accuracy", 0.0)
    input_tokens = invoice_data.get("input_tokens", 0)
    output_tokens = invoice_data.get("output_tokens", 0)
    total_tokens = invoice_data.get("total_tokens", 0)
    cost_inr = invoice_data.get("cost_inr", 0.0)
    
    # Get user config
    user_config = get_user_config(username)
    if not user_config:
        logger.error(f"No config found for user: {username}")
        return []
    
    # Normalize date
    raw_date = header.get("date", "")
    normalized_date = normalize_date(raw_date)
    if normalized_date:
        date_to_store = format_to_db(normalized_date)
    elif raw_date and raw_date.strip():
        date_to_store = raw_date
    else:
        date_to_store = None
    
    def safe_float(val: Any, default: float = 0.0) -> float:
        """Safely convert to float"""
        if val is None or val == "" or val == "N/A":
            return float(default)
        try:
            return float(val)
        except (ValueError, TypeError):
            return float(default)
    
    # BBOX DISABLED: Bbox extraction removed from Gemini prompt to speed up processing.
    # DB columns are kept intact (receiving NULL) so they can be re-enabled without schema changes.
    # To re-enable: restore bbox fields in vendor_gemini prompt + uncomment get_bbox_json below.
    # --- BBOX CODE (commented out, not deleted) ---
    # def get_bbox_json(data_dict, field_name):
    #     """Extract bbox and convert to JSON, or None if missing"""
    #     bbox = data_dict.get(f"{field_name}_bbox")
    #     if bbox and isinstance(bbox, dict):
    #         return bbox
    #     return None

    # Invoice-level v2 fields from header
    vendor_gstin      = header.get('vendor_gstin')
    place_of_supply   = header.get('place_of_supply')
    invoice_tax_type  = header.get('tax_type', 'UNKNOWN')
    header_adjustments = header.get('header_adjustments', [])

    rows = []
    for idx, item in enumerate(items):
        if not isinstance(item, dict):
            continue

        # ── v2.1 Math Engine ─────────────────────────────────────────────────
        # Stamp each item with invoice-level tax_type if item doesn't have one
        if 'tax_type' not in item or not item.get('tax_type'):
            item = dict(item)  # copy before mutating
            item['tax_type'] = invoice_tax_type

        v2 = process_invoice_item(item)

        # ── Compat values for existing DB columns ─────────────────────────────
        qty              = safe_float(item.get('quantity'), 1.0)
        rate             = safe_float(item.get('rate'), 0.0)
        disc_percent     = v2['_compat_disc_percent']
        cgst_percent     = v2['_compat_cgst_percent']
        sgst_percent     = v2['_compat_sgst_percent']
        taxable_amount   = v2['_compat_taxable_amount']
        net_bill         = v2['_compat_net_bill']

        # Legacy mismatch column: reuse v2 value
        amount_mismatch  = v2['v2_mismatch_amount']

        # discounted_price / taxed_amount for legacy schema columns
        discounted_price = taxable_amount  # after disc, pre-tax
        taxed_amount_col = (cgst_percent + sgst_percent) * discounted_price / 100

        invoice_type = str(header.get('invoice_type', 'Printed'))

        # Build inventory row
        unique_id = str(uuid.uuid4()).split('-')[0]
        row_id = f"{str(image_hash):.8}_{unique_id}_{idx}"

        row = {
            # System columns
            'row_id':        row_id,
            'username':      username,
            'industry_type': user_config.get('industry', ''),
            'image_hash':    image_hash,

            # File information
            'source_file':  header.get('source_file', ''),
            'receipt_link': receipt_link,

            # Invoice header
            'invoice_type':   invoice_type,
            'invoice_date':   date_to_store,
            'invoice_number': header.get('invoice_number', ''),
            'vendor_name':    header.get('vendor_name', ''),

            # Line item details
            'part_number': item.get('part_number', 'N/A'),
            'batch':       item.get('batch', 'N/A'),
            'description': item.get('description', ''),
            # v2 prompts output 'hsn_code'; fall back to 'hsn' for old rows
            'hsn': item.get('hsn_code') or item.get('hsn', 'N/A'),

            # Quantities and pricing (compat columns)
            'qty':             qty,
            'rate':            rate,
            'disc_percent':    disc_percent,
            'taxable_amount':  taxable_amount,

            # Tax (compat columns)
            'cgst_percent': cgst_percent,
            'sgst_percent': sgst_percent,

            # Calculated compat columns
            'discounted_price': int(round(discounted_price)),
            'taxed_amount':     int(round(taxed_amount_col)),
            'net_bill':         int(round(net_bill)),
            'amount_mismatch':  int(round(amount_mismatch)),

            # AI model tracking
            'model_used':     model_used,
            'model_accuracy': model_accuracy,
            'input_tokens':   input_tokens,
            'output_tokens':  output_tokens,
            'total_tokens':   total_tokens,
            'cost_inr':       cost_inr,
            'accuracy_score': item.get('confidence', 0),
            'row_accuracy':   item.get('confidence', 0),

            # BBOX DISABLED: preserved as NULL for future re-enable
            'part_number_bbox':    None,
            'batch_bbox':          None,
            'description_bbox':    None,
            'hsn_bbox':            None,
            'qty_bbox':            None,
            'rate_bbox':           None,
            'disc_percent_bbox':   None,
            'taxable_amount_bbox': None,
            'cgst_percent_bbox':   None,
            'sgst_percent_bbox':   None,
            'line_item_row_bbox':  None,

            # ── v2.1 dedicated columns (migration 043 applied) ───────────────
            'gross_amount':    v2['v2_gross_amount'],
            'disc_type':       v2['v2_disc_type'],
            'disc_amount':     v2['v2_disc_amount'],
            'igst_percent':    v2['v2_igst_percent'],
            'igst_amount':     v2['v2_igst_amount'],
            'cgst_amount':     v2['v2_cgst_amount'],
            'sgst_amount':     v2['v2_sgst_amount'],
            'net_amount':      v2['v2_net_amount'],
            'printed_total':   v2['v2_printed_total'],
            'mismatch_amount': v2['v2_mismatch_amount'],
            'needs_review':    v2['v2_needs_review'],
            'tax_type':        v2['v2_tax_type'],
            'vendor_gstin':    vendor_gstin,
            'place_of_supply': place_of_supply,
            'header_adjustments': header_adjustments,

            # ── v2.1 dedicated columns (migration 044 added) ─────────────────
            # Canonical HSN column (v2 prompt uses 'hsn_code'; legacy stored as 'hsn')
            'hsn_code':        item.get('hsn_code') or item.get('hsn') or None,
            # Explicit taxable base (gross − discount), used for tax calculation
            'taxable_amount':  v2['v2_taxable_amount'],
            # AI confidence per line item (0–100)
            'confidence_score': int(item.get('confidence', 0) or 0),
        }

        # ── extra_fields: v2 data + any unrecognised Gemini fields ───────────
        standard_item_keys = {
            'part_number', 'batch', 'description', 'hsn', 'hsn_code',
            'quantity', 'rate', 'amount',
            'disc_percent', 'disc_amount',
            'cgst_percent', 'sgst_percent', 'igst_percent',
            'combined_gst_percent', 'printed_total_amount', 'printed_total_col_header',
            'tax_type', 'unit', 'confidence',
        }
        standard_header_keys = {
            'invoice_type', 'invoice_date', 'invoice_number',
            'vendor_name', 'vendor_gstin', 'place_of_supply',
            'tax_type', 'header_adjustments', 'source_file',
        }

        item_extra   = {k: v for k, v in item.items() if k not in standard_item_keys and not k.endswith('_bbox')}
        header_extra = {k: v for k, v in header.items() if k not in standard_header_keys and not k.endswith('_bbox')}

        # v2 computed fields — prefixed with v2_ to avoid collision
        v2_fields = {k: v for k, v in v2.items() if k.startswith('v2_')}

        # Invoice-level v2 fields
        invoice_v2 = {
            'v2_vendor_gstin':      vendor_gstin,
            'v2_place_of_supply':   place_of_supply,
            'v2_header_adjustments': header_adjustments,
        }

        row['extra_fields'] = {**header_extra, **item_extra, **v2_fields, **invoice_v2}
        rows.append(row)

    return rows


def _build_adjustment_rows(
    rows: List[Dict[str, Any]], username: str
) -> List[Dict[str, Any]]:
    """
    Derive invoice_adjustments table rows from inventory item rows.

    Each item row carries header_adjustments (list of dicts) that came from the
    Gemini-extracted HeaderAdjustment objects.  We de-duplicate by (username,
    invoice_number, adjustment_type, amount) so that multi-line invoices don't
    produce repeated adjustment rows. 
    """
    seen: set = set()
    adj_rows: List[Dict[str, Any]] = []

    for row in rows:
        adjustments = row.get('header_adjustments') or []
        if not adjustments or not isinstance(adjustments, list):
            continue

        invoice_number = row.get('invoice_number') or ''
        invoice_date   = row.get('invoice_date')  # may be None
        image_hash     = row.get('image_hash', '')

        for adj in adjustments:
            if not isinstance(adj, dict):
                continue
            adj_type = str(adj.get('adjustment_type', '')).strip().upper()
            if adj_type not in ('HEADER_DISCOUNT', 'ROUND_OFF', 'SCHEME', 'OTHER'):
                continue
            try:
                amount = float(adj.get('amount', 0) or 0)
            except (ValueError, TypeError):
                continue

            dedup_key = (username, invoice_number, adj_type, amount)
            if dedup_key in seen:
                continue
            seen.add(dedup_key)

            adj_rows.append({
                'username':        username,
                'invoice_number':  invoice_number,
                'invoice_date':    invoice_date,
                'image_hash':      image_hash,
                'adjustment_type': adj_type,
                'amount':          amount,
                'description':     str(adj.get('description', '') or ''),
            })

    return adj_rows


def save_to_inventory_table(rows: List[Dict[str, Any]], username: str):
    """
    Save inventory rows to Supabase inventory_items table, and persist any
    header-level adjustments to the invoice_adjustments table.

    Args:
        rows: List of inventory item dictionaries (output of convert_to_inventory_rows)
        username: Username for RLS
    """
    if not rows:
        logger.warning("No rows to save to inventory_items")
        return

    try:
        db = get_database_client()

        # ── 1. Insert line items ─────────────────────────────────────────────
        db.client.table("inventory_items").insert(rows).execute()
        logger.info(f"✓ Saved {len(rows)} rows to inventory_items table")

        # ── 2. Persist header adjustments (invoice_adjustments table) ────────
        adj_rows = _build_adjustment_rows(rows, username)
        if adj_rows:
            try:
                db.client.table("invoice_adjustments").insert(adj_rows).execute()
                logger.info(
                    f"✓ Saved {len(adj_rows)} header adjustment(s) "
                    f"to invoice_adjustments table"
                )
            except Exception as adj_err:
                # Non-fatal: log and continue — line items are already saved.
                # invoice_adjustments can be backfilled later via migration 044.
                logger.warning(
                    f"Could not save invoice_adjustments (table may not exist yet): "
                    f"{adj_err}"
                )

    except Exception as e:
        logger.error(f"Error saving to inventory_items: {e}")
        raise


def process_single_inventory_item(
    file_key: str,
    r2_bucket: str,
    username: str,
    force_upload: bool
) -> Dict[str, Any]:
    """
    Process a single inventory item (helper for parallel processing).

    FIX-3: Duplicate check is merged here — no separate pre-scan pass.
    Each image is downloaded exactly once. If it's a duplicate it is
    skipped (auto-skip) — the caller accumulates the count for the
    final status message.

    Returns a result dictionary:
      success    – True on processed or auto-skipped duplicate
      skipped    – True if this was a duplicate that was auto-skipped
      duplicate  – dict with info about the existing record (if skipped)
      error      – str error message on failure
    """
    storage = get_storage_client()
    db = get_database_client()

    result: Dict[str, Any] = {
        "success": False,
        "skipped": False,
        "file_key": file_key,
        "error": None,
        "duplicate": None,
    }

    try:
        # Download image from R2 — only once (FIX-3: no separate pre-scan)
        image_bytes = storage.download_file(r2_bucket, file_key)
        if not image_bytes:
            raise Exception(f"Failed to download file from R2: {file_key}")

        # Calculate image hash for duplicate detection
        img_hash = calculate_image_hash(image_bytes)

        if force_upload:
            # Overwrite mode: delete existing records with this hash first
            logger.info(f"Force upload: deleting existing items with hash {img_hash}")
            db.client.table("inventory_items") \
                .delete() \
                .eq("image_hash", img_hash) \
                .eq("username", username) \
                .execute()
        else:
            # Auto-skip duplicates: check hash, skip without calling Gemini
            dup_check = db.client.table("inventory_items") \
                .select("id,invoice_number,invoice_date,receipt_link,upload_date,part_number,description") \
                .eq("image_hash", img_hash) \
                .eq("username", username) \
                .limit(1) \
                .execute()

            if dup_check.data and isinstance(dup_check.data, list) and len(dup_check.data) > 0:
                existing = dup_check.data[0]
                upload_date = existing.get("upload_date") if isinstance(existing, dict) else None
                date_msg = f"already uploaded on {upload_date}" if upload_date else "already uploaded previously"
                logger.info(f"Auto-skipping duplicate {file_key} (hash={img_hash[:8]}…)")
                result["success"] = True
                result["skipped"] = True
                result["duplicate"] = {
                    "file_key": file_key,
                    "image_hash": img_hash,
                    "existing_record": existing,
                    "message": f"This vendor invoice was {date_msg}",
                }
                return result

        # Generate permanent public URL for receipt link
        receipt_link = storage.get_public_url(r2_bucket, file_key)
        if not receipt_link:
            logger.warning(f"No public URL for {file_key}, using r2:// path")
            receipt_link = f"r2://{r2_bucket}/{file_key}"

        # Process with Gemini AI using VENDOR prompt
        invoice_data = process_vendor_invoice(
            image_bytes=image_bytes,
            filename=file_key.split('/')[-1],
            receipt_link=receipt_link,
            username=username,
        )

        if not invoice_data:
            raise Exception("Gemini processing returned no data")

        # Convert to inventory rows and save
        inventory_rows = convert_to_inventory_rows(invoice_data, username, img_hash)
        if not inventory_rows:
            raise Exception("No inventory rows generated from extracted data")

        save_to_inventory_table(inventory_rows, username)

        result["success"] = True
        logger.info(f"✓ Processed inventory item: {file_key}")

    except Exception as e:
        error_msg = f"Failed to process {file_key}: {str(e)}"
        result["error"] = error_msg
        logger.error(error_msg)

    return result



# check_inventory_item_duplicate is no longer used — duplicate detection
# is now merged into process_single_inventory_item (FIX-3: single download).
# Kept as a no-op stub so any external callers don't break.
def check_inventory_item_duplicate(
    file_key: str,
    r2_bucket: str,
    username: str,
) -> Optional[Dict[str, Any]]:
    """Deprecated: duplicate check is now inlined in process_single_inventory_item."""
    logger.warning("check_inventory_item_duplicate called — this is deprecated.")
    return None


def process_inventory_batch(
    file_keys: List[str],
    r2_bucket: str,
    username: str,
    progress_callback: Optional[Callable[[int, int, int, str], None]] = None,
    force_upload: bool = False,
) -> Dict[str, Any]:
    """
    Process a batch of inventory images with Gemini AI using parallel execution.

    FIX-3: No separate pre-scan pass. Duplicate detection is inlined into
    process_single_inventory_item, which downloads each image exactly once.
    Duplicates are auto-skipped — processing continues for non-duplicate
    images. The caller receives 'skipped_count' and 'skipped_duplicates'
    so the UI can display a summary at the end.

    Args:
        file_keys: List of R2 file keys to process
        r2_bucket: R2 bucket name
        username: Username for config and RLS
        progress_callback: Optional callback(current_index, failed, total, file_key)
        force_upload: If True, overwrite existing duplicates

    Returns:
        Dictionary with keys: processed, failed, skipped_count,
        skipped_duplicates, errors, duplicates (empty list for compat)
    """
    max_workers = int(os.getenv('INVENTORY_MAX_WORKERS', '50'))
    logger.info(
        f"Starting inventory batch processing: {len(file_keys)} files, "
        f"{max_workers} workers, force_upload={force_upload}"
    )

    counters: Dict[str, int] = {"processed": 0, "failed": 0, "skipped_count": 0, "completed_count": 0}
    skipped_duplicates: List[Dict[str, Any]] = []
    errors: List[str] = []

    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        future_to_file = {
            executor.submit(
                process_single_inventory_item,  # type: ignore
                file_key,
                r2_bucket,
                username,
                force_upload,
            ): file_key
            for file_key in file_keys
        }

        for future in as_completed(future_to_file):
            counters["completed_count"] += 1
            file_key = future_to_file[future]
            try:
                result = future.result()

                if result.get("skipped"):
                    # Auto-skipped duplicate — accumulate for summary
                    counters["skipped_count"] += 1
                    if result.get("duplicate"):
                        skipped_duplicates.append(result["duplicate"])
                    logger.info(f"Skipped duplicate: {file_key}")

                elif result.get("success"):
                    counters["processed"] += 1

                else:
                    counters["failed"] += 1
                    if result.get("error"):
                        errors.append(result["error"])

            except Exception as exc:
                logger.error(f"Exception for {file_key}: {exc}")
                counters["failed"] += 1
                errors.append(f"System error processing {file_key}: {str(exc)}")

            cb = progress_callback
            if cb is not None:
                cb(counters["completed_count"], counters["failed"], len(file_keys), file_key)

    results = {
        "processed": counters["processed"],
        "failed": counters["failed"],
        "skipped_count": counters["skipped_count"],
        "skipped_duplicates": skipped_duplicates,
        "errors": errors,
        "duplicates": [],  # kept for backward-compat; always empty now (no blocking)
        "total": len(file_keys),
    }

    logger.info(
        f"Batch done: {counters['processed']} processed, {counters['skipped_count']} skipped (duplicates), "
        f"{counters['failed']} failed"
    )
    return results
