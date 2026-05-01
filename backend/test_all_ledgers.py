import asyncio
import os
import sys

# Add the backend directory to sys.path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from database import get_database_client

db = get_database_client()
print("All ledgers for onkar:")
resp = db.client.table('customer_ledgers').select('id, customer_name, balance_due').eq('username', 'onkar').execute()
for ld in resp.data:
    print(ld)
