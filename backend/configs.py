from typing import Dict, Any, Optional
import os
import json

# Try to load python-dotenv if available (for .env file support)
try:
    from dotenv import load_dotenv
    import os
    # 1. Load .env file from current directory (backend/)
    dotenv_path_backend = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".env")
    if os.path.exists(dotenv_path_backend):
        load_dotenv(dotenv_path_backend, override=True)
        
    # 2. Load .env file from root directory (parent)
    dotenv_path_root = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), ".env")
    if os.path.exists(dotenv_path_root):
        load_dotenv(dotenv_path_root, override=True)
except Exception:
    pass  # python-dotenv not installed, will use system env vars only





def get_r2_config() -> Dict[str, Any]:
    """
    Returns the cloudflare_r2 configuration as a dict.
    Strictly uses environment variables.
    """
    account_id = os.getenv("CLOUDFLARE_R2_ACCOUNT_ID") or os.getenv("R2_ACCOUNT_ID")
    endpoint_url = os.getenv("CLOUDFLARE_R2_ENDPOINT_URL") or os.getenv("R2_ENDPOINT_URL")
    access_key_id = os.getenv("CLOUDFLARE_R2_ACCESS_KEY_ID") or os.getenv("R2_ACCESS_KEY_ID")
    secret_access_key = os.getenv("CLOUDFLARE_R2_SECRET_ACCESS_KEY") or os.getenv("R2_SECRET_ACCESS_KEY")
    public_base_url = os.getenv("CLOUDFLARE_R2_PUBLIC_BASE_URL") or os.getenv("R2_PUBLIC_BASE_URL")
    
    # Support for multiple bucket-specific domains
    bucket_domains_raw = os.getenv("R2_BUCKET_DOMAINS")
    
    bucket_domains = {}
    if bucket_domains_raw:
        try:
            bucket_domains = json.loads(bucket_domains_raw)
        except Exception as e:
            print(f"Error parsing R2_BUCKET_DOMAINS: {e}")

    if account_id and access_key_id and secret_access_key:
        if not endpoint_url:
            endpoint_url = f"https://{account_id}.r2.cloudflarestorage.com"
        
        return {
            "account_id": account_id,
            "endpoint_url": endpoint_url,
            "access_key_id": access_key_id,
            "secret_access_key": secret_access_key,
            "public_base_url": public_base_url,
            "bucket_domains": bucket_domains
        }
    
    return {}


def get_users_db() -> Dict[str, Dict[str, Any]]:
    """
    Returns a dict of users from environment variables:
      { username: { password: str, r2_bucket: str, sheet_id?: str, dashboard_url?: str } }
    """
    import base64
    
    # Check Base64 environment variable first (Safe for GitHub Actions)
    users_b64 = os.getenv("USERS_CONFIG_JSON_BASE64")
    users_json = None
    
    if users_b64:
        try:
            users_json = base64.b64decode(users_b64).decode('utf-8')
        except Exception as e:
            print(f"Error decoding USERS_CONFIG_JSON_BASE64: {e}")

    # Fallback to raw JSON env var
    if not users_json:
        users_json = os.getenv("USERS_CONFIG_JSON")

    if users_json:
        try:
            users = json.loads(users_json)
            if isinstance(users, dict):
                # Handle case where JSON is wrapped in "users" key
                if "users" in users and isinstance(users["users"], dict):
                    return users["users"]
                return users
        except json.JSONDecodeError:
            pass
    
    return {}


def get_user_config(username: str) -> Optional[Dict[str, Any]]:
    """Return single user's config dict or None if not found."""
    users = get_users_db()
    return users.get(username)


def get_google_api_key() -> Optional[str]:
    """
    Returns the Google API key for Gemini AI.
    Strictly uses environment variables.
    """
    return os.getenv("GOOGLE_API_KEY") or os.getenv("GEMINI_API_KEY")