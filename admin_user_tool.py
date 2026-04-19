#!/usr/bin/env python3
"""Admin tool to view and manage users"""
import sys
import os
import argparse
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'backend'))

from config import get_supabase_config
from supabase import create_client
import bcrypt

def get_client():
    config = get_supabase_config()
    return create_client(config['url'], config['service_role_key'])

def list_users():
    """List all users with their data (no passwords)"""
    client = get_client()
    resp = client.table("users").select("username, r2_bucket, industry, created_at").execute()
    rows = resp.data or []
    
    print("\n" + "=" * 80)
    print(f"{'Username':<20} {'R2 Bucket':<20} {'Industry':<15} {'Created':<20}")
    print("=" * 80)
    for row in rows:
        print(f"{row['username']:<20} {row.get('r2_bucket', 'N/A'):<20} {row.get('industry', 'N/A'):<15} {row.get('created_at', 'N/A')[:19] if row.get('created_at') else 'N/A':<20}")
    print(f"\nTotal users: {len(rows)}")

def view_user(username):
    """View detailed user info (no password)"""
    client = get_client()
    resp = client.table("users").select("*").eq("username", username).limit(1).execute()
    rows = resp.data or []
    
    if not rows:
        print(f"✗ User '{username}' not found")
        return
    
    user = rows[0]
    print(f"\n" + "=" * 60)
    print(f"User: {username}")
    print("=" * 60)
    
    for key, value in user.items():
        if key == "password_hash":
            # Show hash prefix only
            print(f"  {key:<20}: {value[:25]}... [HASH - cannot be decrypted]")
        else:
            print(f"  {key:<20}: {value}")

def reset_password(username, new_password):
    """Reset user password"""
    client = get_client()
    
    # Hash new password
    hashed = bcrypt.hashpw(new_password.encode(), bcrypt.gensalt()).decode()
    
    # Update
    result = client.table("users").update({"password_hash": hashed}).eq("username", username).execute()
    
    if result.data:
        print(f"✓ Password reset for '{username}'")
        print(f"  New password: {new_password}")
    else:
        print(f"✗ Failed to reset password")

def check_user_exists(username):
    """Check if user exists and has password"""
    client = get_client()
    resp = client.table("users").select("username, password_hash, r2_bucket").eq("username", username).limit(1).execute()
    rows = resp.data or []
    
    if not rows:
        print(f"✗ User '{username}' NOT FOUND")
        return False
    
    user = rows[0]
    has_password = bool(user.get('password_hash'))
    print(f"✓ User '{username}' EXISTS")
    print(f"  Has password: {has_password}")
    print(f"  R2 bucket: {user.get('r2_bucket', 'N/A')}")
    return True

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Admin User Management Tool")
    parser.add_argument("--list", action="store_true", help="List all users")
    parser.add_argument("--view", metavar="USERNAME", help="View user details")
    parser.add_argument("--check", metavar="USERNAME", help="Check if user exists")
    parser.add_argument("--reset", metavar="USERNAME", help="Reset password for user")
    parser.add_argument("--password", default="TempPass123!", help="New password (for --reset)")
    
    args = parser.parse_args()
    
    if args.list:
        list_users()
    elif args.view:
        view_user(args.view)
    elif args.check:
        check_user_exists(args.check)
    elif args.reset:
        reset_password(args.reset, args.password)
    else:
        parser.print_help()
