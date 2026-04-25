from dotenv import load_dotenv
import os
from supabase import create_client

load_dotenv()
url = os.getenv("SUPABASE_URL")
key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

if not url or not key:
    print("Missing supabase credentials")
    exit(1)

sb = create_client(url, key)

try:
    res = sb.table('ledger_transactions').select('*').limit(1).execute()
    print("ledger_transactions columns:", list(res.data[0].keys()) if res.data else "No data")
except Exception as e:
    print("ledger_transactions Error:", e)

try:
    res2 = sb.table('vendor_ledger_transactions').select('*').limit(1).execute()
    print("vendor_ledger_transactions columns:", list(res2.data[0].keys()) if res2.data else "No data")
except Exception as e:
    print("vendor_ledger_transactions Error:", e)

try:
    res3 = sb.table('verified_invoices').select('*').limit(1).execute()
    print("verified_invoices columns:", list(res3.data[0].keys()) if res3.data else "No data")
except Exception as e:
    print("verified_invoices Error:", e)

