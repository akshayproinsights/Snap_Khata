import os
from configs import get_google_api_key

# Load environment variables from .env manually to simulate the behavior
from dotenv import load_dotenv
load_dotenv()

api_key = get_google_api_key()
print(f"Gemini API Key: {api_key}")

if api_key == "AIzaSyBGzSAK4Kd7Rb3wSkoOKTCcm52gRhKrWHk":
    print("SUCCESS: API key updated correctly.")
else:
    print("FAILURE: API key mismatch.")
