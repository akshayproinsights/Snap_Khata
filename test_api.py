import sys
import os
import asyncio
sys.path.append(os.path.join(os.path.dirname(__file__), 'backend'))
from auth import create_access_token

token = create_access_token(data={"sub": "onkar", "role": "admin"})
print(token)
