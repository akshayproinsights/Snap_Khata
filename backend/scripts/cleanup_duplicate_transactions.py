import os
import sys
import asyncio
from typing import Dict, List

# Add the parent directory to sys.path to import from backend
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from database import get_database_client

async def cleanup_duplicates():
    db = get_database_client()
    print("Starting cleanup of duplicate ledger transactions...")

    # 1. Cleanup Customer Ledger Transactions
    print("\n--- Cleaning up customer_ledger_transactions ---")
    tx_resp = db.client.table("ledger_transactions") \
        .select("id, username, receipt_number, transaction_type, amount") \
        .eq("transaction_type", "INVOICE") \
        .execute()
    
    txs = tx_resp.data or []
    seen = {} # (username, receipt_number) -> id
    to_delete = []

    for tx in txs:
        u = tx["username"]
        rn = tx["receipt_number"]
        if not rn: continue
        
        key = (u, rn)
        if key in seen:
            print(f"Duplicate found for Customer Receipt {rn} (User: {u}). Deleting ID: {tx['id']}")
            to_delete.append(tx["id"])
        else:
            seen[key] = tx["id"]

    if to_delete:
        # Delete in chunks
        for i in range(0, len(to_delete), 10):
            chunk = to_delete[i:i+10]
            db.client.table("ledger_transactions").delete().in_("id", chunk).execute()
        print(f"Deleted {len(to_delete)} duplicate customer transactions.")
    else:
        print("No duplicate customer transactions found.")

    # 2. Cleanup Vendor Ledger Transactions
    print("\n--- Cleaning up vendor_ledger_transactions ---")
    v_tx_resp = db.client.table("vendor_ledger_transactions") \
        .select("id, username, invoice_number, transaction_type, amount") \
        .eq("transaction_type", "INVOICE") \
        .execute()
    
    v_txs = v_tx_resp.data or []
    seen_v = {} # (username, invoice_number) -> id
    to_delete_v = []

    for tx in v_txs:
        u = tx["username"]
        inv = tx["invoice_number"]
        if not inv: continue
        
        key = (u, inv)
        if key in seen_v:
            print(f"Duplicate found for Vendor Invoice {inv} (User: {u}). Deleting ID: {tx['id']}")
            to_delete_v.append(tx["id"])
        else:
            seen_v[key] = tx["id"]

    if to_delete_v:
        for i in range(0, len(to_delete_v), 10):
            chunk = to_delete_v[i:i+10]
            db.client.table("vendor_ledger_transactions").delete().in_("id", chunk).execute()
        print(f"Deleted {len(to_delete_v)} duplicate vendor transactions.")
    else:
        print("No duplicate vendor transactions found.")

    print("\nCleanup complete. Please run fix_ledger_balances.py to reconcile final totals.")

if __name__ == "__main__":
    asyncio.run(cleanup_duplicates())
