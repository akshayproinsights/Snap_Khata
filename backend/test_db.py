import asyncio
from database import get_db
db = get_db()
async def main():
    res = db.execute_query("SELECT column_name, ordinal_position, data_type, is_nullable, column_default FROM information_schema.columns WHERE table_name = 'verified_invoices' ORDER BY ordinal_position;")
    for row in res.data:
        print(row)
asyncio.run(main())
