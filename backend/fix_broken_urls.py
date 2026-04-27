import os
import sys
import json
from dotenv import load_dotenv
from supabase import create_client, Client

# Add backend to path
sys.path.append(os.path.join(os.getcwd(), 'backend'))

# Load environment
dotenv_path = os.path.join(os.getcwd(), 'backend', '.env')
load_dotenv(dotenv_path, override=True)

URL = os.getenv("SUPABASE_URL")
KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

if not URL or not KEY:
    print("Error: SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY not found")
    sys.exit(1)

supabase: Client = create_client(URL, KEY)

# Domain mapping for correction
CORRECTIONS = {
    "pub-3de23488ca6c4e2392d96de04f8c5cff.r2.dev": {
        "bucket": "snapkhata-prod",
        "new_domain": "pub-1ee455c147c54e23b37edcf721f0e3a9.r2.dev"
    }
}

TABLES = [
    "inventory_invoices",
    "invoices",
    "verification_dates",
    "verification_amounts"
]

def fix_urls():
    for table in TABLES:
        print(f"\nProcessing table: {table}")
        
        # Search for URLs containing the old domain that was incorrectly used for snapkhata-prod
        search_domain = "pub-3de23488ca6c4e2392d96de04f8c5cff.r2.dev"
        res = supabase.table(table).select("id, receipt_link").ilike("receipt_link", f"%{search_domain}%").execute()
        
        if not res.data:
            print(f"  No broken URLs found in {table}")
            continue
            
        print(f"  Found {len(res.data)} potentially broken URLs")
        
        update_count = 0
        for row in res.data:
            old_url = row['receipt_link']
            if not old_url:
                continue
            
            # Correction logic for snapkhata-prod
            correction = CORRECTIONS[search_domain]
            bucket = correction['bucket']
            new_domain = correction['new_domain']
            
            # If it's a snapkhata-prod image but using the aksh-invoices domain
            if bucket in old_url and search_domain in old_url:
                # 1. Replace domain
                new_url = old_url.replace(search_domain, new_domain)
                # 2. Remove bucket name from path (managed domains serve bucket at root)
                # Check for /bucket/ and replace with /
                new_url = new_url.replace(f"/{bucket}/", "/")
                
                print(f"  Updating ID {row['id']}:")
                print(f"    Old: {old_url}")
                print(f"    New: {new_url}")
                
                # Perform update
                try:
                    supabase.table(table).update({"receipt_link": new_url}).eq("id", row['id']).execute()
                    update_count += 1
                except Exception as e:
                    print(f"    Error updating {row['id']}: {e}")
        
        print(f"  Successfully updated {update_count} records in {table}")

if __name__ == "__main__":
    fix_urls()
