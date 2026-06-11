import sys
import os
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'backend'))
from database import get_database_client

db = get_database_client()
for table in ["ledger_transactions", "verification_dates", "verified_invoices", "invoices"]:
    res = db.client.table(table).select("*").eq("receipt_number", "REC-00001").eq("username", "jadhav").execute()
    print(f"Table: {table}, Count: {len(res.data)}")
    if res.data:
        print(f"Sample row keys: {list(res.data[0].keys())}")
        # Print first row
        print(res.data[0])
