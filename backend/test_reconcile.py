import asyncio
import os
import sys

# Add the backend directory to sys.path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from routes.udhar import reconcile_all_customer_ledger_balances
from database import get_database_client

async def main():
    db = get_database_client()
    print("Reconciling for onkar...")
    result = await reconcile_all_customer_ledger_balances({"username": "onkar"})
    print("Result:", result)

    print("Checking db state after reconcile:")
    resp = db.client.table('customer_ledgers').select('id, username, customer_name, balance_due').eq('username', 'onkar').ilike('customer_name', '%arjun%').execute()
    print(resp.data)

if __name__ == "__main__":
    asyncio.run(main())
