import asyncio
import os
import sys

# Add the backend directory to sys.path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from routes.udhar import get_ledger_transactions

async def verify_transactions(ledger_id, username):
    print(f"\n--- Verifying Transactions for Ledger {ledger_id} (User: {username}) ---")
    result = await get_ledger_transactions(ledger_id, {"username": username})
    
    transactions = result["data"]
    ledger = result["ledger"]
    
    print(f"Total Billed: {ledger.get('total_billed')}")
    print(f"Total Paid: {ledger.get('total_paid')}")
    print(f"Balance Due: {ledger.get('balance_due')}")
    print("-" * 50)
    
    for tx in transactions:
        tx_id = tx.get("id")
        tx_type = tx.get("transaction_type")
        amount = tx.get("amount")
        rn = tx.get("receipt_number")
        
        if tx_type == "INVOICE":
            pm = tx.get("payment_mode")
            rec = tx.get("received_amount")
            bal = tx.get("balance_due")
            print(f"[ID: {tx_id}] [INVOICE] RN: {rn}, Amt: {amount}, PM: {pm}, Rec: {rec}, Bal: {bal}")
        elif tx_type == "PAYMENT":
            link = tx.get("linked_transaction_id")
            print(f"[ID: {tx_id}] [PAYMENT] RN: {rn}, Amt: {amount}, Linked: {link}")
        else:
            print(f"[ID: {tx_id}] [{tx_type}] Amt: {amount}")

if __name__ == "__main__":
    # Test for Barde (75) and Kedarnath (81)
    async def run():
        await verify_transactions(75, "onkar")
        await verify_transactions(81, "onkar")
        
    asyncio.run(run())
