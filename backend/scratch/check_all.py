import sys
import os
import json

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from database import get_database_client

def check_db():
    db = get_database_client()

    print("\n--- INVOICES ---")
    data = db.query('invoices').execute().data
    for d in data[-10:]:
        print(f"Receipt: {d.get('receipt_number')}, Payment Mode: {d.get('payment_mode')}")
        
    print("\n--- VERIFICATION DATES ---")
    data = db.query('verification_dates').execute().data
    for d in data[-10:]:
        print(f"Receipt: {d.get('receipt_number')}, Status: {d.get('verification_status')}, Payment Mode: {d.get('payment_mode')}")

if __name__ == "__main__":
    check_db()
