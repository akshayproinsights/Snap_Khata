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

# Model Configuration
PRIMARY_MODEL = "gemini-3-flash-preview"
FALLBACK_MODEL = "gemini-3-pro-preview"
ACCURACY_THRESHOLD = 50.0  # Switch to Pro if accuracy < 50%

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

    try:
        # Try with Flash model first
        logger.info(f"Trying {PRIMARY_MODEL} for vendor invoice extraction...")
        
        config = types.GenerateContentConfig(
            system_instruction=vendor_prompt,
            response_mime_type="application/json",
            temperature=0.1
        )
        
        response = client.models.generate_content(
            model=PRIMARY_MODEL,
            contents=[img, "Extract all vendor invoice data according to the instructions."],
            config=config
        )
        
        # Parse response
        json_text = response.text.strip() if response.text else "{}"
        extracted_data = json.loads(json_text)
        
        # Handle case where Gemini returns just the items array instead of full structure
        if isinstance(extracted_data, list):
            extracted_data = {
                "invoice_type": "Printed",
                "invoice_date": "",
                "invoice_number": "",
                "items": extracted_data
            }
        
        # Calculate accuracy
        items = extracted_data.get("items", [])
        accuracy = calculate_accuracy(items)
        
        # QUALITY CHECK: Penalize if critical fields are missing
        # This handles cases where Flash returns a valid JSON but with empty fields/template
        header = extracted_data.get("header", {}) if isinstance(extracted_data.get("header"), dict) else {}
        vendor_name = extracted_data.get("vendor_name", "") or header.get("vendor_name", "")
        # Note: invoice_number might be missing on some valid bills, but vendor_name is critical for stock
        
        if not vendor_name or not str(vendor_name).strip():
            logger.warning("Quality Check Failed: Missing Vendor Name. Forcing fallback to Pro model.")
            accuracy = 0.0
            
        # Also check if we have items but they are empty "N/A" placeholders
        if items:
            valid_items = 0
            for item in items:
                if isinstance(item, dict):
                    desc = str(item.get("description", "")).strip()
                    part = str(item.get("part_number", "")).strip()
                    if desc and desc.lower() != "n/a" or part and part.lower() != "n/a":
                        valid_items += 1
            
            if valid_items == 0:
                logger.warning("Quality Check Failed: Items found but all appear empty/N/A. Forcing fallback.")
                accuracy = 0.0
        
        # Get token usage
        usage = response.usage_metadata
        input_tokens = (usage.prompt_token_count or 0) if usage else 0
        output_tokens = (usage.candidates_token_count or 0) if usage else 0
        total_tokens = input_tokens + output_tokens
        
        # Calculate cost
        cost_inr = calculate_cost_inr(input_tokens, output_tokens, "Flash")
        
        model_used = "Flash"
        
        # Fallback to Pro if accuracy is low
        if accuracy < ACCURACY_THRESHOLD:
            logger.warning(f"Flash accuracy ({accuracy}%) < {ACCURACY_THRESHOLD}%, falling back to Pro model...")
            
            config_pro = types.GenerateContentConfig(
                system_instruction=vendor_prompt,
                response_mime_type="application/json",
                temperature=0.1
            )
            
            response_pro = client.models.generate_content(
                model=FALLBACK_MODEL,
                contents=[img, "Extract all vendor invoice data according to the instructions."],
                config=config_pro
            )
            
            json_text = response_pro.text.strip() if response_pro.text else "{}"
            extracted_data = json.loads(json_text)
            
            # Handle case where Pro model also returns just the items array
            if isinstance(extracted_data, list):
                extracted_data = {
                    "invoice_type": "Printed",
                    "invoice_date": "",
                    "invoice_number": "",
                    "items": extracted_data
                }
            
            # Recalculate with Pro model
            items = extracted_data.get("items", [])
            accuracy = calculate_accuracy(items)
            
            usage_pro = response_pro.usage_metadata
            input_tokens = (usage_pro.prompt_token_count or 0) if usage_pro else 0
            output_tokens = (usage_pro.candidates_token_count or 0) if usage_pro else 0
            total_tokens = input_tokens + output_tokens
            cost_inr = calculate_cost_inr(input_tokens, output_tokens, "Pro")
            
            model_used = "Pro"
            logger.info(f"Pro model accuracy: {accuracy}%")
        
        # Transform to match expected format
        result = {
            "header": {
                "invoice_type": extracted_data.get("invoice_type", "Printed"),
                "invoice_number": extracted_data.get("invoice_number", ""),
                "date": extracted_data.get("invoice_date", ""),
                "vendor_name": extracted_data.get("vendor_name", ""),
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
    
    def get_bbox_json(data_dict, field_name):
        """Extract bbox and convert to JSON, or None if missing"""
        bbox = data_dict.get(f"{field_name}_bbox")
        if bbox and isinstance(bbox, dict):
            return bbox
        return None
    
    rows = []
    for idx, item in enumerate(items):
        if not isinstance(item, dict):
            continue
        qty = safe_float(item.get("quantity"), 1.0)
        rate = safe_float(item.get("rate"), 0.0)
        taxable_amount = safe_float(item.get("amount"), 0.0)
        
        # Calculate derived fields
        disc_percent = safe_float(item.get("disc_percent"), 0.0)
        cgst_percent = safe_float(item.get("cgst_percent"), 0.0)
        sgst_percent = safe_float(item.get("sgst_percent"), 0.0)
        
        discounted_price = ((100 - disc_percent) * taxable_amount) / 100
        taxed_amount = (cgst_percent + sgst_percent) * discounted_price / 100
        net_bill = discounted_price + taxed_amount
        
        # Calculate amount mismatch (for printed invoices)
        invoice_type = str(header.get("invoice_type", "Printed"))
        amount_mismatch: float = 0.0
        if invoice_type.lower() == "printed":
            calc_amount = qty * rate
            amount_mismatch = float(abs(calc_amount - taxable_amount))
        
        # Build inventory row
        # Generate unique row_id: use UUID to prevent any collisions
        # Format: first 8 chars of image_hash + UUID + index for traceability
        unique_id = str(uuid.uuid4()).split('-')[0]
        row_id = f"{str(image_hash):.8}_{unique_id}_{idx}"
        
        row = {
            # System columns
            "row_id": row_id,
            "username": username,
            "industry_type": user_config.get("industry", ""),
            "image_hash": image_hash,  # Add image hash for duplicate detection
            
            # File information
            "source_file": header.get("source_file", ""),
            "receipt_link": receipt_link,
            
            # Invoice header
            "invoice_type": invoice_type,
            "invoice_date": date_to_store,
            "invoice_number": header.get("invoice_number", ""),
            "vendor_name": header.get("vendor_name", ""),
            
            # Line item details
            "part_number": item.get("part_number", "N/A"),
            "batch": item.get("batch", "N/A"),
            "description": item.get("description", ""),
            "hsn": item.get("hsn", "N/A"),
            
            # Quantities and pricing
            "qty": qty,
            "rate": rate,
            "disc_percent": disc_percent,
            "taxable_amount": taxable_amount,
            
            # Tax information
            "cgst_percent": cgst_percent,
            "sgst_percent": sgst_percent,
            
            # Calculated fields
            "discounted_price": float(f"{discounted_price:.2f}"),
            "taxed_amount": float(f"{taxed_amount:.2f}"),
            "net_bill": float(f"{net_bill:.2f}"),
            "amount_mismatch": float(f"{amount_mismatch:.2f}"),
            
            # AI model tracking
            "model_used": model_used,
            "model_accuracy": model_accuracy,
            "input_tokens": input_tokens,
            "output_tokens": output_tokens,
            "total_tokens": total_tokens,
            "cost_inr": cost_inr,
            "accuracy_score": item.get("confidence", 0),
            "row_accuracy": item.get("confidence", 0),
            
            # Bounding boxes
            "part_number_bbox": get_bbox_json(item, "part_number"),
            "batch_bbox": get_bbox_json(item, "batch"),
            "description_bbox": get_bbox_json(item, "description"),
            "hsn_bbox": get_bbox_json(item, "hsn"),
            "qty_bbox": get_bbox_json(item, "quantity"),
            "rate_bbox": get_bbox_json(item, "rate"),
            "disc_percent_bbox": get_bbox_json(item, "disc_percent"),
            "taxable_amount_bbox": get_bbox_json(item, "amount"),
            "cgst_percent_bbox": get_bbox_json(item, "cgst_percent"),
            "sgst_percent_bbox": get_bbox_json(item, "sgst_percent"),
            "line_item_row_bbox": get_bbox_json(item, "line_item_row"),
        }
        
        rows.append(row)
    
    return rows


def save_to_inventory_table(rows: List[Dict[str, Any]], username: str):
    """
    Save inventory rows to Supabase inventory_items table.
    
    Args:
        rows: List of inventory item dictionaries
        username: Username for RLS
    """
    if not rows:
        logger.warning("No rows to save to inventory_items")
        return
    
    try:
        db = get_database_client()
        
        # Insert all rows
        response = db.client.table("inventory_items").insert(rows).execute()
        
        logger.info(f"✓ Saved {len(rows)} rows to inventory_items table")
        
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
    progress_callback: Optional[Callable] = None,
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
                process_single_inventory_item,
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

            if progress_callback:
                progress_callback(counters["completed_count"], counters["failed"], len(file_keys), file_key)

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
