import asyncio
import os
from database import get_database_client
from routes.udhar import sync_customer_ledgers_from_invoices, sync_vendor_ledgers_from_invoices
from datetime import datetime

async def test_dashboard_summary(username):
    print(f"Testing dashboard summary for {username}")
    db = get_database_client()
    
    current_user = {"username": username}
    
    # Trigger sync
    print("Syncing...")
    try:
        await sync_vendor_ledgers_from_invoices(current_user)
        await sync_customer_ledgers_from_invoices(current_user)
    except Exception as e:
        print(f"Sync failed: {e}")
    
    # Compute total_receivable
    ledger_resp = db.client.table('customer_ledgers') \
        .select('id, balance_due') \
        .eq('username', username) \
        .execute()
    ledgers = ledger_resp.data or []
    
    total_receivable = 0.0
    if ledgers:
        ledger_ids = [ld['id'] for ld in ledgers]
        cust_tx_resp = db.client.table('ledger_transactions') \
            .select('ledger_id, amount, transaction_type') \
            .eq('username', username) \
            .in_('ledger_id', ledger_ids) \
            .execute()
        
        expected = {ld['id']: 0.0 for ld in ledgers}
        for tx in (cust_tx_resp.data or []):
            lid = tx.get('ledger_id')
            amt = float(tx.get('amount') or 0)
            ttype = tx.get('transaction_type')
            if ttype in ('INVOICE', 'MANUAL_CREDIT'):
                expected[lid] += amt
            elif ttype == 'PAYMENT':
                expected[lid] -= amt
        
        for ld in ledgers:
            computed = expected[ld['id']]
            if computed > 0:
                total_receivable += computed

    # Compute total_payable
    v_ledger_resp = db.client.table('vendor_ledgers') \
        .select('id, balance_due') \
        .eq('username', username) \
        .execute()
    v_ledgers = v_ledger_resp.data or []
    
    total_payable = 0.0
    if v_ledgers:
        v_ledger_ids = [ld['id'] for ld in v_ledgers]
        vend_tx_resp = db.client.table('vendor_ledger_transactions') \
            .select('vendor_ledger_id, amount, transaction_type') \
            .eq('username', username) \
            .in_('vendor_ledger_id', v_ledger_ids) \
            .execute()
        
        v_expected = {ld['id']: 0.0 for ld in v_ledgers}
        for tx in (vend_tx_resp.data or []):
            lid = tx.get('vendor_ledger_id')
            amt = float(tx.get('amount') or 0)
            ttype = tx.get('transaction_type')
            if ttype in ('INVOICE', 'MANUAL_CREDIT'):
                v_expected[lid] += amt
            elif ttype == 'PAYMENT':
                v_expected[lid] -= amt
        
        for ld in v_ledgers:
            computed = v_expected[ld['id']]
            if computed > 0:
                total_payable += computed

    print(f"Total Receivable: {total_receivable}")
    print(f"Total Payable: {total_payable}")

    # Check for specific customer "Anubhav Shendge"
    anubhav = db.client.table('customer_ledgers').select('id, customer_name, balance_due').eq('username', username).eq('customer_name', 'Anubhav Shendge').execute()
    if anubhav.data:
        aid = anubhav.data[0]['id']
        print(f"Anubhav Shendge (ID: {aid}) Stored Balance: {anubhav.data[0]['balance_due']}")
        atx = db.client.table('ledger_transactions').select('*').eq('ledger_id', aid).execute()
        print(f"Anubhav Transactions: {len(atx.data)}")
        for t in atx.data:
            print(f"  - {t['transaction_type']} {t['amount']} (is_paid: {t['is_paid']})")

if __name__ == "__main__":
    import sys
    user = sys.argv[1] if len(sys.argv) > 1 else "akshaykh"
    asyncio.run(test_dashboard_summary(user))
