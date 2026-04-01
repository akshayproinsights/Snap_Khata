import sys
import os

# Set up path
sys.path.append('.')

from config import get_google_api_key
from google import genai
from google.genai import types

api_key = get_google_api_key()
print(f"API Key retrieved: {api_key}")

try:
    client = genai.Client(api_key=api_key)
    response = client.models.generate_content(
        model='gemini-3-flash-preview',
        contents='Hello'
    )
    print("Response:", response.text)
except Exception as e:
    print("Error:", e)
