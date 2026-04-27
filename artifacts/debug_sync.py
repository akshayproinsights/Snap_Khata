
import os
import sys
sys.path.append('/root/Snap_Khata/backend')
from database import get_database_client
from dotenv import load_dotenv
load_dotenv('/root/Snap_Khata/backend/.env')

def debug_sync():
    db = get_database_client()
    users_resp = db.client.table('users').select('username').limit(5).execute()
    username = users_resp.data[0]['username']
    print(f"User: {username}")
    
    # Check verified_invoices
    vi_resp = db.client.table('verified_invoices').select('receipt_number, customer_name, amount, payment_mode').eq('username', username).execute()
    print(f"Total Verified Invoices: {len(vi_resp.data or [])}")
    
    # Check ledger_transactions
    tx_resp = db.client.table('ledger_transactions').select('receipt_number').eq('username', username).execute()
    synced_rns = {tx['receipt_number'] for tx in (tx_resp.data or []) if tx.get('receipt_number')}
    print(f"Total Synced Receipts: {len(synced_rns)}")
    
    missing = []
    for vi in (vi_resp.data or []):
        rn = vi.get('receipt_number')
        if rn and rn not in synced_rns and vi.get('payment_mode') == 'Credit':
            missing.append(vi)
            
    print(f"Credit Invoices MISSING from Ledger: {len(missing)}")
    for m in missing[:5]:
        print(f"  RN: {m['receipt_number']}, Customer: {m['customer_name']}, Amount: {m['amount']}")

if __name__ == "__main__":
    debug_sync()
