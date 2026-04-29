import sys
import os
import json
from dotenv import load_dotenv

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
load_dotenv()

from database import get_database_client

db = get_database_client()

print("--- LATEST VERIFIED INVOICES ---")
res = db.query('verified_invoices', ['receipt_number', 'payment_mode', 'created_at']).order('created_at', desc=True).limit(5).execute()
print(json.dumps(res.data, indent=2))

print("\n--- LATEST VERIFICATION DATES ---")
res2 = db.query('verification_dates', ['receipt_number', 'payment_mode', 'verification_status', 'created_at']).order('created_at', desc=True).limit(5).execute()
print(json.dumps(res2.data, indent=2))

print("\n--- LATEST INVOICES ---")
res3 = db.query('invoices', ['receipt_number', 'payment_mode', 'created_at']).order('created_at', desc=True).limit(5).execute()
print(json.dumps(res3.data, indent=2))
