import os, sys
import asyncio
from dotenv import load_dotenv

sys.path.insert(0, '.')
load_dotenv('.env')

from database import get_database_client

async def main():
    try:
        db = get_database_client()
        with open('migrations/047_fix_missing_columns.sql', 'r') as f:
            sql = f.read()
            
        print("Executing migration...")
        response = db.client.rpc('exec_sql', {'sql_query': sql}).execute()
        print(f"Migration Response: {response}")
        print("Migration applied successfully!")
    except Exception as e:
        print(f"Error: {e}")
        
if __name__ == "__main__":
    asyncio.run(main())
