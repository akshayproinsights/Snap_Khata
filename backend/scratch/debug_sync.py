import os
import sys
from pathlib import Path
from datetime import datetime

# Add backend to path
sys.path.append(str(Path(__file__).resolve().parent.parent))

from database import get_database_client

def debug_sync():
    db = get_database_client()
    username = 'akshaykh'
    db.set_user_context(username)
    
    print(f"Debugging sync for user: {username}")
    
    # 1. Fetch all verified invoices for this user
    invoices_resp = db.client.table("verified_invoices") \
        .select("*") \
        .eq("username", username) \
        .execute()
    
    invoices_data = invoices_resp.data or []
    print(f"Found {len(invoices_data)} verified invoices.")
    
    grouped_invoices = {}
    for inv in invoices_data:
        rn = inv.get("receipt_number")
        if not rn: continue
        
        if rn not in grouped_invoices:
            grouped_invoices[rn] = {
                "customer_name": inv.get("customer_name"),
                "payment_mode": inv.get("payment_mode") or "Credit",
                "total_amount": 0.0,
                "received_amount": 0.0,
                "created_at": inv.get("created_at"),
                "notes": f"Invoice {rn}"
            }
        
        amt = float(inv.get("amount") or 0)
        recv = float(inv.get("received_amount") or 0)
        grouped_invoices[rn]["total_amount"] += amt
        grouped_invoices[rn]["received_amount"] += recv
        
        if rn == '833':
            print(f"  - Item: {inv.get('description')}, Amt: {amt}, Recv: {recv}")

    for rn, data in grouped_invoices.items():
        if rn == '833':
            print(f"\nGrouped 833: {data}")
            tx_amount = data["total_amount"] - data["received_amount"]
            is_credit = data["payment_mode"].lower() == "credit"
            is_paid = not is_credit or (tx_amount <= 0.01)
            print(f"  => tx_amount: {tx_amount}, is_paid: {is_paid}")

if __name__ == "__main__":
    debug_sync()
