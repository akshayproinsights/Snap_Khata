import asyncio
import sys
import os
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'backend'))
from routes.public_routes import get_public_receipt

async def main():
    res = await get_public_receipt("REC-00001", u=None)
    print(res)

asyncio.run(main())
