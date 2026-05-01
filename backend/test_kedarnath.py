import asyncio
import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from database import get_database_client

db = get_database_client()
print("Transactions for Kedarnath:")
resp = db.client.table('ledger_transactions').select('*').eq('ledger_id', 81).execute()
print(resp.data)

rns = [tx.get('receipt_number') for tx in resp.data if tx.get('receipt_number')]
if rns:
    vi_resp = db.client.table('verified_invoices').select('receipt_number, received_amount, balance_due, amount, payment_mode').in_('receipt_number', rns).execute()
    print("Verified invoices:")
    print(vi_resp.data)
