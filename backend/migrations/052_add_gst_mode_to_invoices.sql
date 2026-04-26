-- ============================================================================
-- MIGRATION 052: Add gst_mode and payment tracking columns to invoices table
-- 
-- The invoices table is missing columns that were supposed to be added
-- by migration 003 (udhar tracking). This migration adds them safely
-- with IF NOT EXISTS to avoid errors if any already exist.
-- ============================================================================

ALTER TABLE public.invoices
  ADD COLUMN IF NOT EXISTS gst_mode TEXT,
  ADD COLUMN IF NOT EXISTS payment_mode TEXT DEFAULT 'Credit',
  ADD COLUMN IF NOT EXISTS received_amount NUMERIC,
  ADD COLUMN IF NOT EXISTS balance_due NUMERIC,
  ADD COLUMN IF NOT EXISTS customer_details TEXT,
  ADD COLUMN IF NOT EXISTS taxable_row_ids TEXT;

SELECT 'Migration 052 completed: gst_mode and payment tracking columns added to invoices table.' AS status;
