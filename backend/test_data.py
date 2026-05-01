import asyncio
import os
import sys

# Add the backend directory to sys.path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from database import get_database_client

db = get_database_client()
print("Transactions for Arjun:")
resp = db.client.table('ledger_transactions').select('*').eq('ledger_id', 73).execute()
print(resp.data)

print("\nVerified invoices:")
rns = [tx.get('receipt_number') for tx in resp.data if tx.get('receipt_number')]
if rns:
    vi_resp = db.client.table('verified_invoices').select('receipt_number, received_amount, payment_mode').in_('receipt_number', rns).execute()
    print(vi_resp.data)
else:
    print("No receipt numbers in transactions.")
