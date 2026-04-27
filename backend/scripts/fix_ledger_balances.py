import os
import sys
import logging
from typing import Dict, List, Any

# Add backend to path to import database
sys.path.append(os.path.join(os.getcwd(), 'backend'))

from database import get_database_client

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def reconcile_all_ledgers():
    db = get_database_client()
    
    # 1. Fetch all users
    users_resp = db.client.table('user_profiles').select('username').execute()
    usernames = [u['username'] for u in (users_resp.data or [])]
    
    for username in usernames:
        logger.info(f"Reconciling data for user: {username}")
        db.set_user_context(username)
        
        # --- CUSTOMER LEDGERS ---
        # Recalculate ledger balances based on existing transactions
        ledgers_resp = db.client.table('customer_ledgers').select('id, customer_name, balance_due').eq('username', username).execute()
        for ledger in (ledgers_resp.data or []):
            lid = ledger['id']
            # Sum all transactions for this ledger
            all_txs_resp = db.client.table('ledger_transactions').select('amount, transaction_type').eq('ledger_id', lid).execute()
            correct_balance = 0.0
            for tx in (all_txs_resp.data or []):
                amt = float(tx.get('amount') or 0.0)
                if tx['transaction_type'] == 'INVOICE':
                    correct_balance += amt
                else: # PAYMENT
                    correct_balance -= amt
            
            if abs(correct_balance - float(ledger.get('balance_due') or 0.0)) > 0.01:
                logger.info(f"Updating customer ledger {ledger['customer_name']}: balance {ledger['balance_due']} -> {correct_balance}")
                db.client.table('customer_ledgers').update({'balance_due': correct_balance}).eq('id', lid).execute()

        # --- VENDOR LEDGERS ---
        # Recalculate vendor ledger balances based on existing transactions
        v_ledgers_resp = db.client.table('vendor_ledgers').select('id, vendor_name, balance_due').eq('username', username).execute()
        for ledger in (v_ledgers_resp.data or []):
            lid = ledger['id']
            all_txs_resp = db.client.table('vendor_ledger_transactions').select('amount, transaction_type').eq('ledger_id', lid).execute()
            correct_balance = 0.0
            for tx in (all_txs_resp.data or []):
                amt = float(tx.get('amount') or 0.0)
                if tx['transaction_type'] == 'INVOICE':
                    correct_balance += amt
                else: # PAYMENT
                    correct_balance -= amt
            
            if abs(correct_balance - float(ledger.get('balance_due') or 0.0)) > 0.01:
                logger.info(f"Updating vendor ledger {ledger['vendor_name']}: balance {ledger['balance_due']} -> {correct_balance}")
                db.client.table('vendor_ledgers').update({'balance_due': correct_balance}).eq('id', lid).execute()

if __name__ == "__main__":
    reconcile_all_ledgers()
