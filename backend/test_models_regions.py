import google.auth
import vertexai
from vertexai.generative_models import GenerativeModel

def test_models_across_regions():
    regions = ["us-central1", "us-east4", "europe-west1", "asia-east1"]
    project = "snapkhataapifree"
    
    # Load credentials
    try:
        credentials, _ = google.auth.default()
    except Exception as e:
        print(f"Failed to load credentials: {e}")
        return

    # List of models to test
    models_to_test = [
        "gemini-3.1-flash-lite",
        "gemini-3.1-flash-lite-preview",
        "gemini-3.5-flash",
        "gemini-3.5-pro",
    ]
    
    for region in regions:
        print(f"\n=========================================")
        print(f"Testing in Region: '{region}'")
        print(f"=========================================")
        try:
            vertexai.init(project=project, location=region, credentials=credentials)
        except Exception as e:
            print(f"Failed to initialize Vertex AI for region {region}: {e}")
            continue
            
        for model_name in models_to_test:
            print(f"Testing '{model_name}'...")
            try:
                model = GenerativeModel(model_name)
                response = model.generate_content("Say 'OK' in one word.")
                print(f"  -> SUCCESS! Response: {repr(response.text.strip())}")
            except Exception as e:
                # Print short error message to keep it clean
                error_msg = str(e).split('\n')[0]
                print(f"  -> FAILED: {error_msg}")

if __name__ == "__main__":
    test_models_across_regions()
