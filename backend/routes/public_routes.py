from fastapi import APIRouter, HTTPException
from database import get_database_client

router = APIRouter()

@router.get("/receipts/{receipt_number}")
async def get_public_receipt(receipt_number: str, u: str = None):
    """
    Fetch basic public info for a receipt given its receipt_number.
    This endpoint does not require authentication, so anyone with the link can view it.

    Search strategy (in order):
    1. First look in verification_dates (receipts pending review)
    2. Then look in verified_invoices (receipts already synced/completed)
    """
    try:
        db = get_database_client()

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

        if header is None:
            raise HTTPException(status_code=404, detail="Receipt not found")

        # ── Shop name & details from user profile ─────────────────────────────────
        shop_name = "Business Name"
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
        # Receipts in verified_invoices are always considered paid/done
        if source_table == "verified_invoices":
            is_paid = True

        # ── Line items ────────────────────────────────────────────────────────────
        # For verification_dates source, items live in verification_amounts.
        # For verified_invoices source, each row IS a line item — group by receipt_number.
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
                        "qty": qty if qty > 0 else 1,
                        "rate": rate if rate > 0 else amount,
                        "amount": amount,
                        "type": item.get("type") or "part"
                    })

        else:  # verified_invoices — fetch ALL rows for this receipt number
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
                        "qty": qty if qty > 0 else 1,
                        "rate": rate if rate > 0 else amount,
                        "amount": amount,
                        "type": row.get("type") or "part"
                    })

        # ── Total amount ──────────────────────────────────────────────────────────
        total_amount = float(header.get("amount") or 0) or total_from_items

        # ── Date ──────────────────────────────────────────────────────────────────
        display_date = (
            header.get("date")
            or header.get("upload_date")
            or header.get("created_at")
        )

        calc_received = total_amount - float(header.get("balance_due") or 0.0)
        received_amount = float(header.get("received_amount") or 0.0)
        if received_amount <= 0:
            received_amount = calc_received if calc_received > 0 else 0.0

        return {
            "id": header.get("receipt_number"),
            "customer_name": header.get("customer_name") or "Customer",
            "customer_phone": header.get("mobile_number") or "",
            "total_amount": total_amount,
            "paid_amount": total_amount if is_paid else 0,
            "status": "PAID" if is_paid else "PENDING",
            "created_at": display_date,
            "vehicle_number": header.get("vehicle_number") or "",
            "odometer_reading": header.get("odometer") or "",
            "balance_due": float(header.get("balance_due") or 0.0),
            "payment_mode": header.get("payment_mode") or "Cash",
            "received_amount": received_amount,
            "shop_name": shop_name,
            "shop_address": shop_address,
            "shop_phone": shop_phone,
            "shop_gst": shop_gst,
            "gst_mode": header.get("gst_mode") or "none",
            "items": items
        }

    except HTTPException:
        raise
    except Exception as e:
        print(f"Error fetching public receipt {receipt_number}: {str(e)}")
        raise HTTPException(status_code=500, detail="Failed to fetch receipt data")
