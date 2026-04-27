from dotenv import load_dotenv
import os
from supabase import create_client

load_dotenv('/root/Snap_Khata/backend/.env')
url = os.getenv("SUPABASE_URL")
key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
sb = create_client(url, key)

# Get one row to see all columns
res = sb.table('invoices').select('*').limit(1).execute()
if res.data:
    print("Columns in invoices table:", list(res.data[0].keys()))
else:
    # If no data, try to get column names via RPC or just assume from previous check if they are same
    print("No data in invoices table")

res2 = sb.table('verified_invoices').select('*').limit(1).execute()
if res2.data:
    print("Columns in verified_invoices table:", list(res2.data[0].keys()))
