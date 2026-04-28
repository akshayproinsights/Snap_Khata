
import os
from supabase import create_client

def load_env():
    with open(".env", "r") as f:
        for line in f:
            if line.startswith("PROD_SUPABASE_URL="):
                os.environ["PROD_SUPABASE_URL"] = line.split("=", 1)[1].strip()
            if line.startswith("PROD_SUPABASE_SERVICE_ROLE_KEY="):
                os.environ["PROD_SUPABASE_SERVICE_ROLE_KEY"] = line.split("=", 1)[1].strip()

def check_indexes():
    load_env()
    url = os.environ.get("PROD_SUPABASE_URL")
    key = os.environ.get("PROD_SUPABASE_SERVICE_ROLE_KEY")
    supabase = create_client(url, key)
    
    query = """
    SELECT
        tablename,
        indexname,
        indexdef
    FROM
        pg_indexes
    WHERE
        schemaname = 'public'
        AND tablename = 'verified_invoices';
    """
    
    try:
        response = supabase.rpc('exec_sql', {'query': query}).execute()
        print("Indexes for verified_invoices:")
        print(response.data)
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    check_indexes()
