-- Migration 056: Create deleted_ledger_tombstones table
-- This table is a permanent record of every customer ledger a user has
-- manually deleted. The sync function (sync_customer_ledgers_from_invoices)
-- checks this table before auto-creating new ledgers to prevent resurrection.

CREATE TABLE IF NOT EXISTS deleted_ledger_tombstones (
    id          bigserial PRIMARY KEY,
    username    text NOT NULL,
    customer_name text NOT NULL,
    deleted_at  timestamptz NOT NULL DEFAULT now(),
    
    -- Prevent duplicate tombstones for the same user+customer
    CONSTRAINT uq_deleted_ledger_tombstone UNIQUE (username, customer_name)
);

-- Index for fast lookups during sync (queries by username)
CREATE INDEX IF NOT EXISTS idx_deleted_ledger_tombstones_username
    ON deleted_ledger_tombstones (username);

-- Enable Row Level Security (consistent with rest of schema)
ALTER TABLE deleted_ledger_tombstones ENABLE ROW LEVEL SECURITY;

-- RLS policy: users can only see/modify their own tombstones
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE tablename = 'deleted_ledger_tombstones'
          AND policyname = 'users_own_tombstones'
    ) THEN
        CREATE POLICY users_own_tombstones
            ON deleted_ledger_tombstones
            FOR ALL
            USING (username = current_setting('app.username', true));
    END IF;
END $$;

COMMENT ON TABLE deleted_ledger_tombstones IS
    'Permanent record of user-deleted customer ledgers. Prevents the sync '
    'function from auto-resurrecting deleted parties.';
