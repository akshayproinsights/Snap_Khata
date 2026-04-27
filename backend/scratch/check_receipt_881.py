from dotenv import load_dotenv
import os
import json
from supabase import create_client

load_dotenv('/root/Snap_Khata/backend/.env')
url = os.getenv("SUPABASE_URL")
key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
sb = create_client(url, key)

print("Checking invoices table...")
res = sb.table('invoices').select('*').eq('receipt_number', '881').execute()
for row in res.data:
    print(json.dumps(row, indent=2))

print("\nChecking verified_invoices table...")
res2 = sb.table('verified_invoices').select('*').eq('receipt_number', '881').execute()
for row in res2.data:
    print(json.dumps(row, indent=2))
