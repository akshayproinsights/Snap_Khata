import asyncio
from backend.database import get_database_client

async def test():
    db = get_database_client()
    # Let's get the raw data without username filter so we can see all of it
    resp = db.client.table('vendor_ledgers').select('*').limit(5).execute()
    print("Vendor ledgers:")
    for row in resp.data:
        print(f"Vendor: {row.get('vendor_name')}, Balance Due: {row.get('balance_due')} (Type: {type(row.get('balance_due'))})")
    
    resp2 = db.client.table('vendor_ledgers').select('*').gt('balance_due', 0).limit(5).execute()
    print("Vendor ledgers with balance > 0:")
    for row in resp2.data:
        print(f"Vendor: {row.get('vendor_name')}, Balance Due: {row.get('balance_due')}")

asyncio.run(test())
