import asyncio
from backend.database import get_database_client

def main():
    db = get_database_client()
    resp = db.client.table("inventory_items").select("id, verification_status").execute()
    print("Total items:", len(resp.data))
    for row in resp.data[:5]:
        print(row)
    
    # Query with neq Done
    resp2 = db.client.table("inventory_items").select("id, verification_status").neq("verification_status", "Done").execute()
    print("Total with neq Done:", len(resp2.data))

main()
