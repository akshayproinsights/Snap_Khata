import asyncio
import sys
import os
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'backend'))
from routes.public_routes import get_shop_logo_proxy

async def main():
    try:
        res = await get_shop_logo_proxy(u="jadhav")
        print("Success!")
        print("Status/Type:", res.media_type)
        print("Content length:", len(res.body))
    except Exception as e:
        print("Error:", e)

asyncio.run(main())
