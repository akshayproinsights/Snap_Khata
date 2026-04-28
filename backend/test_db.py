import asyncio
from utils.database import db
async def test():
    try:
        res = db.execute_query("SELECT column_name FROM information_schema.columns WHERE table_name = 'verification_dates'")
        print(res)
    except Exception as e:
        print(e)
asyncio.run(test())
