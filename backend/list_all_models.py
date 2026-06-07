import google.auth
from google import genai

def list_all_models():
    project = "snapkhataapifree"
    location = "us-central1"
    
    print("Loading Google credentials...")
    try:
        credentials, _ = google.auth.default()
        
        # Initialize the Google Gen AI client with Vertex AI integration
        client = genai.Client(
            vertexai=True,
            project=project,
            location=location,
            credentials=credentials
        )
        print("Google Gen AI client initialized with Vertex AI.")
    except Exception as e:
        print(f"Failed to initialize client: {e}")
        return

    print(f"\nQuerying available foundational models for project '{project}' / region '{location}'...")
    
    try:
        # List all available models
        models = list(client.models.list())
        
        if not models:
            print("No models returned.")
            return
            
        print(f"Found {len(models)} available model(s):")
        # Sort and print
        for model in sorted(models, key=lambda m: m.name):
            print(f"- {model.name}")
            
    except Exception as e:
        print(f"Failed to list models: {e}")

if __name__ == "__main__":
    list_all_models()
