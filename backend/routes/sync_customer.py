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

async def sync_galla_transactions_from_invoices(current_user: Dict):
    """
    Reconcile galla_transactions against verified_invoices.
    Scans all Cash verified_invoices and ensures a matching CASH_SALE transaction exists.
    Updates amount if there's a discrepancy.
    """
    username = current_user.get("username")
    if not username:
        return

    db = get_database_client()
    db.set_user_context(username)

    try:
        # 1. Fetch all Cash invoices
        invoices_resp = db.client.table("verified_invoices") \
            .select("id, receipt_number, total_bill_amount, amount, balance_due, received_amount, verification_date, created_at") \
            .eq("username", username) \
            .eq("payment_mode", "Cash") \
            .execute()

        invoices = invoices_resp.data or []
        if not invoices:
            return

        # Need to group by receipt_number to get authoritative grand_total
        grouped_invoices = {}
        for inv in invoices:
            rn = inv.get("receipt_number")
            if not rn:
                continue
            if rn not in grouped_invoices:
                grouped_invoices[rn] = []
            grouped_invoices[rn].append(inv)
            
        receipt_numbers = list(grouped_invoices.keys())

        # 2. Fetch existing galla transactions
        existing_tx_resp = db.client.table("galla_transactions") \
            .select("id, receipt_number, amount") \
            .eq("username", username) \
            .eq("transaction_type", "CASH_SALE") \
            .in_("receipt_number", receipt_numbers) \
            .execute()

        existing_txs = {tx["receipt_number"]: tx for tx in (existing_tx_resp.data or []) if tx.get("receipt_number")}
        
        now = datetime.utcnow().isoformat()

        for rn, items in grouped_invoices.items():
            first_item = items[0]
            items_total = sum(float(i.get('amount') or 0.0) for i in items)
            
            # Authoritative grand total logic identical to udhar.py
            tba_max = max((float(i.get('total_bill_amount') or 0.0) for i in items), default=0.0)
            total_amount = tba_max if tba_max > 0 else items_total
            
            if total_amount <= 0:
                continue

            created_timestamps = [i.get('created_at') for i in items if i.get('created_at')]
            latest_created_ts = max(created_timestamps) if created_timestamps else first_item.get('created_at')

            if rn in existing_txs:
                # Update if amount differs
                existing_tx = existing_txs[rn]
                if abs(float(existing_tx["amount"]) - total_amount) > 0.01:
                    db.client.table("galla_transactions").update({
                        "amount": total_amount,
                        "updated_at": now
                    }).eq("id", existing_tx["id"]).execute()
            else:
                # Insert new transaction
                db.client.table("galla_transactions").insert({
                    "username": username,
                    "transaction_type": "CASH_SALE",
                    "amount": total_amount,
                    "receipt_number": rn,
                    "created_at": first_item.get("verification_date") or latest_created_ts or now,
                    "notes": "Cash Bill"
                }).execute()

    except Exception as e:
        logger.error(f"Error syncing galla transactions from invoices: {e}")
