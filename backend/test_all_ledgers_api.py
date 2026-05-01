import asyncio
import os
import sys

# Add the backend directory to sys.path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from routes.udhar import get_customer_ledgers

async def main():
    print("Getting ledgers for onkar...")
    result = await get_customer_ledgers({"username": "onkar"})
    
    for ld in result["data"]:
        print(f"ID: {ld['id']}, Name: {ld['customer_name']}, Balance: {ld['balance_due']}")

if __name__ == "__main__":
    asyncio.run(main())
