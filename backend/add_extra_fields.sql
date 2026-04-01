-- Supabase SQL Migration: Add extra_fields JSON column to invoice pipeline tables
-- This allows storing industry-specific data (vehicle numbers, GST fields, etc.)
-- without requiring schema changes for each new industry type.

ALTER TABLE public.inventory_items
ADD COLUMN IF NOT EXISTS extra_fields JSONB DEFAULT '{}'::jsonb;

-- Invoice processing pipeline tables
ALTER TABLE public.invoices
ADD COLUMN IF NOT EXISTS extra_fields JSONB DEFAULT '{}'::jsonb;

ALTER TABLE public.verification_dates
ADD COLUMN IF NOT EXISTS extra_fields JSONB DEFAULT '{}'::jsonb;

ALTER TABLE public.verification_amounts
ADD COLUMN IF NOT EXISTS extra_fields JSONB DEFAULT '{}'::jsonb;

-- verified_invoices: store extra_fields so sync-finish preserves
-- industry-specific data (e.g., vehicle numbers captured during AI extraction).
-- After running this, remove 'extra_fields' from columns_to_exclude in
-- backend/services/verification.py (around line 876) to activate the feature.
ALTER TABLE public.verified_invoices
ADD COLUMN IF NOT EXISTS extra_fields JSONB DEFAULT '{}'::jsonb;
