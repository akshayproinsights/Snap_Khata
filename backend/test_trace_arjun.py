import asyncio
import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from database import get_database_client

async def trace_arjun():
    db = get_database_client()
    db.set_user_context("onkar")
    
    tx_resp = db.client.table('ledger_transactions').select('*').eq('ledger_id', 73).execute()
    transactions = tx_resp.data
    
    receipt_numbers = [tx['receipt_number'] for tx in transactions if tx.get('transaction_type') == 'INVOICE' and tx.get('receipt_number')]
    
    enrichment = {}
    if receipt_numbers:
        vi_resp = db.client.table('verified_invoices').select('receipt_number, amount, received_amount, balance_due, payment_mode').in_('receipt_number', receipt_numbers).eq('username', "onkar").execute()
        for vi in vi_resp.data:
            rn = vi.get('receipt_number')
            if rn not in enrichment:
                enrichment[rn] = {'amount_sum': 0.0, 'received_amount': 0.0, 'balance_due': 0.0, 'payment_mode': 'Cash'}
            enrichment[rn]['amount_sum'] += float(vi.get('amount', 0) or 0)
            row_received = float(vi.get('received_amount', 0) or 0)
            row_balance = float(vi.get('balance_due', 0) or 0)
            if row_received > enrichment[rn]['received_amount']:
                enrichment[rn]['received_amount'] = row_received
            if row_balance > enrichment[rn]['balance_due']:
                enrichment[rn]['balance_due'] = row_balance
            if vi.get('payment_mode'):
                enrichment[rn]['payment_mode'] = vi['payment_mode']
                
    for i, tx in enumerate(transactions):
        if tx.get('transaction_type') == 'INVOICE' and tx.get('receipt_number') in enrichment:
            enr = enrichment[tx['receipt_number']]
            line_item_total = enr['amount_sum']
            meta_received = float(enr.get('received_amount') or 0)
            meta_balance = float(enr.get('balance_due') or 0)
            payment_mode = enr.get('payment_mode') or 'Cash'
            
            grand_total = meta_received + meta_balance
            if grand_total == 0 and line_item_total > 0:
                grand_total = line_item_total
                
            print("meta_received:", meta_received)
            print("meta_balance:", meta_balance)
            print("payment_mode:", payment_mode)
            print("grand_total:", grand_total)
            print("line_item_total:", line_item_total)
            
            if payment_mode.lower() != 'credit':
                effective_received = meta_received if (meta_received > 0 or meta_balance > 0) else grand_total
                effective_balance = max(0, grand_total - effective_received)
                is_paid = (effective_balance <= 0)
            else:
                if meta_received == 0 and meta_balance == 0 and line_item_total > 0:
                    effective_received = 0.0
                    effective_balance = line_item_total
                    is_paid = False
                else:
                    effective_received = meta_received
                    effective_balance = meta_balance
                    is_paid = (meta_balance <= 0)
                    
            print("effective_received:", effective_received)
            print("effective_balance:", effective_balance)
            print("is_paid:", is_paid)

if __name__ == "__main__":
    asyncio.run(trace_arjun())
