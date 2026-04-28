
import os
from supabase import create_client

def load_env():
    with open(".env", "r") as f:
        for line in f:
            if line.startswith("PROD_SUPABASE_URL="):
                os.environ["PROD_SUPABASE_URL"] = line.split("=", 1)[1].strip()
            if line.startswith("PROD_SUPABASE_SERVICE_ROLE_KEY="):
                os.environ["PROD_SUPABASE_SERVICE_ROLE_KEY"] = line.split("=", 1)[1].strip()

def check_constraints():
    load_env()
    url = os.environ.get("PROD_SUPABASE_URL")
    key = os.environ.get("PROD_SUPABASE_SERVICE_ROLE_KEY")
    
    if not url or not key:
        print("Missing env vars")
        return
        
    supabase = create_client(url, key)
    
    # Check for unique constraints on verified_invoices
    # Since we can't use rpc('execute_sql') easily if it's not defined, 
    # we can try to insert a duplicate and see if it fails with a constraint violation
    
    print(f"Checking {url}")
    
    # Alternatively, just try to get the table definition if possible
    # But let's try the SQL query again, maybe it works via postgrest if we use a different approach
    # Actually, Supabase doesn't expose raw SQL via PostgREST unless there's an RPC.
    
    # Let's try to list indexes using another method if possible.
    # Or just assume the constraint might be missing and that's why on_conflict is failing.
    
    # Wait, the user said "not getting saved".
    # If on_conflict is missing, Supabase upsert usually defaults to PK (id).
    # If the frontend doesn't send 'id', and we rely on 'username,row_id', and that's not a constraint,
    # then it might be doing a normal insert which might fail if there's no PK or if it violates something else.
    
    print("DONE")

if __name__ == "__main__":
    check_constraints()
