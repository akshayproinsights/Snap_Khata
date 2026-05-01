import asyncio
import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from routes.udhar import get_ledger_transactions

async def main():
    result = await get_ledger_transactions(73, {"username": "onkar"})
    print("Ledger:", result["ledger"])
    print("Transactions:")
    for tx in result["data"]:
        print(f"Type: {tx.get('transaction_type')}, Amount: {tx.get('amount')}, is_paid: {tx.get('is_paid')}, balance_due: {tx.get('balance_due')}")

if __name__ == "__main__":
    asyncio.run(main())
