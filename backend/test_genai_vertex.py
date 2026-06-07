import os
from google import genai
from google.genai import types

def test_gemini_3_5():
    print("Initializing Google Gen AI Client with Vertex AI...")
    locations = ["us-central1", "global", "us", "eu"]
    model = "gemini-3.5-flash"
    
    for loc in locations:
        print(f"\nTrying location '{loc}'...")
        try:
            client = genai.Client(
                vertexai=True,
                project="snapkhataapifree",
                location=loc
            )
            contents = [
                types.Content(
                    role="user",
                    parts=[
                        types.Part.from_text(text="Say 'Connected' in exactly one word.")
                    ]
                )
            ]
            response = client.models.generate_content(
                model=model,
                contents=contents
            )
            print(f"-> SUCCESS in '{loc}'! Response: {repr(response.text.strip())}")
            return # Exit early if we find a working one
        except Exception as e:
            error_msg = str(e).split('\n')[0]
            print(f"-> FAILED in '{loc}': {error_msg}")

if __name__ == "__main__":
    test_gemini_3_5()
