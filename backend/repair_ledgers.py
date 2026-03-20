import os
import sys
import logging
from datetime import datetime

# Add current directory to path so we can import database
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from database import get_database_client

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def repair_ledgers():
    """
    Recalculates all customer and vendor ledger balances based on the sum of their transactions.
    """
    db = get_database_client()
    
    # 1. Repair Customer Ledgers
    logger.info("Starting repair of Customer Ledgers...")
    try:
        ledgers_resp = db.client.table('customer_ledgers').select('*').execute()
        customer_ledgers = ledgers_resp.data
        
        repaired_ids = []

        for ledger in customer_ledgers:
            ledger_id = ledger['id']
            name = ledger['customer_name']
            username = ledger['username']
            
            # Get all transactions for this ledger
            tx_resp = db.client.table('ledger_transactions') \
                .select('amount, transaction_type') \
                .eq('ledger_id', ledger_id) \
                .execute()
            
            transactions = tx_resp.data
            
            expected_balance = 0.0
            for tx in transactions:
                amount = float(tx['amount'])
                t_type = tx['transaction_type']
                
                # INVOICE, MANUAL_CREDIT increase balance due
                if t_type in ['INVOICE', 'MANUAL_CREDIT']:
                    expected_balance += amount
                # PAYMENT decreases balance due
                elif t_type == 'PAYMENT':
                    expected_balance -= amount
                else:
                    logger.warning(f"Unknown transaction type {t_type} for customer ledger {ledger_id}")
            
            current_balance = float(ledger.get('balance_due', 0))
            
            if abs(current_balance - expected_balance) > 0.01:
                logger.info(f"Mismatch for customer '{name}' (User: {username}): Current={current_balance}, Expected={expected_balance}. Fixing...")
                db.client.table('customer_ledgers').update({
                    'balance_due': expected_balance,
                    'updated_at': datetime.utcnow().isoformat()
                }).eq('id', ledger_id).execute()
                repaired_ids.append(ledger_id)
            else:
                logger.debug(f"Balance correct for customer '{name}'")
        
        logger.info(f"Customer Ledgers repair complete. Repaired {len(repaired_ids)} records.")
        
    except Exception as e:
        logger.error(f"Error during customer ledger repair: {e}")

    # 2. Repair Vendor Ledgers
    logger.info("Starting repair of Vendor Ledgers...")
    try:
        v_ledgers_resp = db.client.table('vendor_ledgers').select('*').execute()
        vendor_ledgers = v_ledgers_resp.data
        
        repaired_v_ids = []

        for v_ledger in vendor_ledgers:
            v_ledger_id = v_ledger['id']
            name = v_ledger['vendor_name']
            username = v_ledger['username']
            
            # Get all transactions for this vendor ledger
            v_tx_resp = db.client.table('vendor_ledger_transactions') \
                .select('amount, transaction_type') \
                .eq('ledger_id', v_ledger_id) \
                .execute()
            
            v_transactions = v_tx_resp.data
            
            expected_v_balance = 0.0
            for v_tx in v_transactions:
                amount = float(v_tx['amount'])
                t_type = v_tx['transaction_type']
                
                # MANUAL_CREDIT, INVOICE increase balance owed to vendor
                if t_type in ['MANUAL_CREDIT', 'INVOICE']:
                    expected_v_balance += amount
                # PAYMENT decreases balance owed
                elif t_type == 'PAYMENT':
                    expected_v_balance -= amount
                else:
                    logger.warning(f"Unknown transaction type {t_type} for vendor ledger {v_ledger_id}")
            
            current_v_balance = float(v_ledger.get('balance_due', 0))
            
            if abs(current_v_balance - expected_v_balance) > 0.01:
                logger.info(f"Mismatch for vendor '{name}' (User: {username}): Current={current_v_balance}, Expected={expected_v_balance}. Fixing...")
                db.client.table('vendor_ledgers').update({
                    'balance_due': expected_v_balance,
                    'updated_at': datetime.utcnow().isoformat()
                }).eq('id', v_ledger_id).execute()
                repaired_v_ids.append(v_ledger_id)
            else:
                logger.debug(f"Balance correct for vendor '{name}'")
        
        logger.info(f"Vendor Ledgers repair complete. Repaired {len(repaired_v_ids)} records.")
        
    except Exception as e:
        logger.error(f"Error during vendor ledger repair: {e}")

if __name__ == "__main__":
    repair_ledgers()
