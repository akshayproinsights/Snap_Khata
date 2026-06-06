-- ============================================================================
-- MIGRATION 062: Enable RLS on tables missing Row Level Security
-- Fixes Supabase security alert: "Table publicly accessible (rls_disabled_in_public)"
--
-- SAFE TO RUN:
--   • All policy creation is guarded with IF NOT EXISTS checks.
--   • ENABLE ROW LEVEL SECURITY is idempotent (no-op if already enabled).
--   • Backend uses service_role key which bypasses RLS — zero impact.
--
-- Tables fixed:
--   1. sync_metadata       — created without RLS in create_sync_metadata_table.sql
--   2. user_item_catalogue — created without RLS in migration 058
-- ============================================================================


-- ============================================================================
-- 1. sync_metadata
-- ============================================================================

ALTER TABLE sync_metadata ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE tablename = 'sync_metadata'
          AND policyname = 'Users can view their own sync metadata'
    ) THEN
        CREATE POLICY "Users can view their own sync metadata"
        ON sync_metadata FOR SELECT
        USING (username = current_setting('app.current_user', true));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE tablename = 'sync_metadata'
          AND policyname = 'Service role can manage all sync metadata'
    ) THEN
        CREATE POLICY "Service role can manage all sync metadata"
        ON sync_metadata FOR ALL
        USING (true) WITH CHECK (true);
    END IF;
END $$;


-- ============================================================================
-- 2. user_item_catalogue
-- ============================================================================

ALTER TABLE user_item_catalogue ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE tablename = 'user_item_catalogue'
          AND policyname = 'Users can view their own item catalogue'
    ) THEN
        CREATE POLICY "Users can view their own item catalogue"
        ON user_item_catalogue FOR SELECT
        USING (username = current_setting('app.current_user', true));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE tablename = 'user_item_catalogue'
          AND policyname = 'Service role can manage all item catalogue'
    ) THEN
        CREATE POLICY "Service role can manage all item catalogue"
        ON user_item_catalogue FOR ALL
        USING (true) WITH CHECK (true);
    END IF;
END $$;


-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================

SELECT 'Migration 062: RLS enabled on sync_metadata and user_item_catalogue' AS status;
