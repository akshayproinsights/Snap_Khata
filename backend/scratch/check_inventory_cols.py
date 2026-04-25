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
    # Get one row from inventory_items to see columns
    res = sb.table('inventory_items').select('*').limit(1).execute()
    if res.data:
        print("inventory_items columns:", list(res.data[0].keys()))
    else:
        print("No data in inventory_items.")
        # Try to find columns by trying to select them
        cols_to_check = ['id', 'username', 'verification_status', 'needs_review', 'invoice_number', 'vendor_name']
        for col in cols_to_check:
            try:
                sb.table('inventory_items').select(col).limit(1).execute()
                print(f"Column '{col}' EXISTS")
            except Exception as e:
                print(f"Column '{col}' MISSING")
except Exception as e:
    print("Error querying inventory_items:", e)
