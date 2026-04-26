-- ============================================================================
-- MIGRATION 049: Fix ALL Remaining Missing Columns (Comprehensive)
-- Resolves ALL 500 errors found in the backend logs post-merge
-- ============================================================================

-- ============================================================================
-- 1. invoices table — code sends receipt_link, quantity, rate, extra_fields
--    but DB only has r2_file_path (NOT NULL). Add missing columns + make
--    r2_file_path nullable since new code never populates it.
-- ============================================================================
ALTER TABLE public.invoices ADD COLUMN IF NOT EXISTS receipt_link TEXT;
ALTER TABLE public.invoices ADD COLUMN IF NOT EXISTS quantity NUMERIC;
ALTER TABLE public.invoices ADD COLUMN IF NOT EXISTS rate NUMERIC;
ALTER TABLE public.invoices ADD COLUMN IF NOT EXISTS extra_fields JSONB DEFAULT '{}'::jsonb;
ALTER TABLE public.invoices ADD COLUMN IF NOT EXISTS upload_date TIMESTAMP WITH TIME ZONE DEFAULT NOW();
ALTER TABLE public.invoices ADD COLUMN IF NOT EXISTS fallback_attempted BOOLEAN DEFAULT FALSE;
ALTER TABLE public.invoices ADD COLUMN IF NOT EXISTS fallback_reason TEXT;
ALTER TABLE public.invoices ADD COLUMN IF NOT EXISTS processing_errors TEXT;

-- Make r2_file_path nullable (old column, new code uses receipt_link instead)
ALTER TABLE public.invoices ALTER COLUMN r2_file_path DROP NOT NULL;

-- ============================================================================
-- 2. verification_dates — code sends receipt_link + customer_name + extra_fields
--    but DB has r2_file_path NOT NULL. Fix constraints and add columns.
-- ============================================================================
ALTER TABLE public.verification_dates ADD COLUMN IF NOT EXISTS receipt_link TEXT;
ALTER TABLE public.verification_dates ADD COLUMN IF NOT EXISTS customer_name TEXT;
ALTER TABLE public.verification_dates ADD COLUMN IF NOT EXISTS extra_fields JSONB DEFAULT '{}'::jsonb;

-- Make r2_file_path nullable
ALTER TABLE public.verification_dates ALTER COLUMN r2_file_path DROP NOT NULL;

-- ============================================================================
-- 3. verification_amounts — same pattern as verification_dates
-- ============================================================================
ALTER TABLE public.verification_amounts ADD COLUMN IF NOT EXISTS receipt_link TEXT;
ALTER TABLE public.verification_amounts ADD COLUMN IF NOT EXISTS customer_name TEXT;
ALTER TABLE public.verification_amounts ADD COLUMN IF NOT EXISTS extra_fields JSONB DEFAULT '{}'::jsonb;
ALTER TABLE public.verification_amounts ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE public.verification_amounts ADD COLUMN IF NOT EXISTS row_id TEXT;

-- Make r2_file_path nullable
ALTER TABLE public.verification_amounts ALTER COLUMN r2_file_path DROP NOT NULL;

-- ============================================================================
-- 4. inventory_items — missing excluded_from_stock + quantity columns
-- ============================================================================
ALTER TABLE public.inventory_items ADD COLUMN IF NOT EXISTS excluded_from_stock BOOLEAN DEFAULT FALSE;
ALTER TABLE public.inventory_items ADD COLUMN IF NOT EXISTS quantity NUMERIC DEFAULT 1;
ALTER TABLE public.inventory_items ADD COLUMN IF NOT EXISTS invoice_date TEXT;
ALTER TABLE public.inventory_items ADD COLUMN IF NOT EXISTS extra_fields JSONB DEFAULT '{}'::jsonb;

-- ============================================================================
-- 5. verified_invoices — additional missing columns
-- ============================================================================
ALTER TABLE public.verified_invoices ADD COLUMN IF NOT EXISTS received_amount NUMERIC DEFAULT 0;
ALTER TABLE public.verified_invoices ADD COLUMN IF NOT EXISTS upload_date TIMESTAMP WITH TIME ZONE DEFAULT NOW();
ALTER TABLE public.verified_invoices ADD COLUMN IF NOT EXISTS type TEXT;
ALTER TABLE public.verified_invoices ADD COLUMN IF NOT EXISTS customer_name TEXT;
ALTER TABLE public.verified_invoices ADD COLUMN IF NOT EXISTS customer_details JSONB;
ALTER TABLE public.verified_invoices ADD COLUMN IF NOT EXISTS extra_fields JSONB DEFAULT '{}'::jsonb;
ALTER TABLE public.verified_invoices ADD COLUMN IF NOT EXISTS quantity NUMERIC;
ALTER TABLE public.verified_invoices ADD COLUMN IF NOT EXISTS rate NUMERIC;
ALTER TABLE public.verified_invoices ADD COLUMN IF NOT EXISTS balance_due NUMERIC DEFAULT 0;
ALTER TABLE public.verified_invoices ADD COLUMN IF NOT EXISTS payment_mode TEXT;
ALTER TABLE public.verified_invoices ADD COLUMN IF NOT EXISTS mobile_number TEXT;
ALTER TABLE public.verified_invoices ADD COLUMN IF NOT EXISTS receipt_link TEXT;

-- Make r2_file_path nullable on verified_invoices too
ALTER TABLE public.verified_invoices ALTER COLUMN r2_file_path DROP NOT NULL;

-- ============================================================================
-- 6. stock_levels — missing columns
-- ============================================================================
ALTER TABLE public.stock_levels ADD COLUMN IF NOT EXISTS unit_value NUMERIC DEFAULT 0;
ALTER TABLE public.stock_levels ADD COLUMN IF NOT EXISTS internal_item_name TEXT;
ALTER TABLE public.stock_levels ADD COLUMN IF NOT EXISTS current_stock NUMERIC DEFAULT 0;
ALTER TABLE public.stock_levels ADD COLUMN IF NOT EXISTS vendor_description TEXT;
ALTER TABLE public.stock_levels ADD COLUMN IF NOT EXISTS customer_items TEXT;
ALTER TABLE public.stock_levels ADD COLUMN IF NOT EXISTS total_in NUMERIC DEFAULT 0;
ALTER TABLE public.stock_levels ADD COLUMN IF NOT EXISTS total_out NUMERIC DEFAULT 0;
ALTER TABLE public.stock_levels ADD COLUMN IF NOT EXISTS vendor_rate NUMERIC;
ALTER TABLE public.stock_levels ADD COLUMN IF NOT EXISTS customer_rate NUMERIC;
ALTER TABLE public.stock_levels ADD COLUMN IF NOT EXISTS total_value NUMERIC DEFAULT 0;
ALTER TABLE public.stock_levels ADD COLUMN IF NOT EXISTS manual_adjustment NUMERIC DEFAULT 0;
ALTER TABLE public.stock_levels ADD COLUMN IF NOT EXISTS last_vendor_invoice_date TEXT;
ALTER TABLE public.stock_levels ADD COLUMN IF NOT EXISTS last_customer_invoice_date TEXT;

-- ============================================================================
-- 7. recalculation_tasks — missing timestamp columns
-- ============================================================================
ALTER TABLE public.recalculation_tasks ADD COLUMN IF NOT EXISTS started_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE public.recalculation_tasks ADD COLUMN IF NOT EXISTS completed_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE public.recalculation_tasks ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE;

-- ============================================================================
-- 8. draft_purchase_orders — missing column
-- ============================================================================
ALTER TABLE public.draft_purchase_orders ADD COLUMN IF NOT EXISTS added_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- ============================================================================
-- Force PostgREST schema cache reload
-- ============================================================================
NOTIFY pgrst, 'reload schema';
