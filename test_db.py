import asyncio
from backend.database import get_database_client
db = get_database_client()
for table in ['invoices', 'verification_dates', 'verified_invoices']:
    res = db.client.table(table).select('*').limit(1).execute()
    print(f"{table}:", list(res.data[0].keys()) if res.data else "[]")
