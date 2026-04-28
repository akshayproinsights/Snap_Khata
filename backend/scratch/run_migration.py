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

def run_sql(sql_file):
    with open(sql_file, 'r') as f:
        sql = f.read()
    
    try:
        # Use rpc if execute_sql is available, or just try to run it
        # Since I don't have direct SQL access, I'll use the 'execute_sql' rpc if it exists
        # If not, I'll have to ask the user or try another way.
        # Most of our setups have an 'execute_sql' function for migrations.
        res = supabase.rpc('exec_sql', {'query': sql}).execute()
        print(f"Successfully ran {sql_file}")
    except Exception as e:
        print(f"Error running {sql_file}: {e}")

if __name__ == "__main__":
    run_sql('/root/Snap_Khata/backend/scratch/fix_verified_invoices_schema.sql')
