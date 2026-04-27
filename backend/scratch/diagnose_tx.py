from database import get_database_client
import asyncio

async def test():
    db = get_database_client()
    try:
        res = db.client.table('ledger_transactions').select('*').eq('customer_name', 'Akshay').execute()
        print("Success:", res.data)
    except Exception as e:
        print("Error:", e)

if __name__ == "__main__":
    asyncio.run(test())
