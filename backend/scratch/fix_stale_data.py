
from database import get_database_client
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def fix_user_data(username):
    db = get_database_client()
    
    # 1. Fix Receipt 827 (Should be Cash)
    logger.info(f"Fixing Receipt 827 for {username} -> Cash")
    db.client.table('verified_invoices').update({
        'payment_mode': 'Cash',
        'balance_due': 0.0,
        'received_amount': 1559.0 # Total for 827
    }).eq('username', username).eq('receipt_number', '827').execute()
    
    db.client.table('invoices').update({
        'payment_mode': 'Cash',
        'balance_due': 0.0,
        'received_amount': 1559.0
    }).eq('username', username).eq('receipt_number', '827').execute()

    # 2. Fix Receipt 823 (Should be Credit with proper balance)
    # Total for 823 is the sum of all items.
    res_823 = db.client.table('verified_invoices').select('amount').eq('username', username).eq('receipt_number', '823').execute()
    total_823 = sum(float(r['amount']) for r in res_823.data)
    logger.info(f"Fixing Receipt 823 for {username} -> Credit (Total: {total_823})")
    
    db.client.table('verified_invoices').update({
        'payment_mode': 'Credit',
        'balance_due': total_823,
        'received_amount': 0.0
    }).eq('username', username).eq('receipt_number', '823').execute()
    
    db.client.table('invoices').update({
        'payment_mode': 'Credit',
        'balance_due': total_823,
        'received_amount': 0.0
    }).eq('username', username).eq('receipt_number', '823').execute()

    # 3. Fix Receipt 824 (Renamed name, check balance)
    res_824 = db.client.table('verified_invoices').select('amount').eq('username', username).eq('receipt_number', '824').execute()
    total_824 = sum(float(r['amount']) for r in res_824.data)
    logger.info(f"Fixing Receipt 824 for {username} -> Credit (Total: {total_824})")
    
    db.client.table('verified_invoices').update({
        'payment_mode': 'Credit',
        'balance_due': total_824,
        'received_amount': 0.0
    }).eq('username', username).eq('receipt_number', '824').execute()
    
    db.client.table('invoices').update({
        'payment_mode': 'Credit',
        'balance_due': total_824,
        'received_amount': 0.0
    }).eq('username', username).eq('receipt_number', '824').execute()

    print("DB Fixes applied. Now triggering ledger re-sync...")
    
    # Trigger re-sync via the API logic
    import asyncio
    from routes.udhar import sync_customer_ledgers_from_invoices
    
    async def run_sync():
        await sync_customer_ledgers_from_invoices({"username": username})
        print("Ledger re-sync completed.")

    asyncio.run(run_sync())

if __name__ == "__main__":
    fix_user_data('akshaykh')
