from database import get_database_client
import json

db = get_database_client()
# Get the most recent username to filter by
user_resp = db.client.table('verified_invoices').select('username').order('created_at', desc=True).limit(1).execute()
if user_resp.data:
    username = user_resp.data[0]['username']
    print(f"Checking data for user: {username}")
    
    # 1. Check Verified Invoices
    vi_resp = db.client.table('verified_invoices').select('customer_name, payment_mode, balance_due, receipt_number, created_at').eq('username', username).order('created_at', desc=True).limit(5).execute()
    print("\n--- Recent Verified Invoices ---")
    print(json.dumps(vi_resp.data, indent=2))
    
    # 2. Check Ledger Transactions
    lt_resp = db.client.table('ledger_transactions').select('ledger_id, amount, transaction_type, is_paid, receipt_number, created_at').eq('username', username).order('created_at', desc=True).limit(5).execute()
    print("\n--- Recent Ledger Transactions ---")
    print(json.dumps(lt_resp.data, indent=2))
    
    # 3. Check Customer Ledgers
    cl_resp = db.client.table('customer_ledgers').select('id, customer_name, balance_due').eq('username', username).execute()
    print("\n--- Customer Ledgers ---")
    print(json.dumps(cl_resp.data, indent=2))
else:
    print("No data found in verified_invoices")
