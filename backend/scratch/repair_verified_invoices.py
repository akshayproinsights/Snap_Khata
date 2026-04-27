import os
import sys
import logging

# Add the current directory to sys.path to import local modules
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))

from database import get_database_client
from database_helpers import convert_numeric_types

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# The core columns we want to populate
CORE_COLS = [
    'received_amount', 'balance_due', 'payment_mode', 'mobile_number',
    'customer_details', 'car_number', 'vehicle_number', 
    'total_bill_amount', 'gst_mode', 'odometer', 'quantity', 'rate'
]

def repair_table(table_name):
    db = get_database_client()
    
    logger.info(f"--- Repairing table: {table_name} ---")
    
    # Heuristic: get one record to see available columns, or just use the first record in the fetch
    logger.info(f"Fetching records from {table_name}...")
    response = db.client.table(table_name).select('*').execute()
    records = response.data if response.data else []
    
    if not records:
        logger.info(f"No records found in {table_name}.")
        return
        
    # Get available columns from the first record
    available_cols = set(records[0].keys())
    logger.info(f"Available columns in {table_name}: {available_cols}")
    
    logger.info(f"Processing {len(records)} records...")
    
    updates = []
    for record in records:
        extra_fields = record.get('extra_fields', {})
        if not extra_fields or not isinstance(extra_fields, dict):
            continue
            
        modified = False
        new_record = record.copy()
        
        for col in CORE_COLS:
            # ONLY move if the column exists in the table schema
            if col in extra_fields and col in available_cols:
                val = extra_fields[col]
                current_val = record.get(col)
                
                # Heuristic: if current is default but extra has data, move it
                is_default = current_val is None or current_val == 0 or current_val == 0.0 or current_val == ''
                if is_default and val is not None and val != '':
                    new_record[col] = val
                    modified = True
                    logger.info(f"  {table_name} {record['id']}: Moving '{col}'={val} from extra_fields to top-level")

        if modified:
            new_record = convert_numeric_types(new_record)
            updates.append(new_record)
            
    if not updates:
        logger.info(f"No records in {table_name} needed repair.")
        return
        
    logger.info(f"Applying {len(updates)} updates to {table_name}...")
    
    # To be absolutely sure we don't send extra columns that might have been in the record but not in the schema
    # (though select('*') should have only returned schema columns)
    # we'll filter new_record to only available_cols
    for i in range(len(updates)):
        updates[i] = {k: v for k, v in updates[i].items() if k in available_cols}

    count = db.batch_upsert(table_name, updates, batch_size=100, on_conflict='id')
    logger.info(f"✅ Successfully repaired {count} records in {table_name}.")

if __name__ == "__main__":
    # verified_invoices was already partially repaired, but let's run it again to be thorough
    repair_table('verified_invoices')
    repair_table('invoices')
