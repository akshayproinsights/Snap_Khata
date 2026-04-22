import asyncio
import os
import sys

# Add backend to path
sys.path.append('/root/Snap_Khata/backend')

from database import get_database_client

async def explore():
    db = get_database_client()
    
    # 1. List all users and their ledger counts
    print("--- Users and Customer Ledger Counts ---")
    users_resp = db.client.table('customer_ledgers').select('username', count='exact').execute()
    # We need to aggregate visually
    counts = {}
    for item in (users_resp.data or []):
        u = item['username']
        counts[u] = counts.get(u, 0) + 1
    for u, c in counts.items():
        print(f"User: {u}, Ledgers: {c}")

    # 2. Search for "Arjun Jadhav" across all users
    print("\n--- Searching for Arjun Jadhav ---")
    arjun_resp = db.client.table('customer_ledgers').select('*').ilike('customer_name', '%Arjun%').execute()
    for row in (arjun_resp.data or []):
        print(f"Row: {row}")
        
    # 3. If found, check his transactions
    if arjun_resp.data:
        ledger_id = arjun_resp.data[0]['id']
        username = arjun_resp.data[0]['username']
        tx_resp = db.client.table('ledger_transactions').select('*').eq('ledger_id', ledger_id).execute()
        print(f"\n--- Transactions for {arjun_resp.data[0]['customer_name']} (User: {username}) ---")
        for tx in (tx_resp.data or []):
            print(f"TX: {tx}")
            
    # 4. Check verified_invoices for Arjun Jadhav
    print("\n--- Verified Invoices for Arjun Jadhav ---")
    vi_resp = db.client.table('verified_invoices').select('*').ilike('customer_name', '%Arjun%').execute()
    for vi in (vi_resp.data or []):
        print(f"VI: {vi}")

    # 3. Check Customer Ledger for Arjun
    ledger_resp = db.client.table('customer_ledgers') \
        .select('*') \
        .eq('username', 'Akshay_K') \
        .ilike('customer_name', '%Arjun%') \
        .execute()
    
    print(f"\n--- Customer Ledger for Arjun Jadhav ---")
    if ledger_resp.data:
        ledger = ledger_resp.data[0]
        print(f"Ledger ID: {ledger['id']}")
        print(f"Customer Name: {ledger['customer_name']}")
        print(f"Balance Due: {ledger['balance_due']}")
        
        # 4. Check Transactions for this ledger
        tx_resp = db.client.table('ledger_transactions') \
            .select('*') \
            .eq('ledger_id', ledger['id']) \
            .execute()
        
        print(f"\n--- Ledger Transactions ({len(tx_resp.data or [])}) ---")
        for tx in (tx_resp.data or []):
            print(f"Type: {tx['transaction_type']}, Amount: {tx['amount']}, Receipt: {tx.get('receipt_number')}")
    else:
        print("No ledger found for Arjun.")

if __name__ == "__main__":
    asyncio.run(explore())
