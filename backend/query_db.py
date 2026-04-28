from database import get_database_client
db = get_database_client()
# Get a user
user = db.client.table('verified_invoices').select('username').limit(1).execute()
username = user.data[0]['username'] if user.data else None
if username:
    print(f"Username: {username}")
    vi = db.client.table('verified_invoices').select('*').eq('username', username).order('created_at', desc=True).limit(2).execute()
    print("Recent Verified Invoices:")
    for row in vi.data:
        print({k: v for k, v in row.items() if k in ['receipt_number', 'customer_name', 'payment_mode', 'balance_due', 'amount', 'type', 'created_at']})
    
    vd = db.client.table('verification_dates').select('*').eq('username', username).order('created_at', desc=True).limit(2).execute()
    print("Recent Verification Dates:")
    for row in vd.data:
        print({k: v for k, v in row.items() if k in ['receipt_number', 'customer_details', 'payment_mode', 'balance_due', 'amount', 'created_at']})
        
    invoices = db.client.table('invoices').select('*').eq('username', username).order('created_at', desc=True).limit(2).execute()
    print("Recent Raw Invoices:")
    for row in invoices.data:
        print({k: v for k, v in row.items() if k in ['receipt_number', 'customer', 'payment_mode', 'balance_due', 'amount', 'created_at']})
        
    ledger = db.client.table('ledger_transactions').select('*').eq('username', username).order('created_at', desc=True).limit(5).execute()
    print("Recent Ledger Transactions:")
    for row in ledger.data:
        print({k: v for k, v in row.items() if k in ['transaction_id', 'customer_name', 'amount', 'type', 'created_at', 'receipt_number']})

    customer_ledgers = db.client.table('customer_ledgers').select('*').eq('username', username).order('created_at', desc=True).limit(3).execute()
    print("Recent Customer Ledgers:")
    for row in customer_ledgers.data:
        print({k: v for k, v in row.items() if k in ['customer_name', 'balance', 'created_at', 'updated_at']})
