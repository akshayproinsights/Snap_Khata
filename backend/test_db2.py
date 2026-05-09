from database import get_database_client
db = get_database_client()
res = db.client.table("inventory_items").select("id, verification_status").eq("username", "onkar").neq("verification_status", "Done").execute()
print(f"Total pending items: {len(res.data)}")
print(res.data)
