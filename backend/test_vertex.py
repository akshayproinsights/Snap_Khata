import os
import google.auth
from google.auth import impersonated_credentials
from google.cloud import aiplatform

def list_datasets(impersonate_sa=None):
    """
    Lists Vertex AI datasets.
    
    Args:
        impersonate_sa (str, optional): Email of the service account to impersonate.
                                        If None, uses the current environment's ADC.
    """
    project = "snapkhataapifree"
    location = "us-central1"

    print("Initializing Vertex AI authentication...")
    
    credentials = None
    if impersonate_sa:
        print(f"Attempting to impersonate service account: {impersonate_sa}")
        try:
            # Get the source user/instance credentials from the environment (ADC)
            source_credentials, _ = google.auth.default()
            
            # Create impersonated credentials using the source credentials
            target_scopes = ["https://www.googleapis.com/auth/cloud-platform"]
            credentials = impersonated_credentials.Credentials(
                source_credentials=source_credentials,
                target_principal=impersonate_sa,
                target_scopes=target_scopes,
            )
            print("Successfully set up impersonation credentials.")
        except Exception as e:
            print(f"Failed to set up impersonation: {e}")
            print("Falling back to standard Application Default Credentials (ADC)...")
            credentials = None

    # Initialize the Vertex AI SDK
    # If credentials is None, it automatically falls back to ADC
    aiplatform.init(project=project, location=location, credentials=credentials)

    print(f"Checking Vertex AI datasets in project '{project}'...")

    try:
        # Import the parent _Dataset class to list all dataset types
        from google.cloud.aiplatform.datasets.dataset import _Dataset
        datasets = _Dataset.list()
        
        if not datasets:
            print("Successfully connected! No datasets found (normal if you haven't created any yet).")
        else:
            print(f"Found {len(datasets)} dataset(s):")
            for ds in datasets:
                print(f"- {ds.display_name} ({ds.resource_name})")
                
    except Exception as e:
        print(f"An error occurred: {e}")
        print("\nTroubleshooting tips:")
        print("1. If using ADC, make sure you ran: gcloud auth application-default login")
        print("2. If impersonating, make sure you have the 'roles/iam.serviceAccountTokenCreator' role on the service account:")
        print("   gcloud iam service-accounts add-iam-policy-binding YOUR_SERVICE_ACCOUNT \\")
        print("       --member='user:YOUR_USER_EMAIL' \\")
        print("       --role='roles/iam.serviceAccountTokenCreator'")

if __name__ == "__main__":
    # Option A: Run using your logged-in user credentials (ADC)
    # This works if snapkhata1@gmail.com is running the code and has aiplatform.user role (or Owner).
    list_datasets()
    
    # Option B: Run by impersonating the service account (uncomment to test)
    # list_datasets(impersonate_sa="snap-service@snapkhataapifree.iam.gserviceaccount.com")
