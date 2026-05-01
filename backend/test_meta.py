import asyncio
import os
import sys

# Add the backend directory to sys.path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from database import get_database_client

db = get_database_client()
print("Verified invoices metadata:")
vi_resp = db.client.table('verified_invoices').select('receipt_number, received_amount, balance_due, amount, payment_mode').eq('receipt_number', '1596').execute()
print(vi_resp.data[0] if vi_resp.data else "None")
