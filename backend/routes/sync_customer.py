from datetime import datetime
from typing import Dict, Any
import logging
from database import get_database_client

logger = logging.getLogger(__name__)

async def sync_customer_ledgers_from_invoices(current_user: Dict):
    """
    Reconcile customer_ledgers against verified_invoices.
    Scans all Credit verified_invoices with balance_due > 0 and ensures
    a matching customer_ledger + INVOICE transaction exists.
    """
    username = current_user.get("username")
    if not username:
        return

    db = get_database_client()
    db.set_user_context(username)

    try:
        # 1. Fetch all Credit invoices with outstanding balance
        invoices_resp = db.client.table("verified_invoices") \
            .select("id, receipt_number, customer_name, customer_details, balance_due, verification_date") \
            .eq("username", username) \
            .eq("payment_mode", "Credit") \
            .gt("balance_due", 0) \
            .execute()

        invoices = invoices_resp.data or []
        if not invoices:
            return

        receipt_numbers = [inv["receipt_number"] for inv in invoices if inv.get("receipt_number")]

        # 2. Fetch existing INVOICE transactions
        existing_tx_resp = db.client.table("ledger_transactions") \
            .select("receipt_number") \
            .eq("username", username) \
            .eq("transaction_type", "INVOICE") \
            .in_("receipt_number", receipt_numbers) \
            .execute()

        already_synced = {tx["receipt_number"] for tx in (existing_tx_resp.data or []) if tx.get("receipt_number")}

        # 3. Only process invoices not yet fully synced
        missing_invoices = [
            inv for inv in invoices
            if inv.get("receipt_number") and inv["receipt_number"] not in already_synced
        ]

        if not missing_invoices:
            return

        # 4. Fetch existing customer ledgers
        ledgers_resp = db.client.table("customer_ledgers") \
            .select("id, customer_name, balance_due") \
            .eq("username", username) \
            .execute()

        ledger_map: Dict[str, Dict] = {}
        for row in (ledgers_resp.data or []):
            ledger_map[str(row["customer_name"]).strip().lower()] = row

        now = datetime.utcnow().isoformat()
        
        for inv in missing_invoices:
            raw_name = str(inv.get("customer_name") or "").strip()
            raw_details = str(inv.get("customer_details") or "").strip()
            
            if not raw_name or raw_name.lower() in ['unknown', 'unknown customer', 'cash customer', '—', '-', 'null']:
                customer_name_raw = raw_details if raw_details else raw_name
            else:
                customer_name_raw = raw_name

            if not customer_name_raw:
                continue

            customer_key = customer_name_raw.lower()
            balance_due = float(inv.get("balance_due") or 0)

            if customer_key in ledger_map:
                ledger = ledger_map[customer_key]
                ledger_id = ledger["id"]
                new_balance = float(ledger.get("balance_due") or 0) + balance_due
                db.client.table("customer_ledgers").update({
                    "balance_due": new_balance,
                    "updated_at": now,
                }).eq("id", ledger_id).execute()
                ledger_map[customer_key]["balance_due"] = new_balance
            else:
                new_ledger_resp = db.client.table("customer_ledgers").insert({
                    "username": username,
                    "customer_name": customer_name_raw,
                    "balance_due": balance_due,
                }).execute()

                if not new_ledger_resp.data:
                    continue

                ledger_id = new_ledger_resp.data[0]["id"]
                ledger_map[customer_key] = {
                    "id": ledger_id,
                    "customer_name": customer_name_raw,
                    "balance_due": balance_due,
                }

            db.client.table("ledger_transactions").insert({
                "username": username,
                "ledger_id": ledger_id,
                "transaction_type": "INVOICE",
                "amount": balance_due,
                "receipt_number": inv["receipt_number"],
                "is_paid": False,
                "created_at": inv.get("verification_date") or now,
                "notes": raw_details,
            }).execute()

    except Exception as e:
        logger.error(f"Error syncing customer ledgers from invoices: {e}")
