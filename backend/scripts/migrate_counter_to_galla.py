import os
import sys
from dotenv import load_dotenv
from supabase import create_client, Client

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

def migrate_counter_to_galla():
    print("Starting migration of 'Counter' ledgers to 'galla_transactions'...")
    
    # 1. Find all Counter ledgers
    ledgers_response = supabase.table('customer_ledgers').select('id, username').ilike('customer_name', 'Counter').execute()
    counter_ledgers = ledgers_response.data
    
    if not counter_ledgers:
        print("No 'Counter' ledgers found. Nothing to migrate.")
        return
        
    print(f"Found {len(counter_ledgers)} 'Counter' ledgers.")
    
    for ledger in counter_ledgers:
        ledger_id = ledger['id']
        username = ledger['username']
        
        # 2. Fetch transactions for this ledger
        tx_response = supabase.table('ledger_transactions').select('*').eq('ledger_id', ledger_id).execute()
        transactions = tx_response.data
        
        if not transactions:
            print(f"No transactions found for Counter ledger {ledger_id} (User: {username}).")
            continue
            
        print(f"Migrating {len(transactions)} transactions for user {username}...")
        
        galla_txs = []
        for tx in transactions:
            # Map tx types to Galla types
            # INVOICE -> CASH_SALE
            # PAYMENT -> MONEY_IN
            # MANUAL_CREDIT -> CASH_SALE (maybe they manually added a sale?)
            
            tx_type = 'CASH_SALE'
            if tx['transaction_type'] == 'PAYMENT':
                tx_type = 'MONEY_IN'
                
            galla_txs.append({
                'username': username,
                'transaction_type': tx_type,
                'amount': tx['amount'],
                'notes': tx.get('notes') or tx.get('transaction_type'),
                'receipt_number': tx.get('receipt_number'),
                'created_at': tx['created_at'],
                'updated_at': tx['created_at']
            })
            
        # 3. Insert into galla_transactions
        if galla_txs:
            insert_resp = supabase.table('galla_transactions').insert(galla_txs).execute()
            print(f"Inserted {len(insert_resp.data)} galla transactions for {username}.")
            
        # 4. Optional: Delete the old Counter ledger
        # We delete it so it no longer appears in the parties list
        print(f"Deleting old Counter ledger {ledger_id}...")
        supabase.table('customer_ledgers').delete().eq('id', ledger_id).execute()
        
    print("Migration complete!")

if __name__ == "__main__":
    migrate_counter_to_galla()
