import os
import sys
from supabase import create_client, Client

# Add backend to path
sys.path.append('/root/Snap_Khata/backend')
from config import get_supabase_config

config = get_supabase_config()
if not config:
    print("Error: Could not load Supabase config")
    sys.exit(1)

supabase: Client = create_client(config['url'], config['service_role_key'])

def check_schema(table_name):
    try:
        # information_schema might not be accessible via rpc if not exposed
        # Let's try select first, but since we want column types, we'll try a raw query via a dummy rpc or just fetch one row
        res = supabase.table(table_name).select("*").limit(1).execute()
        if res.data:
            print(f"Columns for {table_name}: {list(res.data[0].keys())}")
        else:
            print(f"Table {table_name} is empty, could not determine columns via select.")
    except Exception as e:
        print(f"Error checking {table_name}: {e}")

if __name__ == "__main__":
    check_schema('ledger_transactions')
    check_schema('vendor_ledger_transactions')
    check_schema('verified_invoices')
