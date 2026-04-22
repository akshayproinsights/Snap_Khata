import os
import sys
import logging
from datetime import datetime
from collections import defaultdict

# Add current directory to path so we can import database
sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))

from database import get_database_client

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def repair_data():
    db = get_database_client()
    
    # 1. FIX CUSTOMER LEDGER TRANSACTIONS
    logger.info("Cleaning up duplicate Customer Ledger transactions...")
    try:
        # Fetch all transactions with a receipt_number
        tx_resp = db.client.table('ledger_transactions').select('id, ledger_id, receipt_number').not_.is_('receipt_number', 'null').execute()
        all_tx = tx_resp.data or []
        
        # Group by (ledger_id, receipt_number)
        tx_map = defaultdict(list)
        for tx in all_tx:
            key = (tx['ledger_id'], tx['receipt_number'])
            tx_map[key].append(tx['id'])
            
        delete_ids = []
        for key, ids in tx_map.items():
            if len(ids) > 1:
                # Keep the first ID, delete the rest
                delete_ids.extend(ids[1:])
                logger.info(f"Customer Ledger {key[0]}, Invoice {key[1]}: Found {len(ids)} duplicates. Will delete {len(ids)-1}.")
        
        if delete_ids:
            logger.info(f"Deleting {len(delete_ids)} duplicate customer transactions...")
            # Supabase delete with .in_ has limits on array size, so we'll do it in chunks if needed
            for i in range(0, len(delete_ids), 100):
                chunk = delete_ids[i:i+100]
                db.client.table('ledger_transactions').delete().in_('id', chunk).execute()
            logger.info("Deletion complete.")
        else:
            logger.info("No duplicate customer transactions found.")
            
    except Exception as e:
        logger.error(f"Error cleaning customer transactions: {e}")

    # 2. FIX VENDOR LEDGER TRANSACTIONS
    logger.info("Cleaning up duplicate Vendor Ledger transactions...")
    try:
        # Fetch all transactions with an invoice_number
        v_tx_resp = db.client.table('vendor_ledger_transactions').select('id, ledger_id, invoice_number').not_.is_('invoice_number', 'null').execute()
        all_v_tx = v_tx_resp.data or []
        
        # Group by (ledger_id, invoice_number)
        v_tx_map = defaultdict(list)
        for tx in all_v_tx:
            key = (tx['ledger_id'], tx['invoice_number'])
            v_tx_map[key].append(tx['id'])
            
        v_delete_ids = []
        for key, ids in v_tx_map.items():
            if len(ids) > 1:
                # Keep the first ID, delete the rest
                v_delete_ids.extend(ids[1:])
                logger.info(f"Vendor Ledger {key[0]}, Invoice {key[1]}: Found {len(ids)} duplicates. Will delete {len(ids)-1}.")
        
        if v_delete_ids:
            logger.info(f"Deleting {len(v_delete_ids)} duplicate vendor transactions...")
            for i in range(0, len(v_delete_ids), 100):
                chunk = v_delete_ids[i:i+100]
                db.client.table('vendor_ledger_transactions').delete().in_('id', chunk).execute()
            logger.info("Deletion complete.")
        else:
            logger.info("No duplicate vendor transactions found.")
            
    except Exception as e:
        logger.error(f"Error cleaning vendor transactions: {e}")

    # 3. RUN BALANCE RECONCILIATION
    logger.info("Running full balance reconciliation...")
    from repair_ledgers import repair_ledgers
    repair_ledgers()
    logger.info("Repair complete.")

if __name__ == "__main__":
    repair_data()
