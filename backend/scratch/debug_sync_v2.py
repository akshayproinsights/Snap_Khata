import os
import sys
import asyncio

# Add backend to path
sys.path.append(os.path.join(os.getcwd(), 'backend'))

from database import get_database_client

async def debug_sync():
    username = "akshaykh"
    db = get_database_client()
    db.set_user_context(username)
    
    # 1. Fetch invoices
    invoices_resp = db.client.table("verified_invoices").select("*").eq("username", username).execute()
    invoices = invoices_resp.data or []
    print(f"Found {len(invoices)} invoices for {username}")
    
    grouped_invoices = {}
    for inv in invoices:
        rn = inv.get("receipt_number")
        if not rn: continue
        
        if rn not in grouped_invoices:
            grouped_invoices[rn] = {
                "total_amount": 0.0,
                "received_amount": float(inv.get("received_amount") or 0),
                "customer_name": inv.get("customer_name"),
                "date": inv.get("created_at"),
                "notes": inv.get("customer_details")
            }
        grouped_invoices[rn]["total_amount"] += float(inv.get("amount") or 0)

    print(f"Grouped into {len(grouped_invoices)} receipts")
    if '833' in grouped_invoices:
        print(f"Receipt 833 data: {grouped_invoices['833']}")
    else:
        print("Receipt 833 NOT in grouped invoices")
        # Let's see what receipt numbers are there
        print(f"First 5 receipt numbers: {list(grouped_invoices.keys())[:5]}")

    # 2. Check existing transactions
    receipt_numbers = list(grouped_invoices.keys())
    
    # Get ledger map
    customer_names = list(set([g["customer_name"] for g in grouped_invoices.values() if g["customer_name"]]))
    ledgers_resp = db.client.table("customer_ledgers").select("id, customer_name").eq("username", username).in_("customer_name", customer_names).execute()
    ledger_map = {str(row["customer_name"]).strip().lower(): row["id"] for row in (ledgers_resp.data or [])}
    print(f"Ledger map: {ledger_map}")

    existing_tx_resp = db.client.table("ledger_transactions") \
        .select("id, receipt_number, ledger_id, amount, is_paid, transaction_type") \
        .eq("username", username) \
        .in_("receipt_number", receipt_numbers) \
        .execute()
    
    existing_tx = existing_tx_resp.data or []
    print(f"Found {len(existing_tx)} existing transactions")
    
    for tx in existing_tx:
        if tx.get("receipt_number") == '833':
            print(f"Found existing transaction for 833: {tx}")

if __name__ == "__main__":
    asyncio.run(debug_sync())
