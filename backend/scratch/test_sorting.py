import sys
import os
from datetime import datetime
from typing import Dict, Any

# Mock the functions to test
def parse_date_to_iso(date_str: Any) -> str:
    if not date_str:
        return "0000-00-00T00:00:00"
    if isinstance(date_str, datetime):
        return date_str.isoformat()
    
    date_str = str(date_str).strip()
    if not date_str:
        return "0000-00-00T00:00:00"

    try:
        return datetime.fromisoformat(date_str.replace('Z', '+00:00')).isoformat()
    except:
        pass

    try:
        return datetime.strptime(date_str, "%d-%b-%Y").isoformat()
    except:
        pass

    try:
        return datetime.strptime(date_str, "%d/%m/%Y").isoformat()
    except:
        pass

    return date_str

def get_transaction_sort_key(tx: Dict):
    primary_raw = tx.get('invoice_date') or tx.get('date')
    if not primary_raw:
        primary_raw = tx.get('created_at') or ''
    
    primary_iso = parse_date_to_iso(primary_raw)
    
    secondary_raw = tx.get('upload_date') or tx.get('created_at') or ''
    secondary_iso = parse_date_to_iso(secondary_raw)
    
    return (primary_iso, secondary_iso)

# Test cases
transactions = [
    {
        'id': 1,
        'invoice_date': '04-Nov-2025',
        'created_at': '2026-05-01T10:00:00',
        'type': 'Cash Sale'
    },
    {
        'id': 2,
        'date': '04-May-2026',
        'created_at': '2026-05-04T12:00:00',
        'type': 'Payment'
    },
    {
        'id': 3,
        'invoice_date': '04-May-2026',
        'created_at': '2026-05-04T14:00:00', # Same day as id 2, but created later
        'type': 'Credit Sale'
    },
    {
        'id': 4,
        'invoice_date': '01-Jan-2024',
        'created_at': '2026-05-06T08:00:00', # Uploaded today but very old
        'type': 'Old Invoice'
    }
]

print("Original order:")
for tx in transactions:
    print(f"ID: {tx['id']}, Type: {tx['type']}, Date: {tx.get('invoice_date') or tx.get('date')}, Created: {tx['created_at']}")

transactions.sort(key=get_transaction_sort_key, reverse=True)

print("\nSorted order (latest first):")
for tx in transactions:
    print(f"ID: {tx['id']}, Type: {tx['type']}, Date: {tx.get('invoice_date') or tx.get('date')}, Created: {tx['created_at']}")

# Expected order:
# 1. ID 3 (04 May 2026, Created 14:00)
# 2. ID 2 (04 May 2026, Created 12:00)
# 3. ID 1 (04 Nov 2025)
# 4. ID 4 (01 Jan 2024)
