"""
User Configuration Loader Service
Loads industry templates and user configs, merges them, and provides config to the application.
"""
import json
import os
from pathlib import Path
from typing import Dict, Any, Optional
import logging
from copy import deepcopy

logger = logging.getLogger(__name__)

# Paths
BASE_DIR = Path(__file__).parent
USER_CONFIGS_DIR = BASE_DIR / "user_configs"
TEMPLATES_DIR = USER_CONFIGS_DIR / "templates"

# Cache for loaded configs
_config_cache: Dict[str, Dict[str, Any]] = {}
_template_cache: Dict[str, Dict[str, Any]] = {}

# Default industry when all else fails
_DEFAULT_INDUSTRY = "general"


def load_template(industry: str) -> Optional[Dict[str, Any]]:
    """
    Load an industry template from templates directory.
    
    Args:
        industry: Industry name (e.g., 'automobile', 'medical')
    
    Returns:
        Template config dict or None if not found
    """
    global _template_cache
    
    # Check cache first
    if industry in _template_cache:
        return deepcopy(_template_cache[industry])
    
    template_path = TEMPLATES_DIR / f"{industry}.json"
    
    if not template_path.exists():
        logger.warning(f"Template not found: {industry}")
        return None
    
    try:
        with open(template_path, 'r', encoding='utf-8') as f:
            template = json.load(f)
        
        _template_cache[industry] = template
        logger.info(f"Loaded template: {industry}")
        return deepcopy(template)
    
    except Exception as e:
        logger.error(f"Error loading template {industry}: {e}")
        return None


def _get_user_industry_from_db(username: str) -> Optional[Dict[str, str]]:
    """
    Query the database for a user's industry and r2_bucket.
    Returns dict with 'industry', 'r2_bucket', 'display_name' or None on failure.
    This is only called when the per-user config file does not exist.
    """
    try:
        from database import get_database_client
        db = get_database_client()
        resp = (
            db.client.table("users")
            .select("username,industry,r2_bucket")
            .eq("username", username)
            .limit(1)
            .execute()
        )
        if resp.data:
            row = resp.data[0]
            return {
                "industry":    row.get("industry") or _DEFAULT_INDUSTRY,
                "r2_bucket":   row.get("r2_bucket") or "snapkhata-prod",
                "display_name": row.get("display_name") or "",
            }
        # Try case-insensitive (some old usernames may differ)
        resp2 = (
            db.client.table("users")
            .select("username,industry,r2_bucket")
            .ilike("username", username)
            .limit(1)
            .execute()
        )
        if resp2.data:
            row = resp2.data[0]
            return {
                "industry":    row.get("industry") or _DEFAULT_INDUSTRY,
                "r2_bucket":   row.get("r2_bucket") or "snapkhata-prod",
                "display_name": row.get("display_name") or "",
            }
        logger.warning(f"User '{username}' not found in DB — will use general template")
        return None
    except Exception as e:
        logger.error(f"DB lookup failed for user '{username}': {e} — falling back to general template")
        return None


def load_user_config(username: str, bypass_cache: bool = False) -> Optional[Dict[str, Any]]:
    """
    Load user configuration using a 3-tier fallback strategy:

      Tier 1 — Per-user JSON file (user_configs/{username}.json)
               For power users / existing users with custom prompts.
               Merged with their template if 'extends_template' is set.

      Tier 2 — DB-backed template lookup
               Query the `users` table for their registered `industry`,
               load the matching template, stamp username/r2_bucket.
               Works for ALL self-registered users with no per-user file.

      Tier 3 — General template hardcoded fallback
               Used if the DB is unreachable. Ensures the system never
               returns None for a valid username.

    Args:
        username:     Username (e.g., 'adnak', 'yogeshwari')
        bypass_cache: If True, force reload from disk / DB

    Returns:
        Merged config dict (never None for a real user).
        Returns None only if even the 'general' template is broken.
    """
    global _config_cache

    # ── Cache check ──────────────────────────────────────────────────────────
    if not bypass_cache and username in _config_cache:
        return deepcopy(_config_cache[username])

    # ── Tier 1: Per-user JSON file ────────────────────────────────────────────
    user_config_path = USER_CONFIGS_DIR / f"{username}.json"

    # CASE SENSITIVITY FIX: try lowercase filename if exact match not found
    if not user_config_path.exists():
        lowercase_path = USER_CONFIGS_DIR / f"{username.lower()}.json"
        if lowercase_path.exists():
            logger.info(f"User config found with lowercase name: {username.lower()}")
            user_config_path = lowercase_path

    if user_config_path.exists():
        try:
            with open(user_config_path, 'r', encoding='utf-8') as f:
                user_config = json.load(f)

            logger.info(f"[Tier 1] Loaded per-user config: {username}")

            # Merge with industry template if requested
            if "extends_template" in user_config:
                industry = user_config["extends_template"]
                template = load_template(industry)
                if template:
                    merged_config = merge_configs(template, user_config)
                else:
                    logger.warning(f"Template '{industry}' not found for {username}, using user config only")
                    merged_config = user_config
            else:
                merged_config = user_config

            _config_cache[username] = merged_config
            return deepcopy(merged_config)

        except json.JSONDecodeError as e:
            logger.error(f"[Tier 1] Per-user config for '{username}' has invalid JSON: {e} — falling to Tier 2")
        except Exception as e:
            logger.error(f"[Tier 1] Failed to load config for '{username}': {e} — falling to Tier 2")

    else:
        logger.info(f"[Tier 2] No per-user config file for '{username}' — looking up industry from DB")

    # ── Tier 2: DB-backed industry template ───────────────────────────────────
    db_info = _get_user_industry_from_db(username)
    if db_info:
        industry  = db_info["industry"]
        r2_bucket = db_info["r2_bucket"]
        display   = db_info["display_name"]
    else:
        logger.warning(f"[Tier 3] DB lookup failed for '{username}' — using general template as last resort")
        industry  = _DEFAULT_INDUSTRY
        r2_bucket = "snapkhata-prod"
        display   = ""

    template = load_template(industry)
    if template is None and industry != _DEFAULT_INDUSTRY:
        logger.warning(f"Template '{industry}' not found — falling back to '{_DEFAULT_INDUSTRY}'")
        template = load_template(_DEFAULT_INDUSTRY)

    if template is None:
        logger.error(f"CRITICAL: Even the '{_DEFAULT_INDUSTRY}' template could not be loaded for '{username}'")
        return None

    # Stamp identity fields so the rest of the system works correctly
    import copy
    config = copy.deepcopy(template)
    config["username"]  = username
    config["industry"]  = industry
    config["r2_bucket"] = r2_bucket
    if display:
        config["display_name"] = display

    tier = "2" if db_info else "3"
    logger.info(f"[Tier {tier}] Loaded '{industry}' template config for '{username}' (r2={r2_bucket})")

    _config_cache[username] = config
    return deepcopy(config)


def merge_configs(template: Dict[str, Any], user_overrides: Dict[str, Any]) -> Dict[str, Any]:
    """
    Merge template config with user-specific overrides.
    
    Args:
        template: Base template config
        user_overrides: User-specific config with overrides
    
    Returns:
        Merged configuration
    """
    # Start with deep copy of template
    merged = deepcopy(template)
    #
    
    # Override top-level fields from user config
    for key in ['username', 'display_name', 'r2_bucket', 'dashboard_url', 'industry']:
        if key in user_overrides:
            merged[key] = user_overrides[key]
    
    # Apply column label overrides
    if "column_label_overrides" in user_overrides and "columns" in merged:
        overrides = user_overrides["column_label_overrides"]
        
        # Apply to all column sections (invoice_all, verify_dates, etc.)
        for section_name, columns in merged["columns"].items():
            for column in columns:
                db_column = column.get("db_column")
                if db_column in overrides:
                    column["label"] = overrides[db_column]
                    logger.debug(f"Overrode label for {db_column}: {overrides[db_column]}")
    
    # Apply custom gemini prompt if provided
    if "gemini" in user_overrides:
        merged["gemini"] = user_overrides["gemini"]
    
    # Apply custom columns if provided (complete override)
    if "columns" in user_overrides:
        merged["columns"] = user_overrides["columns"]
    
    return merged


def get_user_config(username: str) -> Optional[Dict[str, Any]]:
    """
    Main entry point to get user configuration.
    Convenience wrapper around load_user_config.
    
    Args:
        username: Username
    
    Returns:
        User configuration dict or None
    """
    return load_user_config(username)


def get_gemini_prompt(username: str) -> Optional[str]:
    """
    Get the Gemini system instruction for a user.
    
    Args:
        username: Username
    
    Returns:
        Gemini prompt string or None
    """
    config = get_user_config(username)
    if config and "gemini" in config:
        return config["gemini"].get("system_instruction")
    return None


def get_columns_config(username: str, section: str = "invoice_all") -> Optional[list]:
    """
    Get column configuration for a specific section.
    
    Args:
        username: Username
        section: Column section name ('invoice_all', 'verify_dates', 'verify_amounts', 'verified')
    
    Returns:
        List of column definitions or None
    """
    config = get_user_config(username)
    if config and "columns" in config:
        return config["columns"].get(section)
    return None


def clear_cache():
    """Clear all cached configs (useful for development/testing)"""
    global _config_cache, _template_cache
    _config_cache.clear()
    _template_cache.clear()
    logger.info("Config cache cleared")


def list_available_users() -> list:
    """
    List all available user configurations.
    
    Returns:
        List of usernames
    """
    if not USER_CONFIGS_DIR.exists():
        return []
    
    users = []
    for file in USER_CONFIGS_DIR.glob("*.json"):
        users.append(file.stem)  # filename without extension
    
    return users


# ── Industry/Registration helpers ────────────────────────────────────────────

# Human-readable metadata for each template
_INDUSTRY_META: Dict[str, Dict[str, str]] = {
    "automobile": {"display": "Automobile / Garage",         "icon": "🚗"},
    "medical":    {"display": "Medical / Pharmacy",          "icon": "💊"},
    "grocery":    {"display": "Grocery / Kirana Store",      "icon": "🛒"},
    "hardware":   {"display": "Hardware / Building Materials","icon": "🔧"},
    "restaurant": {"display": "Restaurant / Food",           "icon": "🍽️"},
    "clothing":   {"display": "Clothing / Textile",          "icon": "👗"},
    "electronics":{"display": "Electronics",                 "icon": "📱"},
    "general":    {"display": "General / Other",             "icon": "🏪"},
}


def list_available_industries() -> list:
    """
    List all industry template IDs that have a JSON file in templates/.

    Returns:
        List of dicts: [{"id": "automobile", "display": "...", "icon": "..."}]
    """
    if not TEMPLATES_DIR.exists():
        return []

    industries = []
    for f in sorted(TEMPLATES_DIR.glob("*.json")):
        industry_id = f.stem
        meta = _INDUSTRY_META.get(industry_id, {"display": industry_id.title(), "icon": "🏪"})
        industries.append({
            "id": industry_id,
            "display": meta["display"],
            "icon": meta["icon"],
        })
    return industries


def create_user_config_from_template(
    username: str,
    industry: str,
    r2_bucket: str,
    display_name: str = "",
    extra: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    """
    Generate and persist a user config JSON from an industry template.

    This is called at registration time so the new user immediately has a
    valid config that the rest of the system (config_loader, inventory_processor,
    etc.) can consume.

    Args:
        username:     The new user's username (used as filename).
        industry:     Industry template ID (e.g. 'grocery').  Falls back to
                      'general' if the template does not exist.
        r2_bucket:    Cloudflare R2 bucket name for the user.
        display_name: Optional human-readable shop name.
        extra:        Any additional key/value overrides to merge into the config.

    Returns:
        The final config dict that was persisted to disk.

    Raises:
        ValueError: If both the requested template AND 'general' are missing.
    """
    # Load requested template (fall back to 'general')
    template = load_template(industry)
    fallback_used = False
    if template is None:
        logger.warning(f"Template '{industry}' not found — falling back to 'general'")
        template = load_template("general")
        fallback_used = True

    if template is None:
        raise ValueError(
            f"Neither '{industry}' nor 'general' template found. "
            "Create backend/user_configs/templates/general.json first."
        )

    import copy
    config: Dict[str, Any] = copy.deepcopy(template)

    # Stamp identity fields
    config["username"]     = username
    config["industry"]     = industry if not fallback_used else "general"
    config["r2_bucket"]    = r2_bucket
    if display_name:
        config["display_name"] = display_name

    # Merge any caller-supplied extras
    if extra:
        config.update(extra)

    # Persist to disk
    USER_CONFIGS_DIR.mkdir(parents=True, exist_ok=True)
    config_path = USER_CONFIGS_DIR / f"{username}.json"

    with open(config_path, "w", encoding="utf-8") as f:
        import json
        json.dump(config, f, indent=4, ensure_ascii=False)

    # Invalidate cache so the new file is picked up immediately
    global _config_cache
    _config_cache.pop(username, None)

    logger.info(f"✓ User config created for '{username}' (industry='{config['industry']}') → {config_path}")
    return config


# For testing
if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    
    print("=== Testing Config Loader ===")
    
    # Test loading user config
    print("\n1. Loading adnak config:")
    config = get_user_config("adnak")
    if config:
        print(f"  - Username: {config.get('username')}")
        print(f"  - Industry: {config.get('industry')}")
        print(f"  - Dashboard: {config.get('dashboard_url')}")
        print(f"  - Gemini prompt length: {len(config.get('gemini', {}).get('system_instruction', ''))}")
    
    # Test getting columns
    print("\n2. Getting invoice_all columns for adnak:")
    columns = get_columns_config("adnak", "invoice_all")
    if columns:
        print(f"  - Total columns: {len(columns)}")
        print(f"  - First 3 columns: {[c['label'] for c in columns[:3]]}")
    
    # Test listing users
    print("\n3. Available users:")
    users = list_available_users()
    print(f"  - {users}")
    
    print("\n=== Test Complete ===")
