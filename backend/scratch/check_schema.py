import os
from supabase import create_client
from dotenv import load_dotenv

load_dotenv()

url = os.environ.get("SUPABASE_URL")
key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")

if not url or not key:
    print("Error: SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY not found in environment.")
    exit(1)

supabase = create_client(url, key)

res = supabase.table("verified_invoices").select("*").limit(1).execute()
if res.data:
    print(f"Columns in verified_invoices: {list(res.data[0].keys())}")
else:
    print("No data in verified_invoices to infer columns.")

res_invoices = supabase.table("invoices").select("*").limit(1).execute()
if res_invoices.data:
    print(f"Columns in invoices: {list(res_invoices.data[0].keys())}")
else:
    print("No data in invoices to infer columns.")
