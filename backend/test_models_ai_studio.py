import os
import sys
# Set up path to import config
sys.path.append('.')
from config import get_google_api_key
from google import genai

def test_ai_studio_models():
    api_key = get_google_api_key()
    if not api_key:
        print("GOOGLE_API_KEY not found in env.")
        return
        
    print(f"Retrieved API Key: {api_key[:10]}...{api_key[-5:]}")
    
    try:
        # Initialize Google Gen AI client with developer API key
        client = genai.Client(api_key=api_key)
        print("Google Gen AI Client initialized.")
    except Exception as e:
        print(f"Failed to initialize client: {e}")
        return

    models_to_test = [
        "gemini-3.1-flash-lite",
        "gemini-3.1-flash-lite-preview",
        "gemini-3.5-flash",
        "gemini-3.5-pro",
    ]
    
    print("\nTesting model access via Google AI Studio:")
    for model_name in models_to_test:
        print(f"Testing '{model_name}'...")
        try:
            response = client.models.generate_content(
                model=model_name,
                contents="Say 'OK' in one word."
            )
            print(f"  -> SUCCESS! Response: {repr(response.text.strip())}")
        except Exception as e:
            print(f"  -> FAILED: {e}")

if __name__ == "__main__":
    test_ai_studio_models()
