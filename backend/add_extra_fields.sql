-- Supabase SQL Migration: Add extra_fields JSON column to inventory_items
-- This allows dumping generic, industry-specific data without needing many specific columns.

ALTER TABLE public.inventory_items
ADD COLUMN IF NOT EXISTS extra_fields JSONB DEFAULT '{}'::jsonb;

-- Also add to invoice processing pipeline tables
ALTER TABLE public.invoices
ADD COLUMN IF NOT EXISTS extra_fields JSONB DEFAULT '{}'::jsonb;

ALTER TABLE public.verification_dates
ADD COLUMN IF NOT EXISTS extra_fields JSONB DEFAULT '{}'::jsonb;

ALTER TABLE public.verification_amounts
ADD COLUMN IF NOT EXISTS extra_fields JSONB DEFAULT '{}'::jsonb;
