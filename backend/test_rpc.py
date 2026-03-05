import os
from supabase import create_client

url = os.getenv('SUPABASE_URL')
key = os.getenv('SUPABASE_SERVICE_ROLE_KEY')
client = create_client(url, key)

try:
    res = client.rpc('exec_sql', {'sql': 'SELECT 1;'}).execute()
    print('RPC exec_sql works:', res.data)
except Exception as e:
    print('Error:', e)
