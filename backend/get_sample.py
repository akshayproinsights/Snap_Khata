import sys
import os
from dotenv import load_dotenv

# Let's load .env from the root or backend based on where we are
load_dotenv("/root/Snap_Khata/backend/.env")

url = os.environ.get("SUPABASE_URL")
key = os.environ.get("SUPABASE_KEY")

if not url or not key:
    print("Missing SUPABASE credentials")
    sys.exit(1)

from supabase import create_client, Client
supabase: Client = create_client(url, key)

res = supabase.table("verification_dates").select("*").limit(1).execute()
print("verification_dates keys:", res.data[0].keys() if res.data else "No data")
if res.data:
    row = res.data[0]
    print(f"vehicle_number: {row.get('vehicle_number')}, odometer: {row.get('odometer_reading')}, balance_due: {row.get('balance_due')}")

res2 = supabase.table("verification_amounts").select("*").limit(1).execute()
print("verification_amounts keys:", res2.data[0].keys() if res2.data else "No data")

res3 = supabase.table("verified_invoices").select("*").limit(1).execute()
print("verified_invoices keys:", res3.data[0].keys() if res3.data else "No data")

