import sys
import os

# Add the parent directory to the Python path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from database import get_database_client

def check_db():
    db = get_database_client()

    print("\n--- INVOICES (866) ---")
    data = db.query('invoices').eq('receipt_number', '866').execute().data
    for d in data:
        print({k: d[k] for k in ['id', 'receipt_number', 'payment_mode', 'created_at']})
        
    print("\n--- VERIFICATION DATES (866) ---")
    data = db.query('verification_dates').eq('receipt_number', '866').execute().data
    for d in data:
        print({k: d[k] for k in ['id', 'receipt_number', 'payment_mode', 'verification_status', 'created_at']})
        
    print("\n--- VERIFICATION AMOUNTS (866) ---")
    data = db.query('verification_amounts').eq('receipt_number', '866').execute().data
    for d in data:
        print({k: d[k] for k in ['id', 'receipt_number', 'payment_mode', 'verification_status', 'created_at']})
        
    print("\n--- VERIFIED INVOICES (866) ---")
    data = db.query('verified_invoices').eq('receipt_number', '866').execute().data
    for d in data:
        print({k: d[k] for k in ['id', 'receipt_number', 'payment_mode', 'created_at']})

if __name__ == "__main__":
    check_db()
