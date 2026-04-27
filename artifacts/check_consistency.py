
import os
import sys

# Add backend to path
sys.path.append('/root/Snap_Khata/backend')

from database import get_database_client
from dotenv import load_dotenv

load_dotenv('/root/Snap_Khata/backend/.env')

def check_dashboard_consistency():
    db = get_database_client()
    
    # Let's pick a user. Since I don't have a specific username, I'll list some users first.
    users_resp = db.client.table('users').select('username').limit(5).execute()
    if not users_resp.data:
        print("No users found")
        return
    
    username = users_resp.data[0]['username']
    print(f"Checking consistency for user: {username}")
    
    # 1. Total Receivable from customer_ledgers
    receivable_resp = db.client.table('customer_ledgers') \
        .select('balance_due') \
        .eq('username', username) \
        .gt('balance_due', 0) \
        .execute()
    
    calc_receivable = sum(item['balance_due'] for item in receivable_resp.data) if receivable_resp.data else 0.0
    
    # 2. Total Payable from vendor_ledgers
    payable_resp = db.client.table('vendor_ledgers') \
        .select('balance_due') \
        .eq('username', username) \
        .gt('balance_due', 0) \
        .execute()
    
    calc_payable = sum(item['balance_due'] for item in payable_resp.data) if payable_resp.data else 0.0
    
    print(f"Calculated Receivable (sum of ledgers): {calc_receivable}")
    print(f"Calculated Payable (sum of ledgers): {calc_payable}")
    
    # 3. Sum of transactions vs Ledger balance
    # Let's check one ledger
    if receivable_resp.data:
        ledgers = db.client.table('customer_ledgers').select('id, customer_name, balance_due').eq('username', username).limit(1).execute()
        if ledgers.data:
            ledger = ledgers.data[0]
            lid = ledger['id']
            lname = ledger['customer_name']
            lbal = ledger['balance_due']
            
            tx_resp = db.client.table('ledger_transactions').select('amount, transaction_type').eq('ledger_id', lid).execute()
            tx_sum = 0
            for tx in tx_resp.data:
                if tx['transaction_type'] == 'INVOICE':
                    tx_sum += tx['amount']
                elif tx['transaction_type'] == 'PAYMENT':
                    tx_sum -= tx['amount']
            
            print(f"Ledger: {lname} (ID: {lid})")
            print(f"  Current Balance: {lbal}")
            print(f"  Sum of Transactions: {tx_sum}")
            if abs(lbal - tx_sum) > 0.01:
                print(f"  !!! MISMATCH detected in ledger {lname} !!!")

if __name__ == "__main__":
    check_dashboard_consistency()
