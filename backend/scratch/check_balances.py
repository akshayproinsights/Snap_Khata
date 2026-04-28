import os
import sys
from pathlib import Path

# Add backend to path
sys.path.append(str(Path(__file__).resolve().parent.parent))

from database import get_database_client

def check_balances():
    db = get_database_client()
    
    # Check Anubhav Shendge, Barde Sir, Ajay Jadhav
    names = ['Anubhav Shendge', 'Barde Sir', 'Ajay Jadhav']
    
    print("Checking customer_ledgers...")
    ledger_ids = {}
    for name in names:
        result = db.query('customer_ledgers').match({'customer_name': name}).execute()
        if result.data:
            data = result.data[0]
            ledger_ids[name] = data['id']
            print(f"Name: {data['customer_name']}, ID: {data['id']}, Balance Due: {data['balance_due']}")
        else:
            print(f"Name: {name} not found in customer_ledgers")
            
    print("\nChecking ledger_transactions (summing for verification)...")
    for name, lid in ledger_ids.items():
        result = db.query('ledger_transactions').match({'ledger_id': lid}).execute()
        if result.data:
            total_due = sum(tx['amount'] if tx['transaction_type'] in ('INVOICE', 'MANUAL_CREDIT') else -tx['amount'] for tx in result.data)
            print(f"Name: {name} (LID: {lid}), Total Sum: {total_due}")
            
            # Logic like in dashboard-summary (potentially wrong)
            summary_due = 0.0
            for tx in result.data:
                amt = float(tx.get('amount') or 0)
                ttype = tx.get('transaction_type')
                is_paid = tx.get('is_paid', False)
                print(f"  - {ttype}: {amt} (is_paid: {is_paid}, Date: {tx.get('created_at', 'N/A')})")
                
                if ttype in ('INVOICE', 'MANUAL_CREDIT'):
                    if not is_paid:
                        summary_due += amt
                elif ttype == 'PAYMENT':
                    summary_due -= amt
            print(f"  => Summary logic due: {summary_due}")
        else:
            print(f"Name: {name} (LID: {lid}) not found in ledger_transactions")

if __name__ == "__main__":
    check_balances()
