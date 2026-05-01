import asyncio
import os
import sys

# Add the backend directory to sys.path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from routes.udhar import get_customer_ledgers
from database import get_database_client

async def main():
    db = get_database_client()
    print("Getting ledgers for onkar...")
    result = await get_customer_ledgers({"username": "onkar"})
    
    # print the ledger for arjun
    for ld in result["data"]:
        if "arjun" in ld["customer_name"].lower():
            print("Arjun's ledger data returned:", ld)
            
    print("Checking db state after get_customer_ledgers:")
    resp = db.client.table('customer_ledgers').select('id, username, customer_name, balance_due').eq('username', 'onkar').ilike('customer_name', '%arjun%').execute()
    print("DB state:", resp.data)

if __name__ == "__main__":
    asyncio.run(main())
