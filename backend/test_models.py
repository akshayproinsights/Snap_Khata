import google.auth
import vertexai
from vertexai.generative_models import GenerativeModel

def test_models():
    project = "snapkhataapifree"
    location = "us-central1"
    
    print("Loading Google credentials...")
    try:
        # Load the default credentials (which are using the impersonated service account)
        credentials, _ = google.auth.default()
        
        # Initialize Vertex AI
        vertexai.init(project=project, location=location, credentials=credentials)
        print("Vertex AI initialized successfully.")
    except Exception as e:
        print(f"Failed to initialize credentials/Vertex AI: {e}")
        return

    # A list of Gemini 3.1 and Gemini 3.5 models on Vertex AI to test
    models_to_test = [
        "gemini-3.1-flash-preview",
        "gemini-3.1-pro-preview",
        "gemini-3.1-flash",
        "gemini-3.1-pro",
        "gemini-3.5-flash",
        "gemini-3.5-pro",
        "gemini-3.5-flash-preview",
        "gemini-3.5-pro-preview"
    ]
    
    print(f"\nTesting model access in project '{project}' / location '{location}':")
    
    for model_name in models_to_test:
        print(f"\nTesting '{model_name}'...")
        try:
            model = GenerativeModel(model_name)
            response = model.generate_content("Say 'Access Granted' in exactly two words.")
            print(f"  -> SUCCESS! Response: {repr(response.text.strip())}")
        except Exception as e:
            print(f"  -> FAILED: {e}")

if __name__ == "__main__":
    test_models()
