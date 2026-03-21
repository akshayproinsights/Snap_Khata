import os
import sys
from dotenv import load_dotenv

os.chdir("/root/Snap_Khata/backend")
load_dotenv("/root/Snap_Khata/backend/.env")

from database import get_database_client

db = get_database_client()
resp = db.client.table("verified_invoices").select("*").eq("receipt_number", "1578").limit(1).execute()
if resp.data:
    row = resp.data[0]
    print(f"vehicle_number: {row.get('vehicle_number')}")
    print(f"odometer: {row.get('odometer')}")
    print(f"odometer_reading: {row.get('odometer_reading')}")
else:
    print("Not found in verified_invoices")
    
resp2 = db.client.table("verification_dates").select("*").eq("receipt_number", "1578").limit(1).execute()
if resp2.data:
    row = resp2.data[0]
    print("Found in verification_dates:")
    print(f"vehicle_number: {row.get('vehicle_number')}")
    print(f"odometer: {row.get('odometer')}")
    print(f"odometer_reading: {row.get('odometer_reading')}")
else:
    print("Not found in verification_dates")
