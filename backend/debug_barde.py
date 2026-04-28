from database import get_database_client
import json

def debug_customer(customer_name_part):
    db = get_database_client()
    
    # 1. Find Ledger
    print(f"--- Searching for customer matching: {customer_name_part} ---")
    ledgers = db.client.table('customer_ledgers').select('*').ilike('customer_name', f'%{customer_name_part}%').execute()
    
    if not ledgers.data:
        print("No ledger found.")
        return

    for ledger in ledgers.data:
        ledger_id = ledger['id']
        name = ledger['customer_name']
        username = ledger['username']
        balance_due = ledger['balance_due']
        
        print(f"\nLedger: {name} (ID: {ledger_id}, Username: {username})")
        print(f"Cached Balance Due: {balance_due}")
        
        # 2. Get Ledger Transactions
        transactions = db.client.table('ledger_transactions').select('*').eq('ledger_id', ledger_id).order('created_at').execute()
        print(f"\nLedger Transactions ({len(transactions.data)}):")
        sum_transactions = 0
        for tx in transactions.data:
            amt = tx['amount']
            tx_type = tx['transaction_type'] # INVOICE (+) or PAYMENT (-)
            if tx_type == 'INVOICE':
                sum_transactions += amt
            elif tx_type == 'PAYMENT':
                sum_transactions -= amt
            
            is_paid = tx.get('is_paid', False)
            linked = tx.get('linked_transaction_id')
            print(f"  {tx['created_at']} | {tx_type:7} | {amt:8.2f} | Paid: {str(is_paid):5} | Linked: {str(linked):4} | Receipt: {tx.get('receipt_number')}")
            
        print(f"Calculated Balance from Transactions: {sum_transactions:.2f}")
        if abs(sum_transactions - float(balance_due)) > 0.01:
            print(f"!!! DISCREPANCY DETECTED: {sum_transactions - float(balance_due):.2f} !!!")
            
        # 3. Get Verified Invoices
        invoices = db.client.table('verified_invoices').select('*').eq('username', username).execute()
        print(f"\nAll Verified Invoices for {username} ({len(invoices.data)}):")
        unique_receipts = set()
        for inv in invoices.data:
            receipt = inv.get('receipt_number', 'N/A')
            unique_receipts.add(receipt)
            cust = inv.get('customer_name', 'N/A')
            if customer_name_part.lower() not in cust.lower():
                continue
                
            mode = inv.get('payment_mode', 'N/A')
            amt = float(inv.get('amount') or 0)
            total = float(inv.get('total_bill_amount') or 0)
            recv = float(inv.get('received_amount') or 0)
            due = float(inv.get('balance_due') or 0)
            print(f"  {inv['created_at']} | {receipt:10} | {cust:15} | {mode:6} | Line Amt: {amt:8.2f} | Bill Total: {total:8.2f} | Recv: {recv:8.2f} | Due: {due:8.2f}")
        
        print(f"\nTotal Unique Receipts for user: {len(unique_receipts)}")

if __name__ == '__main__':
    debug_customer('Barde')
