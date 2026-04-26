import os
import sys
from pathlib import Path

# Add backend directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from database import get_database_client

def reload_schema():
    print("Attempting to reload PostgREST schema cache...")
    try:
        db = get_database_client()
        # Notify PostgREST to reload schema
        db.client.rpc('exec_sql', {'query': "NOTIFY pgrst, 'reload schema';"}).execute()
        print("✅ Success: Schema reload notification sent.")
    except Exception as e:
        print(f"❌ Error: {e}")
        print("\nIf 'exec_sql' function is missing, you need to create it in Supabase SQL Editor first:")
        print("""
create or replace function exec_sql(query text)
returns void
language plpgsql
security definer
as $$
begin
  execute query;
end;
$$;
GRANT EXECUTE ON FUNCTION exec_sql(text) TO service_role;
""")

if __name__ == "__main__":
    reload_schema()
