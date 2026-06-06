import sys
import os
from google import genai
from google.genai import types

# Define keys to test - load from environment variables, never hardcode secrets!
# Set these before running:
#   export ROOT_GOOGLE_API_KEY="AIzaSy..."
#   export BACKEND_GOOGLE_API_KEY="AQ...."
#   export BACKEND_GOOGLE_API_KEY_FREE="AQ...."
KEYS = {
    "Root GOOGLE_API_KEY": os.environ.get("ROOT_GOOGLE_API_KEY", ""),
    "Backend GOOGLE_API_KEY": os.environ.get("BACKEND_GOOGLE_API_KEY", ""),
    "Backend GOOGLE_API_KEY_FREE": os.environ.get("BACKEND_GOOGLE_API_KEY_FREE", ""),
}

MODELS = [
    "gemini-2.0-flash",
    "gemini-3.1-flash-lite",
    "gemini-3.5-flash"
]

print("Starting Gemini API Keys and Models Connectivity Test...")
print("=" * 80)

for key_name, key_val in KEYS.items():
    masked_key = f"{key_val[:6]}...{key_val[-4:]}" if len(key_val) > 10 else key_val
    print(f"\nTesting API Key: {key_name} ({masked_key})")
    print("-" * 50)
    
    for model in MODELS:
        print(f"  --> Calling model: {model} ... ", end="", flush=True)
        try:
            client = genai.Client(api_key=key_val)
            response = client.models.generate_content(
                model=model,
                contents="Hello, please reply with 'OK' if you can read this."
            )
            print(f"SUCCESS!")
            print(f"      Response: {response.text.strip()}")
        except Exception as e:
            # Format error message to be readable
            err_str = str(e).replace('\n', ' ')
            if len(err_str) > 150:
                err_str = err_str[:150] + "..."
            print(f"FAILED: {err_str}")

print("\n" + "=" * 80)
print("Test complete.")
