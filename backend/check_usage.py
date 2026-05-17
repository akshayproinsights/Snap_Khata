import asyncio
from database import get_database_client

def main():
    db = get_database_client()
    response = db.client.table("usage_logs").select("username, order_type").execute()
    logs = response.data
    
    from collections import defaultdict
    counts = defaultdict(int)
    for log in logs:
        counts[log['username']] += 1
        
    for user, count in sorted(counts.items(), key=lambda x: x[1], reverse=True):
        print(f"User: {user} | Processed Receipts: {count}")

if __name__ == "__main__":
    main()
