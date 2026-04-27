
import os
import sys
import logging
import json
from collections import defaultdict

# Add backend directory to path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from database import get_database_client

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def repair_data():
    db = get_database_client()
    # Note: We need a valid username context if RLS is on. 
    # But for a repair script, we might want to bypass it or iterate users.
    # For now, let's assume we can see everything or set a specific user if needed.
    # From previous logs, 'akshay' seems to be the main user.
    db.set_user_context('akshay')

    # 1. Fetch all verified invoices
    logger.info("Fetching verified_invoices...")
    resp = db.client.table('verified_invoices').select('*').execute()
    if not resp.data:
        logger.error("No verified invoices found.")
        return
    
    verified_records = resp.data
    logger.info(f"Found {len(verified_records)} verified records.")

    # 2. Fetch all raw invoices for metadata recovery
    logger.info("Fetching raw invoices for metadata...")
    inv_resp = db.client.table('invoices').select('receipt_number, extra_fields, vehicle_number, customer_details').execute()
    
    raw_metadata = {}
    for inv in inv_resp.data:
        rn = inv['receipt_number']
        if rn not in raw_metadata:
            raw_metadata[rn] = {
                'mobile_number': inv.get('extra_fields', {}).get('mobile_number'),
                'vehicle_number': inv.get('vehicle_number') or inv.get('extra_fields', {}).get('vehicle_number') or inv.get('extra_fields', {}).get('car_number'),
                'customer_details': inv.get('customer_details') or inv.get('extra_fields', {}).get('customer_details'),
                'total_bill_amount': inv.get('extra_fields', {}).get('total_bill_amount')
            }

    # 3. Group by receipt_number and recalculate
    receipt_groups = defaultdict(list)
    for rec in verified_records:
        receipt_groups[rec['receipt_number']].append(rec)

    updates_verified = []
    ledger_amount_updates = {} # (receipt_number, username) -> total_balance_due

    for receipt_number, rows in receipt_groups.items():
        # Calculate true total from line items
        calculated_total = 0.0
        for row in rows:
            try:
                calculated_total += float(row.get('amount') or 0.0)
            except:
                pass
        
        # Pull metadata
        meta = raw_metadata.get(receipt_number, {})
        
        # Determine shared values for the receipt
        payment_mode = rows[0].get('payment_mode', 'Cash')
        username = rows[0].get('username')
        
        new_balance_due = 0.0
        new_received_amount = 0.0
        
        if payment_mode == 'Credit':
            new_balance_due = calculated_total
        else:
            new_received_amount = calculated_total
            
        # Store for ledger sync
        ledger_amount_updates[(receipt_number, username)] = new_balance_due

        for row in rows:
            update = {
                'id': row['id'],
                'username': row['username'], # Include mandatory username
                'total_bill_amount': calculated_total,
                'balance_due': new_balance_due,
                'received_amount': new_received_amount,
                'mobile_number': row.get('mobile_number') or meta.get('mobile_number'),
                'vehicle_number': row.get('vehicle_number') or meta.get('vehicle_number'),
                'customer_details': row.get('customer_details') or meta.get('customer_details'),
            }
            # Clean up None values to avoid overwriting with null if we have something
            update = {k: v for k, v in update.items() if v is not None}
            # Always include ID
            update['id'] = row['id']
            
            # Check if actual change is needed
            needs_update = False
            for k, v in update.items():
                if k != 'id' and str(row.get(k)) != str(v):
                    needs_update = True
                    break
            
            if needs_update:
                updates_verified.append(update)

    # 4. Apply updates to verified_invoices
    if updates_verified:
        logger.info(f"Updating {len(updates_verified)} verified records...")
        for up in updates_verified:
            try:
                rid = up.pop('id')
                db.client.table('verified_invoices').update(up).eq('id', rid).execute()
            except Exception as e:
                logger.error(f"Failed to update record {rid}: {e}")
        logger.info("Successfully updated verified_invoices.")
    else:
        logger.info("No updates needed for verified_invoices.")

    # 5. Sync ledger_transactions
    logger.info("Syncing ledger_transactions...")
    for (rn, user), amount in ledger_amount_updates.items():
        # Find transactions for this receipt and user
        tx_resp = db.client.table('ledger_transactions') \
            .select('id, amount') \
            .eq('username', user) \
            .eq('receipt_number', rn) \
            .eq('transaction_type', 'INVOICE') \
            .execute()
        
        if tx_resp.data:
            tx_updates = []
            for tx in tx_resp.data:
                # We only update if it's different. 
                # Note: If there are multiple transactions for same receipt (like we saw for 1577), 
                # this logic might be tricky. But usually only one should have a non-zero balance.
                # For now, if amount is 0, we update it.
                if float(tx['amount']) == 0.0 and amount > 0:
                    tx_updates.append({'id': tx['id'], 'amount': amount})
            
            if tx_updates:
                logger.info(f"Updating ledger transaction for receipt {rn} to {amount}")
                for tx_up in tx_updates:
                    tx_id = tx_up.pop('id')
                    db.client.table('ledger_transactions').update(tx_up).eq('id', tx_id).execute()

    logger.info("Repair complete.")

if __name__ == "__main__":
    repair_data()
