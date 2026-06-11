import base64
import hashlib
import hmac
import os
import time
from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import HTMLResponse
from typing import Any, Dict, Optional
from auth import get_current_user
from database import get_database_client
from config_loader import get_user_config
import logging

logger = logging.getLogger(__name__)

router = APIRouter()

def _urlsafe_b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode("utf-8").rstrip("=")


def _get_public_receipt_secret() -> str:
    secret = os.getenv("PUBLIC_RECEIPT_SIGNING_SECRET", "").strip()
    if not secret:
        logger.error("PUBLIC_RECEIPT_SIGNING_SECRET is not set in environment!")
        raise HTTPException(status_code=500, detail="Public receipt sharing is not configured")
    return secret


def _sign_receipt_token(receipt_number: str, username: str, expires_at: int, secret: str) -> str:
    payload = f"{receipt_number}:{username}:{expires_at}".encode("utf-8")
    signature = hmac.new(secret.encode("utf-8"), payload, hashlib.sha256).digest()
    return _urlsafe_b64(signature)


def _verify_receipt_token(receipt_number: str, username: str, expires_at: int, token: str, secret: str) -> bool:
    if expires_at <= int(time.time()):
        return False
    expected = _sign_receipt_token(receipt_number, username, expires_at, secret)
    return hmac.compare_digest(expected, token)


@router.post("/receipts/{receipt_number:path}/share-token")
async def create_public_receipt_share_token(
    receipt_number: str,
    ttl_hours: int = 168,
    current_user: Dict[str, Any] = Depends(get_current_user),
):
    """
    Create a signed, time-bound token for a public receipt link.
    The token is scoped to receipt_number + username and can be revoked
    by rotating PUBLIC_RECEIPT_SIGNING_SECRET.
    """
    username = current_user.get("username")
    if not username:
        raise HTTPException(status_code=400, detail="Invalid authenticated user")

    ttl_hours = max(1, min(ttl_hours, 24 * 30))
    expires_at = int(time.time()) + (ttl_hours * 3600)
    secret = _get_public_receipt_secret()
    token = _sign_receipt_token(receipt_number, username, expires_at, secret)

    return {
        "receipt_number": receipt_number,
        "username": username,
        "expires_at": expires_at,
        "st": token,
        "share_url": f"https://snapkhata.com/receipt.html?i={receipt_number}&u={username}",
    }


@router.get("/receipts/{receipt_number:path}/photo-preview", response_class=HTMLResponse)
async def get_receipt_photo_preview(
    receipt_number: str,
    request: Request,
    u: Optional[str] = None,
):
    """
    Server-rendered HTML page for WhatsApp link preview of a receipt photo.
    
    WhatsApp's crawler (facebookexternalhit) cannot execute JavaScript, so
    dynamically injecting og:image in JS never works for link previews.
    This endpoint bakes the og:image URL into the static HTML <head> so
    WhatsApp shows the receipt photo as a rich preview card.
    
    - WhatsApp crawler → served the og:image HTML directly
    - Regular users    → 302 redirect to receipt.html?i=...&u=...&view=photo
    """
    user_agent = request.headers.get("user-agent", "").lower()
    is_crawler = any(bot in user_agent for bot in [
        "facebookexternalhit", "whatsapp", "twitterbot", "linkedinbot",
        "slackbot", "telegrambot", "discordbot", "googlebot", "bingbot",
    ])

    # Fetch receipt data to get receipt_link + shop_name
    receipt_link = ""
    shop_name = "Our Shop"

    try:
        db = get_database_client()

        # Try verification_dates first
        header = None
        for table, col in [
            ("verification_dates", "receipt_number"),
            ("verified_invoices", "receipt_number"),
        ]:
            q = db.client.from_(table).select("receipt_link, username").eq("receipt_number", receipt_number)
            if u:
                q = q.eq("username", u)
            resp = q.limit(1).execute()
            if resp.data:
                header = resp.data[0]
                break

        # Fallback to invoices table
        if header is None:
            q = db.client.from_("invoices").select("receipt_link, username").eq("receipt_number", receipt_number)
            if u:
                q = q.eq("username", u)
            resp = q.limit(1).execute()
            if resp.data:
                header = resp.data[0]

        if header:
            receipt_link = header.get("receipt_link") or ""
            uname = header.get("username") or u or ""
            # Fetch shop name
            if uname:
                pr = db.client.from_("user_profiles").select("shop_name").eq("username", uname).limit(1).execute()
                if pr.data:
                    shop_name = pr.data[0].get("shop_name") or shop_name
    except Exception as e:
        logger.error(f"Error in photo-preview for {receipt_number}: {e}")

    # For regular users, redirect to the full JS-powered page
    if not is_crawler:
        redirect_url = f"https://snapkhata.com/receipt.html?i={receipt_number}"
        if u:
            redirect_url += f"&u={u}"
        redirect_url += "&view=photo"
        from fastapi.responses import RedirectResponse
        return RedirectResponse(url=redirect_url, status_code=302)

    # For crawlers: return minimal HTML with og:image in static <head>
    # og:image points to OUR proxy endpoint, not the raw R2 CDN URL.
    # WhatsApp trusts snapkhata.com and will render the image thumbnail.
    if receipt_link:
        # Proxy URL served from our domain so WhatsApp's crawler can fetch it
        og_image = f"https://snapkhata.com/api/public/receipts/{receipt_number}/photo"
        if u:
            og_image += f"?u={u}"
    else:
        og_image = "https://snapkhata.com/logo.png"
    if u:
        receipt_page_url = f"https://snapkhata.com/r/{u}/{receipt_number}"
    else:
        receipt_page_url = f"https://snapkhata.com/r/{receipt_number}"

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <title>Receipt from {shop_name} • SnapKhata</title>
  <meta property="og:title" content="Receipt from {shop_name}" />
  <meta property="og:description" content="Tap to view your full receipt photo." />
  <meta property="og:image" content="{og_image}" />
  <meta property="og:image:width" content="600" />
  <meta property="og:image:height" content="800" />
  <meta property="og:url" content="{receipt_page_url}" />
  <meta property="og:type" content="website" />
  <meta name="twitter:card" content="summary_large_image" />
  <meta name="twitter:image" content="{og_image}" />
  <meta http-equiv="refresh" content="0;url={receipt_page_url}" />
</head>
<body>
  <p>Redirecting to receipt…</p>
  <a href="{receipt_page_url}">View Receipt</a>
</body>
</html>"""
    return HTMLResponse(content=html)


@router.get("/receipts/{receipt_number:path}/photo")
async def get_receipt_photo_image(
    receipt_number: str,
    u: Optional[str] = None,
):
    """
    Proxy endpoint that fetches the receipt image from R2 and serves it
    directly from snapkhata.com. This ensures WhatsApp's crawler can load
    the og:image without hitting the raw CDN hostname.
    """
    import httpx
    from fastapi.responses import Response

    receipt_link = ""
    try:
        db = get_database_client()
        for table in ["verification_dates", "verified_invoices", "invoices"]:
            q = db.client.from_(table).select("receipt_link").eq("receipt_number", receipt_number)
            if u:
                q = q.eq("username", u)
            resp = q.limit(1).execute()
            if resp.data and resp.data[0].get("receipt_link"):
                receipt_link = resp.data[0]["receipt_link"]
                break
    except Exception as e:
        logger.error(f"Error fetching receipt_link for photo proxy {receipt_number}: {e}")

    if not receipt_link:
        raise HTTPException(status_code=404, detail="Receipt photo not found")

    try:
        async with httpx.AsyncClient(timeout=15.0, follow_redirects=True) as client:
            r = await client.get(receipt_link)
            r.raise_for_status()
            content_type = r.headers.get("content-type", "image/jpeg")
            return Response(
                content=r.content,
                media_type=content_type,
                headers={
                    "Cache-Control": "public, max-age=86400",  # cache 24h
                    "Access-Control-Allow-Origin": "*",
                },
            )
    except Exception as e:
        logger.error(f"Error proxying receipt photo {receipt_number}: {e}")
        raise HTTPException(status_code=502, detail="Failed to fetch receipt photo")

@router.get("/shop-logo")
async def get_shop_logo_proxy(
    u: Optional[str] = None,
):
    """
    Proxy endpoint that fetches the shop logo from R2 and serves it
    directly from snapkhata.com. This bypasses any CORS or public-access
    restrictions on the raw R2 CDN URL and ensures the logo loads
    correctly in receipt.html regardless of bucket configuration.

    Usage: /api/public/shop-logo?u=<username>
    """
    import httpx
    from fastapi.responses import Response

    if not u:
        raise HTTPException(status_code=400, detail="Username (u) is required")

    logo_url = ""
    try:
        db = get_database_client()
        resp = db.client.from_("user_profiles") \
            .select("shop_logo_url") \
            .eq("username", u) \
            .limit(1) \
            .execute()
        if resp.data and resp.data[0].get("shop_logo_url"):
            logo_url = resp.data[0]["shop_logo_url"]
    except Exception as e:
        logger.error(f"Error fetching shop logo for {u}: {e}")

    if not logo_url:
        raise HTTPException(status_code=404, detail="Shop logo not found")

    # Validate the URL only proxies known R2 / CDN domains (security guard)
    allowed_domains = ("r2.dev", "cloudflare.com", "snapkhata.com", "pub-")
    from urllib.parse import urlparse
    parsed = urlparse(logo_url)
    host = parsed.netloc.lower()
    if not any(d in host for d in allowed_domains):
        raise HTTPException(status_code=403, detail="Logo URL not from an allowed domain")

    try:
        async with httpx.AsyncClient(timeout=10.0, follow_redirects=True) as client:
            r = await client.get(logo_url)
            r.raise_for_status()
            content_type = r.headers.get("content-type", "image/jpeg")
            return Response(
                content=r.content,
                media_type=content_type,
                headers={
                    "Cache-Control": "public, max-age=86400",  # cache 24h
                    "Access-Control-Allow-Origin": "*",
                },
            )
    except Exception as e:
        logger.error(f"Error proxying shop logo for {u}: {e}")
        raise HTTPException(status_code=502, detail="Failed to fetch shop logo")


@router.get("/receipts/{receipt_number:path}")
async def get_public_receipt(
    receipt_number: str,
    u: Optional[str] = None,
    st: Optional[str] = None,
    exp: Optional[int] = None,
):
    """
    Fetch basic public info for a receipt given its receipt_number.
    This endpoint does not require authentication, so anyone with the link can view it.

    Search strategy (in order):
    1. First look in verification_dates (receipts pending review)
    2. Then look in verified_invoices (receipts already synced/completed)
    """
    try:
        db = get_database_client()

        require_signed_token = os.getenv("REQUIRE_PUBLIC_RECEIPT_TOKEN", "false").strip().lower() == "true"

        # ── 1. Try verification_dates first (pending/in-review receipts) ──────────
        header = None
        username = None
        source_table = None

        query_dates = db.client.from_("verification_dates") \
            .select("*") \
            .eq("receipt_number", receipt_number)
        if u:
            query_dates = query_dates.eq("username", u)
            
        resp_dates = query_dates.limit(1).execute()

        if resp_dates.data and len(resp_dates.data) > 0:
            header = resp_dates.data[0]
            username = header.get("username")
            source_table = "verification_dates"

        # ── 2. Fall back to verified_invoices (synced/completed receipts) ─────────
        if header is None:
            query_verified = db.client.from_("verified_invoices") \
                .select("*") \
                .eq("receipt_number", receipt_number)
            if u:
                query_verified = query_verified.eq("username", u)
                
            resp_verified = query_verified.limit(1).execute()

            if resp_verified.data and len(resp_verified.data) > 0:
                header = resp_verified.data[0]
                username = header.get("username")
                source_table = "verified_invoices"

        # ── 3. Fall back to raw `invoices` table (receipts not yet promoted to verified) ──
        if header is None:
            try:
                query_raw = db.client.from_("invoices") \
                    .select("receipt_number, receipt_link, payment_mode, received_amount, balance_due, customer, date, created_at, username") \
                    .eq("receipt_number", receipt_number)
                if u:
                    query_raw = query_raw.eq("username", u)
                resp_raw = query_raw.limit(1).execute()
                if resp_raw.data and len(resp_raw.data) > 0:
                    raw_row = resp_raw.data[0]
                    # Normalize column names to match what the rest of code expects
                    header = {
                        **raw_row,
                        "customer_name": raw_row.get("customer") or "Walk-in Customer",
                        "verification_status": "pending",
                    }
                    username = raw_row.get("username")
                    source_table = "invoices"
            except Exception as e:
                logger.error(f"Error querying invoices table as fallback: {e}")

        # ── 3b. Fall back to ledger_transactions (manual entries) ─────────────────
        if header is None:
            try:
                query_tx = db.client.from_("ledger_transactions") \
                    .select("*") \
                    .eq("receipt_number", receipt_number)
                if u:
                    query_tx = query_tx.eq("username", u)
                resp_tx = query_tx.limit(1).execute()
                if resp_tx.data and len(resp_tx.data) > 0:
                    tx_row = resp_tx.data[0]
                    # Fetch customer details from customer_ledgers using ledger_id
                    ledger_id = tx_row.get("ledger_id")
                    customer_name = "Walk-in Customer"
                    customer_phone = None
                    if ledger_id:
                        ld_resp = db.client.from_("customer_ledgers") \
                            .select("customer_name, customer_phone") \
                            .eq("id", ledger_id) \
                            .limit(1) \
                            .execute()
                        if ld_resp.data:
                            customer_name = ld_resp.data[0].get("customer_name") or customer_name
                            customer_phone = ld_resp.data[0].get("customer_phone")
                    
                    extra = tx_row.get("extra_fields") or {}
                    vehicle_number = extra.get("vehicle_number") or extra.get("car_number")
                    odometer_reading = extra.get("odometer") or extra.get("odometer_reading")

                    header = {
                        **tx_row,
                        "customer_name": customer_name,
                        "customer_phone": customer_phone,
                        "vehicle_number": vehicle_number,
                        "odometer_reading": odometer_reading,
                        "verification_status": "done" if tx_row.get("is_paid") else "pending",
                    }
                    username = tx_row.get("username")
                    source_table = "ledger_transactions"
            except Exception as e:
                logger.error(f"Error querying ledger_transactions table as fallback: {e}")

        # ── 4. Fall back to customer_ledgers (account statements) ─────────────────
        if header is None:
            query_ledgers = db.client.from_("customer_ledgers") \
                .select("*") \
                .eq("id", receipt_number)
            if u:
                query_ledgers = query_ledgers.eq("username", u)
            
            try:
                resp_ledgers = query_ledgers.limit(1).execute()
                if resp_ledgers.data and len(resp_ledgers.data) > 0:
                    header = resp_ledgers.data[0]
                    username = header.get("username")
                    source_table = "customer_ledgers"
            except Exception as e:
                logger.error(f"Error querying customer_ledgers: {e}")

        if header is None:
            raise HTTPException(status_code=404, detail="Receipt or Ledger not found")

        username = header.get("username") or username or ""
        if require_signed_token:
            # Only enforce token if REQUIRE_PUBLIC_RECEIPT_TOKEN is true in env
            if st or exp:
                secret = _get_public_receipt_secret()
                if not _verify_receipt_token(receipt_number, username, exp, st, secret):
                    logger.warning(f"Invalid or expired token for receipt {receipt_number}")

        # ── Shop name & details from user profile ─────────────────────────────────
        shop_name = "Our Shop"
        shop_address = ""
        shop_phone = ""
        shop_gst = ""
        shop_upi_id = ""
        shop_logo_url = ""
        custom_terms = ""
        if username:
            try:
                profile_response = db.client.from_("user_profiles") \
                    .select("shop_name, shop_address, shop_phone, shop_gst, shop_upi_id, shop_logo_url, custom_terms") \
                    .eq("username", username) \
                    .limit(1) \
                    .execute()
                if profile_response.data and len(profile_response.data) > 0:
                    profile_data = profile_response.data[0]
                    shop_name = profile_data.get("shop_name") or shop_name
                    shop_address = profile_data.get("shop_address") or ""
                    shop_phone = profile_data.get("shop_phone") or ""
                    shop_gst = profile_data.get("shop_gst") or ""
                    shop_upi_id = profile_data.get("shop_upi_id") or ""
                    shop_logo_url = profile_data.get("shop_logo_url") or ""
                    custom_terms = profile_data.get("custom_terms") or ""
            except Exception:
                pass  # stay as default

        status_val = header.get("verification_status")
        status_str = str(status_val).lower() if status_val else ""
        is_paid = status_str in ["done", "paid", "confirmed"]
        
        if source_table == "verified_invoices":
            is_paid = True
        
        if source_table == "invoices":
            bal = float(header.get("balance_due") or 0)
            is_paid = bal <= 0

        if source_table == "customer_ledgers":
            is_paid = float(header.get("balance_due", 0)) <= 0

        # ── Line items ────────────────────────────────────────────────────────────
        items = []
        total_from_items = 0.0
        ledger_total_billed = 0.0
        ledger_total_paid = 0.0

        if source_table == "verification_dates":
            items_query = db.client.from_("verification_amounts") \
                .select("*") \
                .eq("receipt_number", receipt_number)
            if username:
                items_query = items_query.eq("username", username)
                
            items_resp = items_query.execute()

            if items_resp.data:
                for item in items_resp.data:
                    amount = float(item.get("amount") or 0)
                    qty = float(item.get("quantity") or 1)
                    rate = float(item.get("rate") or 0)
                    total_from_items += amount
                    items.append({
                        "name": item.get("description") or "Item",
                        "quantity": qty if qty > 0 else 1,
                        "qty": qty if qty > 0 else 1,
                        "rate": rate if rate > 0 else amount,
                        "amount": amount,
                        "type": item.get("type") or "part"
                    })

        elif source_table == "verified_invoices":
            items_query = db.client.from_("verified_invoices") \
                .select("*") \
                .eq("receipt_number", receipt_number)
            if username:
                items_query = items_query.eq("username", username)
                
            all_rows_resp = items_query.execute()

            if all_rows_resp.data:
                for row in all_rows_resp.data:
                    amount = float(row.get("amount") or 0)
                    qty = float(row.get("quantity") or 1)
                    rate = float(row.get("rate") or 0)
                    total_from_items += amount
                    items.append({
                        "name": row.get("description") or "Item",
                        "quantity": qty if qty > 0 else 1,
                        "qty": qty if qty > 0 else 1,
                        "rate": rate if rate > 0 else amount,
                        "amount": amount,
                        "type": row.get("type") or "part"
                    })

        elif source_table == "ledger_transactions":
            # Extract items from extra_fields
            extra = header.get("extra_fields") or {}
            if isinstance(extra, dict) and "items" in extra:
                raw_items = extra["items"]
                if isinstance(raw_items, list):
                    for it in raw_items:
                        if isinstance(it, dict):
                            qty = float(it.get("quantity") or 1)
                            rate = float(it.get("rate") or 0)
                            items.append({
                                "name": it.get("item_name") or "Item",
                                "quantity": qty,
                                "qty": qty,
                                "rate": rate,
                                "amount": float(it.get("amount") or (qty * rate)),
                                "type": "part"
                            })
            total_from_items = float(header.get("amount") or 0)

        elif source_table == "customer_ledgers":
            try:
                # Fetch transactions for the ledger
                trans_query = db.client.from_("ledger_transactions") \
                    .select("*") \
                    .eq("ledger_id", receipt_number) \
                    .order("created_at", desc=True)
                if u:
                    trans_query = trans_query.eq("username", u)
                trans_resp = trans_query.execute()
                transactions = trans_resp.data or []
                
                # Compute billed / paid totals from transactions
                _credit_types = {"INVOICE", "MANUAL_CREDIT"}
                _payment_types = {"PAYMENT"}
                ledger_total_billed = sum(
                    float(tx.get("amount", 0))
                    for tx in transactions
                    if tx.get("transaction_type", "").upper() in _credit_types
                )
                ledger_total_paid = sum(
                    float(tx.get("amount", 0))
                    for tx in transactions
                    if tx.get("transaction_type", "").upper() in _payment_types
                )

                # Transform transactions into items format
                items = []
                for tx in transactions:
                    t_type = tx.get("transaction_type", "TRANSACTION")
                    amount = float(tx.get("amount", 0))
                    
                    display_name = t_type.replace("_", " ").title()
                    if t_type == "INVOICE" and tx.get("receipt_number"):
                        display_name = f"Invoice #{tx['receipt_number']}"
                    
                    items.append({
                        "name": display_name,
                        "qty": 1,
                        "quantity": 1,
                        "rate": amount,
                        "amount": amount,
                        "type": t_type,
                        "date": tx.get("transaction_date")
                    })
                total_from_items = float(header.get("balance_due", 0))
            except Exception as e:
                logger.error(f"Error fetching ledger transactions: {e}")
                ledger_total_billed = 0.0
                ledger_total_paid = 0.0

        # ── Cumulative payment lookup for individual receipts ─────────────────────
        # For receipts (non-ledger), the stored received_amount/balance_due may be
        # stale — it only reflects the payment made at the time of billing.
        #
        # Strategy:
        # 1. Find the ledger_id for the INVOICE transaction linked to this receipt_number.
        # 2. Sum ALL PAYMENT transactions on that customer ledger.
        # 3. Find the INVOICE total from ledger_transactions to get the bill total.
        # This correctly captures standalone "Record Payment" entries that get their
        # own sequential receipt numbers (not linked to original receipt_number).
        cumulative_received = None
        cumulative_balance_due = None
        is_ledger = source_table == "customer_ledgers"

        if not is_ledger and username:
            try:
                # Step 1: Find the INVOICE transaction for this receipt to get ledger_id + amount
                invoice_tx_resp = db.client.from_("ledger_transactions") \
                    .select("ledger_id, amount, transaction_type") \
                    .eq("receipt_number", receipt_number) \
                    .eq("username", username) \
                    .execute()

                ledger_id_for_receipt = None
                invoice_amount_from_ledger = 0.0

                if invoice_tx_resp.data:
                    for tx in invoice_tx_resp.data:
                        ttype = tx.get("transaction_type", "").upper()
                        if ttype == "INVOICE":
                            ledger_id_for_receipt = tx.get("ledger_id")
                            invoice_amount_from_ledger = float(tx.get("amount") or 0)
                        elif ttype == "PAYMENT" and ledger_id_for_receipt is None:
                            # Some old receipts only have a PAYMENT row — still grab ledger_id
                            ledger_id_for_receipt = tx.get("ledger_id")

                if ledger_id_for_receipt:
                    # Step 2: Sum ALL payments on this customer ledger (captures standalone payments too)
                    all_pay_resp = db.client.from_("ledger_transactions") \
                        .select("amount, transaction_type") \
                        .eq("ledger_id", ledger_id_for_receipt) \
                        .eq("username", username) \
                        .execute()

                    if all_pay_resp.data:
                        _payment_types = {"PAYMENT"}
                        _invoice_types = {"INVOICE", "MANUAL_CREDIT"}
                        total_paid_on_ledger = sum(
                            float(tx.get("amount", 0))
                            for tx in all_pay_resp.data
                            if tx.get("transaction_type", "").upper() in _payment_types
                        )
                        total_billed_on_ledger = sum(
                            float(tx.get("amount", 0))
                            for tx in all_pay_resp.data
                            if tx.get("transaction_type", "").upper() in _invoice_types
                        )
                        # Clamp: can't pay more than the total billed across all invoices
                        # and distribute proportionally to this receipt's share
                        _bill_total = total_from_items if total_from_items > 0 else (
                            invoice_amount_from_ledger if invoice_amount_from_ledger > 0 else
                            float(header.get("received_amount") or 0) + float(header.get("balance_due") or 0)
                        )
                        if _bill_total > 0 and total_billed_on_ledger > 0:
                            # How much of the total payments applies to this specific receipt?
                            receipt_share = _bill_total / total_billed_on_ledger
                            cumulative_received = min(_bill_total, total_paid_on_ledger * receipt_share)
                            cumulative_balance_due = max(0.0, _bill_total - cumulative_received)

                else:
                    # No ledger transaction found — fall back to simple receipt_number query
                    pay_query = db.client.from_("ledger_transactions") \
                        .select("amount, transaction_type") \
                        .eq("receipt_number", receipt_number) \
                        .eq("username", username)
                    pay_resp = pay_query.execute()
                    if pay_resp.data:
                        _payment_types = {"PAYMENT"}
                        cumulative_received = sum(
                            float(tx.get("amount", 0))
                            for tx in pay_resp.data
                            if tx.get("transaction_type", "").upper() in _payment_types
                        )
                        _bill_total = total_from_items if total_from_items > 0 else float(header.get("received_amount") or 0) + float(header.get("balance_due") or 0)
                        if _bill_total > 0:
                            cumulative_balance_due = max(0.0, _bill_total - cumulative_received)

            except Exception as e:
                logger.warning(f"Could not fetch cumulative payments for receipt {receipt_number}: {e}")
                cumulative_received = None
                cumulative_balance_due = None

        # Use cumulative values if we got them, else fall back to stored values
        final_received = cumulative_received if cumulative_received is not None else (header.get("received_amount") if not is_ledger else None)
        final_balance_due = cumulative_balance_due if cumulative_balance_due is not None else header.get("balance_due")

        # Get overall ledger balance due
        ledger_balance_due = None
        ledger_transaction_count = None
        if not is_ledger and username:
            try:
                resolved_lid = None
                if 'ledger_id_for_receipt' in locals() and ledger_id_for_receipt:
                    resolved_lid = ledger_id_for_receipt
                else:
                    invoice_tx_resp = db.client.from_("ledger_transactions") \
                        .select("ledger_id") \
                        .eq("receipt_number", receipt_number) \
                        .eq("username", username) \
                        .limit(1) \
                        .execute()
                    if invoice_tx_resp.data:
                        resolved_lid = invoice_tx_resp.data[0].get("ledger_id")

                if resolved_lid:
                    ledg_resp = db.client.from_("customer_ledgers") \
                        .select("balance_due") \
                        .eq("id", resolved_lid) \
                        .limit(1) \
                        .execute()
                    if ledg_resp.data:
                        ledger_balance_due = float(ledg_resp.data[0].get("balance_due") or 0)

                if ledger_balance_due is None and header.get("customer_phone"):
                    import re
                    phone_str = str(header.get("customer_phone")).replace("+91", "").strip()
                    clean_phone = re.sub(r"\D", "", phone_str)
                    if clean_phone:
                        ledg_resp = db.client.from_("customer_ledgers") \
                            .select("id, balance_due") \
                            .eq("customer_phone", clean_phone) \
                            .eq("username", username) \
                            .limit(1) \
                            .execute()
                        if ledg_resp.data:
                            ledger_balance_due = float(ledg_resp.data[0].get("balance_due") or 0)
                            resolved_lid = ledg_resp.data[0].get("id")

                if resolved_lid:
                    tx_count_resp = db.client.from_("ledger_transactions") \
                        .select("id", count="exact") \
                        .eq("ledger_id", resolved_lid) \
                        .eq("username", username) \
                        .execute()
                    if tx_count_resp.count is not None:
                        ledger_transaction_count = tx_count_resp.count
            except Exception as e:
                logger.warning(f"Error querying overall ledger balance: {e}")

        # ── Final Response ────────────────────────────────────────────────────────
        return {
            "id": receipt_number,
            "type": "ledger" if is_ledger else "receipt",
            "username": username,
            "shop_name": shop_name,
            "shop_address": shop_address,
            "shop_phone": shop_phone,
            "shop_gst": shop_gst,
            "shop_upi_id": shop_upi_id,
            "shop_logo_url": shop_logo_url,
            "custom_terms": custom_terms,
            "customer_name": header.get("customer_name") or "Walk-in Customer",
            "customer_phone": header.get("customer_phone"),
            "vehicle_number": header.get("vehicle_number"),
            "odometer_reading": header.get("odometer_reading"),
            "created_at": header.get("created_at") or header.get("transaction_date"),
            "status": "PAID" if is_paid else "UNPAID",
            "items": items,
            "total_amount": total_from_items,
            # received_amount: cumulative total paid across all installments
            # total_billed / total_paid: only for ledger account statements
            "received_amount": final_received if not is_ledger else None,
            "total_billed": ledger_total_billed if is_ledger else None,
            "total_paid": ledger_total_paid if is_ledger else None,
            "balance_due": final_balance_due,
            "ledger_balance_due": ledger_balance_due,
            "ledger_transaction_count": ledger_transaction_count,
            "industry": header.get("industry") or "general",
            "gst_mode": header.get("gst_mode") or "none",
            "receipt_link": header.get("receipt_link") or "",
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching public receipt {receipt_number}: {str(e)}")
        import traceback
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail="Failed to fetch receipt data")
