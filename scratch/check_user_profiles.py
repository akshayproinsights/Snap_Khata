import sys
import os
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'backend'))
from database import get_database_client

db = get_database_client()
res = db.client.table("user_profiles").select("*").execute()
print(f"Total profiles: {len(res.data)}")
for profile in res.data:
    print({
        "username": profile.get("username"),
        "shop_name": profile.get("shop_name"),
        "shop_logo_url": profile.get("shop_logo_url")
    })
