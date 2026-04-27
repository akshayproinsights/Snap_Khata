import os
import sys
import asyncio
from typing import Dict, List

# Add the parent directory to sys.path to import from backend
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from database import get_database_client

async def fix_amounts():
    db = get_database_client()
    print("Fixing transaction amounts that were incorrectly summed...")

    # 1. Fix Customer Transactions
    print("\n--- Fixing customer_ledger_transactions ---")
    # Fetch all INVOICE transactions
    tx_resp = db.client.table("ledger_transactions") \
        .select("id, username, receipt_number, amount") \
        .eq("transaction_type", "INVOICE") \
        .execute()
    
    txs = tx_resp.data or []
    
    for tx in txs:
        rn = tx["receipt_number"]
        u = tx["username"]
        if not rn: continue
        
        # Fetch the ACTUAL balance_due from verified_invoices (take only one row)
        inv_resp = db.client.table("verified_invoices") \
            .select("balance_due") \
            .eq("username", u) \
            .eq("receipt_number", rn) \
            .limit(1) \
            .execute()
        
        if inv_resp.data:
            correct_amount = float(inv_resp.data[0]["balance_due"] or 0)
            current_amount = float(tx["amount"] or 0)
            
            if abs(current_amount - correct_amount) > 0.01:
                print(f"Mismatch for Customer Receipt {rn} (User: {u}): Current={current_amount}, Correct={correct_amount}. Updating...")
                db.client.table("ledger_transactions").update({"amount": correct_amount}).eq("id", tx["id"]).execute()

    # 2. Fix Vendor Transactions
    print("\n--- Fixing vendor_ledger_transactions ---")
    v_tx_resp = db.client.table("vendor_ledger_transactions") \
        .select("id, username, invoice_number, amount") \
        .eq("transaction_type", "INVOICE") \
        .execute()
    
    v_txs = v_tx_resp.data or []
    
    for tx in v_txs:
        inv_num = tx["invoice_number"]
        u = tx["username"]
        if not inv_num: continue
        
        # Fetch the ACTUAL balance_owed from inventory_invoices
        inv_resp = db.client.table("inventory_invoices") \
            .select("balance_owed") \
            .eq("username", u) \
            .eq("invoice_number", inv_num) \
            .limit(1) \
            .execute()
        
        if inv_resp.data:
            correct_amount = float(inv_resp.data[0]["balance_owed"] or 0)
            current_amount = float(tx["amount"] or 0)
            
            if abs(current_amount - correct_amount) > 0.01:
                print(f"Mismatch for Vendor Invoice {inv_num} (User: {u}): Current={current_amount}, Correct={correct_amount}. Updating...")
                db.client.table("vendor_ledger_transactions").update({"amount": correct_amount}).eq("id", tx["id"]).execute()

    print("\nFix complete. Please run fix_ledger_balances.py to reconcile final totals.")

if __name__ == "__main__":
    asyncio.run(fix_amounts())
