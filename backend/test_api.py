import asyncio
import os
import sys

# Add the backend directory to sys.path so we can import 'database'
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from database import get_database_client

db = get_database_client()
# Need to use the actual username, let's query the customer_ledgers directly.
resp = db.client.table('customer_ledgers').select('id, username, customer_name, balance_due').ilike('customer_name', '%arjun%').execute()
print(resp.data)
