import sys
import os
sys.path.append(os.path.join(os.path.dirname(__file__), 'backend'))
from database import get_database_client

db = get_database_client()
res = db.client.table("inventory_items").select("id, verification_status, username").eq("username", "onkar").execute()
print(f"Total onkar items: {len(res.data)}")
pending = [r for r in res.data if r.get("verification_status") != "Done"]
print(f"Pending items: {len(pending)}")
print(pending[:2])
