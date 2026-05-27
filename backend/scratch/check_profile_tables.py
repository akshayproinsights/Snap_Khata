import os
import sys
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from database import get_database_client

db = get_database_client()

print("--- Checking user_profiles table ---")
try:
    res = db.client.table("user_profiles").select("*").limit(5).execute()
    print("user_profiles rows:", res.data)
except Exception as e:
    print("Error querying user_profiles:", e)

print("\n--- Checking user_profile table ---")
try:
    res = db.client.table("user_profile").select("*").limit(5).execute()
    print("user_profile rows:", res.data)
except Exception as e:
    print("Error querying user_profile:", e)
