from supabase import create_client
import os

supabase_url = ""
supabase_key = ""

with open("backend/.env", "r") as f:
    for line in f:
        if "SUPABASE_URL" in line:
            supabase_url = line.split("=", 1)[1].strip().strip('"').strip("'")
        if "SUPABASE_KEY" in line:
            supabase_key = line.split("=", 1)[1].strip().strip('"').strip("'")

supabase = create_client(supabase_url, supabase_key)

try:
    res = supabase.table("verified_invoices").select("*").limit(1).execute()
    if res.data:
        print("Columns in verified_invoices:", list(res.data[0].keys()))
    else:
        print("Empty table but works")
except Exception as e:
    print(e)
