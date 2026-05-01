import asyncio
import os
import sys

# Add the backend directory to sys.path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from routes.udhar import sync_customer_ledgers_from_invoices, reconcile_all_customer_ledger_balances
from database import get_database_client
import logging

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
# Force udhar logger to INFO
logging.getLogger("routes.udhar").setLevel(logging.INFO)
logger = logging.getLogger(__name__)

import routes.udhar
print(f"DEBUG: Importing udhar from: {routes.udhar.__file__}")

async def main():
    username = "onkar"
    print(f"--- Force Repairing Ledgers for {username} ---")
    
    current_user = {"username": username}
    
    # 1. Run the sync from invoices to create missing transactions (Payments)
    print("Step 1: Running sync_customer_ledgers_from_invoices...")
    await sync_customer_ledgers_from_invoices(current_user)
    
    # 2. Run reconciliation to fix balances
    print("Step 2: Running reconcile_all_customer_ledger_balances...")
    await reconcile_all_customer_ledger_balances(current_user)
    
    # 3. Verify results
    db = get_database_client()
    data = db.client.table('customer_ledgers').select('customer_name, balance_due').eq('username', username).execute().data
    
    print("\nFinal Ledger Balances:")
    total = 0
    for d in data:
        bal = float(d['balance_due'])
        print(f"{d['customer_name']}: {bal}")
        total += bal
    
    print(f"\nTOTAL RECEIVABLE: {total}")

if __name__ == "__main__":
    asyncio.run(main())
