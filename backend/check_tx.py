from dotenv import load_dotenv
import os
from supabase import create_client

load_dotenv()
url = os.getenv("SUPABASE_URL")
key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
sb = create_client(url, key)

res = sb.table('ledger_transactions').select('id, transaction_type, amount, receipt_number').limit(5).execute()
print("Customer Tx:", res.data)

res2 = sb.table('vendor_ledger_transactions').select('id, transaction_type, amount, invoice_number').limit(5).execute()
print("Vendor Tx:", res2.data)
