-- ============================================================================
-- MIGRATION 051: Fix Missing mobile_number, car_number, total_bill_amount
-- Resolves:
--   1. verification_dates: 'mobile_number' column missing → 500 on every save
--   2. verified_invoices: 'car_number' column missing → Sync & Finish fails
--   3. verified_invoices: 'total_bill_amount' column missing → duplicate check error
--   4. verification_amounts: 'mobile_number' column missing (same pattern)
-- ============================================================================

-- 1. verification_dates — add mobile_number (sent by Flutter New Order screen)
ALTER TABLE public.verification_dates ADD COLUMN IF NOT EXISTS mobile_number TEXT;
ALTER TABLE public.verification_dates ADD COLUMN IF NOT EXISTS vehicle_number TEXT;
ALTER TABLE public.verification_dates ADD COLUMN IF NOT EXISTS gst_mode TEXT;
ALTER TABLE public.verification_dates ADD COLUMN IF NOT EXISTS payment_mode TEXT;

-- 2. verification_amounts — add mobile_number (same payload sent for line items)
ALTER TABLE public.verification_amounts ADD COLUMN IF NOT EXISTS mobile_number TEXT;
ALTER TABLE public.verification_amounts ADD COLUMN IF NOT EXISTS vehicle_number TEXT;
ALTER TABLE public.verification_amounts ADD COLUMN IF NOT EXISTS gst_mode TEXT;

-- 3. verified_invoices — add car_number (verification.py renames vehicle_number -> car_number)
ALTER TABLE public.verified_invoices ADD COLUMN IF NOT EXISTS car_number TEXT;
-- Add total_bill_amount (used by duplicate-check query in processor.py)
ALTER TABLE public.verified_invoices ADD COLUMN IF NOT EXISTS total_bill_amount NUMERIC;
-- Add vehicle_number alias too (belt-and-suspenders)
ALTER TABLE public.verified_invoices ADD COLUMN IF NOT EXISTS vehicle_number TEXT;
ALTER TABLE public.verified_invoices ADD COLUMN IF NOT EXISTS gst_mode TEXT;
ALTER TABLE public.verified_invoices ADD COLUMN IF NOT EXISTS odometer TEXT;

-- ============================================================================
-- Force PostgREST schema cache reload
-- ============================================================================
NOTIFY pgrst, 'reload schema';
