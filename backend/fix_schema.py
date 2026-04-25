import os
import sys
from dotenv import load_dotenv

# Load env from .env
load_dotenv(".env")

url = os.environ.get("SUPABASE_URL")
key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")

if not url or not key:
    print("Missing env")
    sys.exit(1)

try:
    from supabase import create_client
    supabase = create_client(url, key)
    
    queries = [
        "ALTER TABLE verified_invoices ADD COLUMN IF NOT EXISTS received_amount NUMERIC DEFAULT 0;",
        "ALTER TABLE verified_invoices ADD COLUMN IF NOT EXISTS upload_date TIMESTAMP WITH TIME ZONE DEFAULT NOW();",
        "ALTER TABLE stock_levels ADD COLUMN IF NOT EXISTS internal_item_name TEXT;",
        "ALTER TABLE draft_purchase_orders ADD COLUMN IF NOT EXISTS added_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();",
        "ALTER TABLE stock_levels ADD COLUMN IF NOT EXISTS current_stock NUMERIC DEFAULT 0;",
        "ALTER TABLE verified_invoices ADD COLUMN IF NOT EXISTS type TEXT;",
        "ALTER TABLE inventory_invoices ADD COLUMN IF NOT EXISTS price_hike_amount NUMERIC DEFAULT 0;",
        "ALTER TABLE verified_invoices ADD COLUMN IF NOT EXISTS customer_details JSONB;",
        "NOTIFY pgrst, 'reload schema';"
    ]
    
    for q in queries:
        print(f"Running: {q}")
        res = supabase.rpc("exec_sql", {"query": q}).execute()
        print(res)
        
except Exception as e:
    print(f"Error: {e}")
