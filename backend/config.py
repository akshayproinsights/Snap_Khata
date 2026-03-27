"""
Configuration management for the FastAPI backend.
Loads settings from environment variables and secrets.toml
"""
from typing import Dict, Any, Optional
import os

# Trigger reload 2
from pydantic_settings import BaseSettings
from pydantic import Field
import sys
from pathlib import Path

# Add parent directory to path to import configs - REMOVED
# parent_dir = Path(__file__).parent.parent
# sys.path.insert(0, str(parent_dir))

import configs


class Settings(BaseSettings):
    """Application settings"""
    
    # JWT Configuration
    jwt_secret: str = Field(default="your-secret-key-change-in-production", alias="JWT_SECRET")
    jwt_algorithm: str = Field(default="HS256", alias="JWT_ALGORITHM")
    jwt_expire_minutes: int = Field(default=43200, alias="JWT_EXPIRE_MINUTES")  # 30 days
    
    # CORS
    cors_origins: list = Field(default=["http://localhost:3000", "http://localhost:5173", "http://localhost:5174", "http://localhost:5175", "https://snapkhata-prod.web.app", "https://mydigientry.com", "https://www.mydigientry.com", "http://192.168.1.18:8000", "http://192.168.1.18:3000", "http://192.168.1.18:5173", "http://localhost:8080", "http://127.0.0.1:8080"], alias="CORS_ORIGINS")
    
    # Google API
    google_api_key: Optional[str] = Field(default=None, alias="GOOGLE_API_KEY")
    
    class Config:
        env_file = ".env"
        case_sensitive = False
        extra = "ignore"


# Global settings instance
settings = Settings()


def get_r2_config() -> Dict[str, str]:
    """Get Cloudflare R2 configuration from secrets"""
    return configs.get_r2_config()


def get_users_db() -> Dict[str, Dict[str, Any]]:
    """Get users database from secrets"""
    return configs.get_users_db()


def get_user_config(username: str) -> Optional[Dict[str, Any]]:
    """Get single user's config"""
    return configs.get_user_config(username)


def get_google_api_key() -> Optional[str]:
    """Get Google API key for Gemini"""
    if settings.google_api_key:
        return settings.google_api_key
    
    return configs.get_google_api_key()

def get_supabase_config() -> Optional[Dict[str, str]]:
    """
    Returns Supabase configuration.
    Respects APP_ENV (development/production).
    """
    env = os.getenv("APP_ENV", "development").lower()
    
    prefix = "PROD_" if env == "production" else ""
    
    env_config = {
        "url": os.getenv(f"{prefix}SUPABASE_URL") or os.getenv("SUPABASE_URL"),
        "anon_key": os.getenv(f"{prefix}SUPABASE_ANON_KEY") or os.getenv("SUPABASE_ANON_KEY"),
        "service_role_key": os.getenv(f"{prefix}SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_SERVICE_ROLE_KEY")
    }
    
    # If all env vars present, return them
    if all(env_config.values()):
        return env_config
        
    # BACKWARD COMPATIBILITY: Allow SUPABASE_KEY to map to service_role_key
    supabase_key = os.getenv(f"{prefix}SUPABASE_KEY") or os.getenv("SUPABASE_KEY")
    if supabase_key and env_config["url"]:
        return {
            "url": env_config["url"],
            "anon_key": supabase_key,
            "service_role_key": supabase_key
        }
    
    return None


def get_sales_folder(username: str) -> str:
    """
    Get R2 folder path for sales invoice uploads.
    
    Args:
        username: Username to get folder path for
        
    Returns:
        R2 folder path for sales invoices (e.g., "Adnak/sales/")
    """
    return f"{username}/sales/"


def get_purchases_folder(username: str) -> str:
    """
    Get R2 folder path for purchase/vendor invoice uploads.
    
    Args:
        username: Username to get folder path for
        
    Returns:
        R2 folder path for purchase invoices (e.g., "Adnak/purchases/")
    """
    return f"{username}/purchases/"


def get_mappings_folder(username: str) -> str:
    """
    Get R2 folder path for vendor mapping PDF uploads.
    
    Args:
        username: Username to get folder path for
        
    Returns:
        R2 folder path for vendor mappings (e.g., "Adnak/mappings/")
    """
    return f"{username}/mappings/"


def get_inventory_r2_folder(username: str) -> str:
    """
    Get R2 folder path for inventory uploads (vendor invoices).
    DEPRECATED: Use get_purchases_folder() instead.
    
    Args:
        username: Username to get folder path for
        
    Returns:
        R2 folder path for inventory items
    """
    # Use the new purchases folder function for consistency
    return get_purchases_folder(username)
