import google.auth
from google import genai
from google.genai import types

def test_global_models():
    project = "snapkhataapifree"
    location = "global"
    
    print("Loading Google credentials...")
    try:
        credentials, _ = google.auth.default()
        
        # Initialize the client targeting the 'global' region
        client = genai.Client(
            vertexai=True,
            project=project,
            location=location
        )
        print(f"Client initialized successfully for location '{location}'.")
    except Exception as e:
        print(f"Failed to initialize client: {e}")
        return

    # A list of Gemini 3.1 and 3.5 models to test on the global endpoint
    models_to_test = [
        "gemini-3.1-pro",
        "gemini-3.5-pro-preview"
    ]
    
    print(f"\nTesting model access on global endpoint (project: '{project}'):")
    
    for model_name in models_to_test:
        print(f"\nTesting '{model_name}'...")
        try:
            contents = [
                types.Content(
                    role="user",
                    parts=[
                        types.Part.from_text(text="Say 'Access Granted' in exactly two words.")
                    ]
                )
            ]
            response = client.models.generate_content(
                model=model_name,
                contents=contents
            )
            print(f"  -> SUCCESS! Response: {repr(response.text.strip())}")
        except Exception as e:
            error_msg = str(e).split('\n')[0]
            print(f"  -> FAILED: {error_msg}")

if __name__ == "__main__":
    test_global_models()
