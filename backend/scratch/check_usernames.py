import os
import sys
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from database import get_database_client

db = get_database_client()

tables = ["users", "user_profiles", "verified_invoices", "invoices", "verification_dates"]

for table in tables:
    print(f"\n--- Unique usernames in '{table}' ---")
    try:
        res = db.client.table(table).select("username").execute()
        usernames = set(row.get("username") for row in res.data if row.get("username"))
        print(usernames)
    except Exception as e:
        print(f"Error querying {table}: {e}")
