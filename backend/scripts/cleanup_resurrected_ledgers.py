"""
One-time cleanup script for the party resurrection bug.

This script:
1. Finds any customer_ledger that has ALL transactions with payment_mode='Cash' 
   AND was created AFTER a same-named ledger was deleted (i.e., resurrected orphans).
2. Writes tombstones for any ledger that the user has since re-deleted.

Run ONCE from the backend directory:
    python scripts/cleanup_resurrected_ledgers.py

It is SAFE to run multiple times (idempotent).
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from database import get_database_client
from datetime import datetime

def cleanup(username: str):
    db = get_database_client()
    db.set_user_context(username)

    # Fetch all customer ledgers for this user
    ledgers_resp = db.client.table("customer_ledgers") \
        .select("id, customer_name, balance_due, created_at") \
        .eq("username", username) \
        .execute()
    ledgers = ledgers_resp.data or []

    if not ledgers:
        print(f"[{username}] No ledgers found.")
        return

    # Fetch all transactions for these ledgers
    ledger_ids = [l["id"] for l in ledgers]
    tx_resp = db.client.table("ledger_transactions") \
        .select("ledger_id, transaction_type, payment_mode, amount") \
        .eq("username", username) \
        .in_("ledger_id", ledger_ids) \
        .execute()
    txs = tx_resp.data or []

    # Build per-ledger stats
    ledger_stats: dict = {l["id"]: {"all_cash": True, "has_tx": False, "balance": float(l.get("balance_due") or 0)} for l in ledgers}
    for tx in txs:
        lid = tx["ledger_id"]
        if lid not in ledger_stats:
            continue
        ledger_stats[lid]["has_tx"] = True
        pm = str(tx.get("payment_mode") or "Cash").strip().lower()
        if pm == "credit":
            ledger_stats[lid]["all_cash"] = False

    # Orphaned resurrected ledger = zero balance + all-cash transactions
    # (because delete converts Credit→Cash and the sync re-creates with 0 balance)
    resurrected = []
    for l in ledgers:
        lid = l["id"]
        stats = ledger_stats[lid]
        if stats["balance"] <= 0 and stats["all_cash"]:
            resurrected.append(l)

    if not resurrected:
        print(f"[{username}] No resurrected ledgers found. ✅")
        return

    print(f"[{username}] Found {len(resurrected)} potentially resurrected ledger(s):")
    for l in resurrected:
        print(f"  - ID {l['id']}: {l['customer_name']} (balance={l['balance_due']})")

    confirm = input("\nDelete these + write tombstones? [y/N]: ").strip().lower()
    if confirm != "y":
        print("Skipped.")
        return

    now = datetime.utcnow().isoformat()
    for l in resurrected:
        lid = l["id"]
        cname = l["customer_name"]
        # Delete the resurrected ledger
        db.client.table("customer_ledgers").delete().eq("id", lid).execute()
        # Write tombstone
        try:
            db.client.table("deleted_ledger_tombstones").upsert({
                "username": username,
                "customer_name": cname,
                "deleted_at": now,
            }, on_conflict="username,customer_name").execute()
            print(f"  ✅ Deleted & tombstoned: {cname} (ID {lid})")
        except Exception as e:
            print(f"  ⚠️  Deleted but tombstone failed for {cname}: {e}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python cleanup_resurrected_ledgers.py <username>")
        print("Example: python cleanup_resurrected_ledgers.py onkar")
        sys.exit(1)

    target_username = sys.argv[1]
    print(f"🔍 Scanning ledgers for user: {target_username}\n")
    cleanup(target_username)
    print("\nDone.")
