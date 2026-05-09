import sys
import os
import asyncio
sys.path.append(os.path.join(os.path.dirname(__file__), 'backend'))
from database import get_database_client

db = get_database_client()
res = db.client.table("inventory_items").select("*").eq("username", "onkar").neq("verification_status", "Done").execute()
print(f"neq Done: {len(res.data)}")

res2 = db.client.table("inventory_items").select("*").eq("username", "onkar").execute()
print(f"all items: {len(res2.data)}")

