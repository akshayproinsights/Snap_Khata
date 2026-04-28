import asyncio
import os
import logging
import sys

# Configure logging to see output from routes
logging.basicConfig(level=logging.INFO, stream=sys.stdout)

from database import get_database_client
from routes.udhar import sync_customer_ledgers_from_invoices, reconcile_all_customer_ledger_balances
from routes.vendor_ledgers import sync_vendor_ledgers_from_invoices, reconcile_all_ledger_balances

async def main():
    # Replace with the relevant username
    username = "akshaykh" 
    current_user = {"username": username}
    
    print(f"Starting manual sync for user: {username}")
    
    print("Syncing Customer Ledgers...")
    await sync_customer_ledgers_from_invoices(current_user)
    
    print("Reconciling Customer Ledger Balances...")
    res = await reconcile_all_customer_ledger_balances(current_user)
    print(f"Result: {res}")
    
    print("\nSyncing Vendor Ledgers...")
    await sync_vendor_ledgers_from_invoices(current_user)
    
    print("Reconciling Vendor Ledger Balances...")
    res_v = await reconcile_all_ledger_balances(current_user)
    print(f"Result: {res_v}")
    
    print("\nManual sync and reconciliation complete!")

if __name__ == "__main__":
    asyncio.run(main())
