-- ============================================================================
-- MIGRATION 053: Add unique constraint on (username, row_id) to verified_invoices
--
-- The batch upsert uses ON CONFLICT (username, row_id) to update existing
-- verified invoice records instead of throwing duplicate key errors.
-- Without this constraint, the upsert fails with error code 42P10:
--   "there is no unique or exclusion constraint matching the ON CONFLICT specification"
-- ============================================================================

ALTER TABLE public.verified_invoices
  ADD CONSTRAINT verified_invoices_username_row_id_key
  UNIQUE (username, row_id);

SELECT 'Migration 053 completed: unique(username, row_id) constraint added to verified_invoices.' AS status;
