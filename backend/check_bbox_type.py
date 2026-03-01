import os
import sys
# Add parent directory to path to import database
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from database import get_database_client

db = get_database_client()

print("Checking verification_dates...")
res = db.query('verification_dates').limit(1).execute()
if res.data:
    row = res.data[0]
    for k in ['date_bbox', 'receipt_number_bbox', 'combined_bbox', 'date_and_receipt_combined_bbox']:
        if k in row:
            v = row[k]
            print(f"{k}: {type(v)} - {v}")
else:
    print("No data in verification_dates")

print("\nChecking verification_amounts...")
res2 = db.query('verification_amounts').limit(1).execute()
if res2.data:
    row2 = res2.data[0]
    for k in ['line_item_row_bbox', 'amount_bbox', 'receipt_bbox', 'date_and_receipt_combined_bbox']:
        if k in row2:
            v = row2[k]
            print(f"{k}: {type(v)} - {v}")
else:
    print("No data in verification_amounts")
