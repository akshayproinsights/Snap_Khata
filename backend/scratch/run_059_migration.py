"""
Run migration 059 using Supabase Management API
"""
import sys
import os
from pathlib import Path
import httpx

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

SUPABASE_URL = "https://zlqwoexomqggkigjalds.supabase.co"
SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpscXdvZXhvbXFnZ2tpZ2phbGRzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2Njg5OTU4NiwiZXhwIjoyMDgyNDc1NTg2fQ.l12clHHyjkDu8ernU--3BabtJZTP41yAzKKtF0NHEFE"

# Extract project ref from URL
PROJECT_REF = "zlqwoexomqggkigjalds"

SQL = """
ALTER TABLE customer_ledgers
  ADD COLUMN IF NOT EXISTS latest_bill_date   TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS last_payment_date  TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS latest_bill_number TEXT;

ALTER TABLE vendor_ledgers
  ADD COLUMN IF NOT EXISTS latest_bill_date   TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS last_payment_date  TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS latest_bill_number TEXT;
"""

def run():
    print("Running migration 059 via Supabase Management API...")
    
    url = f"https://api.supabase.com/v1/projects/{PROJECT_REF}/database/query"
    headers = {
        "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
        "Content-Type": "application/json",
    }
    
    resp = httpx.post(url, json={"query": SQL}, headers=headers, timeout=30)
    print(f"Status: {resp.status_code}")
    print(f"Response: {resp.text}")
    
    if resp.status_code in (200, 201):
        print("✅ Migration succeeded!")
    else:
        print("❌ Management API failed, trying direct REST approach...")
        # Try using pg_rest extension or another approach
        # Use supabase-js compatible approach via POST to /rest/v1/rpc
        alt_url = f"{SUPABASE_URL}/rest/v1/rpc/exec_sql"
        alt_headers = {
            "apikey": SERVICE_ROLE_KEY,
            "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
            "Content-Type": "application/json",
        }
        alt_resp = httpx.post(alt_url, json={"query": SQL}, headers=alt_headers, timeout=30)
        print(f"Alt Status: {alt_resp.status_code}")
        print(f"Alt Response: {alt_resp.text}")

if __name__ == "__main__":
    run()
