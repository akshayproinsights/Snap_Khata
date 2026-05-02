import base64
import hashlib
import hmac
import os
import time
from fastapi import APIRouter, Depends, HTTPException
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

        # ── 3. Fall back to customer_ledgers (account statements) ─────────────────
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
        if username:
            try:
                profile_response = db.client.from_("user_profiles") \
                    .select("shop_name, shop_address, shop_phone, shop_gst") \
                    .eq("username", username) \
                    .limit(1) \
                    .execute()
                if profile_response.data and len(profile_response.data) > 0:
                    profile_data = profile_response.data[0]
                    shop_name = profile_data.get("shop_name") or shop_name
                    shop_address = profile_data.get("shop_address") or ""
                    shop_phone = profile_data.get("shop_phone") or ""
                    shop_gst = profile_data.get("shop_gst") or ""
            except Exception:
                pass  # stay as default

        status_val = header.get("verification_status")
        status_str = str(status_val).lower() if status_val else ""
        is_paid = status_str in ["done", "paid", "confirmed"]
        
        if source_table == "verified_invoices":
            is_paid = True
        
        if source_table == "customer_ledgers":
            is_paid = float(header.get("balance_due", 0)) <= 0

        # ── Line items ────────────────────────────────────────────────────────────
        items = []
        total_from_items = 0.0

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

        elif source_table == "customer_ledgers":
            try:
                # Fetch transactions for the ledger
                trans_query = db.client.from_("ledger_transactions") \
                    .select("*") \
                    .eq("ledger_id", receipt_number) \
                    .order("transaction_date", desc=True)
                trans_resp = trans_query.execute()
                transactions = trans_resp.data or []
                
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

        # ── Final Response ────────────────────────────────────────────────────────
        return {
            "id": receipt_number,
            "type": "ledger" if source_table == "customer_ledgers" else "receipt",
            "username": username,
            "shop_name": shop_name,
            "shop_address": shop_address,
            "shop_phone": shop_phone,
            "shop_gst": shop_gst,
            "customer_name": header.get("customer_name") or "Walk-in Customer",
            "customer_phone": header.get("customer_phone"),
            "vehicle_number": header.get("vehicle_number"),
            "odometer_reading": header.get("odometer_reading"),
            "created_at": header.get("created_at") or header.get("transaction_date"),
            "status": "PAID" if is_paid else "UNPAID",
            "items": items,
            "total_amount": total_from_items,
            "received_amount": header.get("received_amount") if source_table != "customer_ledgers" else None,
            "balance_due": header.get("balance_due"),
            "industry": header.get("industry") or "general",
            "gst_mode": header.get("gst_mode") or "none"
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching public receipt {receipt_number}: {str(e)}")
        import traceback
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail="Failed to fetch receipt data")
