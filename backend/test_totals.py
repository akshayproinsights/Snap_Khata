import asyncio
import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from database import get_database_client

db = get_database_client()
print("Totals for onkar:")
resp = db.client.table('customer_ledgers').select('balance_due').eq('username', 'onkar').execute()
print(sum(r['balance_due'] for r in resp.data))

print("Totals for Akshay_K:")
resp = db.client.table('customer_ledgers').select('balance_due').eq('username', 'Akshay_K').execute()
print(sum(r['balance_due'] for r in resp.data))

# Also check for other users maybe?
print("All users:")
resp = db.client.table('users').select('username').execute()
print([r['username'] for r in resp.data])

