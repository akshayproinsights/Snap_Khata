import asyncio
from routes.udhar import get_ledger_transactions, get_all_customer_transactions
import json
import os

async def test():
    current_user = {"username": "akshaykh"}
    print(">>> STARTING_FULL_TEST")
    
    try:
        # Test Maske (ID 47)
        resp = await get_ledger_transactions(47, current_user)
        data = resp["data"]
        ledger = resp.get("ledger", {})
        print(f"RESULT_LEDGER_BAL: {ledger.get('balance_due')}, Billed={ledger.get('total_billed')}, Paid={ledger.get('total_paid')}")
        inv_814 = next((tx for tx in data if tx.get("receipt_number") == "814" and tx["transaction_type"] == "INVOICE"), None)
        pay_814 = next((tx for tx in data if tx.get("receipt_number") == "814" and tx["transaction_type"] == "PAYMENT"), None)
        
        if inv_814:
            print(f"RESULT_MASK_INV: Amt={inv_814.get('amount')}, Recv={inv_814.get('received_amount')}, Paid={inv_814.get('is_paid')}")
        else:
            print("RESULT_MASK_INV: NOT_FOUND")
            
        if pay_814:
            print(f"RESULT_MASK_PAY: {pay_814.get('amount')}")
        else:
            print("RESULT_MASK_PAY: NOT_FOUND")

        # Test Recent Activity
        resp_all = await get_all_customer_transactions(50, current_user)
        maske_all = next((tx for tx in resp_all["data"] if tx.get("receipt_number") == "814"), None)
        if maske_all:
            print(f"RESULT_RECENT: Amt={maske_all.get('amount')}, Recv={maske_all.get('received_amount')}, Paid={maske_all.get('is_paid')}")
        else:
            print("RESULT_RECENT: NOT_FOUND")
    except Exception as e:
        print(f"ERROR: {e}")
    
    print(">>> TEST_COMPLETE")

if __name__ == "__main__":
    asyncio.run(test())
