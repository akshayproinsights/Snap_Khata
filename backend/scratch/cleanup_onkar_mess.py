
import os
import sys
import asyncio
from datetime import datetime

# Add the parent directory to sys.path to import local modules
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from database import get_database_client
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

async def main():
    username = "onkar"
    print(f"--- Cleaning Up Old Mess for {username} ---")
    
    db = get_database_client()
    db.set_user_context(username)
    
    # We want to find old invoices that are causing trouble.
    # Specifically, any invoice with a receipt number that is much older than the current ones.
    # In the logs, I saw receipt #871 was causing the 3657 balance.
    
    trouble_receipts = ["871", "866", "818", "838", "814", "870", "873"]
    
    print(f"Deleting troublesome old receipts: {trouble_receipts}")
    
    for rn in trouble_receipts:
        # Delete from verified_invoices
        res = db.client.table("verified_invoices").delete().eq("username", username).eq("receipt_number", rn).execute()
        print(f"Deleted receipt {rn} from verified_invoices: {len(res.data) if res.data else 0} records")
        
        # Delete from invoices
        res = db.client.table("invoices").delete().eq("username", username).eq("receipt_number", rn).execute()
        print(f"Deleted receipt {rn} from invoices: {len(res.data) if res.data else 0} records")

        # Delete from ledger_transactions (if any orphaned ones remain)
        res = db.client.table("ledger_transactions").delete().eq("username", username).eq("receipt_number", rn).execute()
        print(f"Deleted receipt {rn} from ledger_transactions: {len(res.data) if res.data else 0} records")

    # Now reconcile all balances
    from routes.udhar import sync_customer_ledgers_from_invoices, reconcile_all_customer_ledger_balances
    current_user = {"username": username}
    
    print("Re-syncing and reconciling...")
    await sync_customer_ledgers_from_invoices(current_user)
    await reconcile_all_customer_ledger_balances(current_user)
    
    print("Cleanup Complete.")

if __name__ == "__main__":
    asyncio.run(main())
