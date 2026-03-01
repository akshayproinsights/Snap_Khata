-- ============================================================================
-- Migration 035: Fix inventory_mapped and vendor_mapping_entries schemas
-- Date: 2026-02-26
-- Purpose: Add missing columns needed by the new customer-item mapping flow
--          and the vendor mapping entries feature.
-- ============================================================================

-- ============================================================================
-- PART 1: inventory_mapped table
-- The new customer-item mapping flow expects these columns for tracking how
-- customer invoice descriptions map to vendor inventory items.
-- ============================================================================

-- Add customer_item column (the invoice description as written by customer)
ALTER TABLE inventory_mapped
    ADD COLUMN IF NOT EXISTS customer_item TEXT;

-- Add normalized_description column (cleaned/normalized version)
ALTER TABLE inventory_mapped
    ADD COLUMN IF NOT EXISTS normalized_description TEXT;

-- Add vendor_item_id column (FK to inventory_items or NULL for custom)
ALTER TABLE inventory_mapped
    ADD COLUMN IF NOT EXISTS vendor_item_id INTEGER;

-- Add vendor_description column (standardized vendor item name)
ALTER TABLE inventory_mapped
    ADD COLUMN IF NOT EXISTS vendor_description TEXT;

-- Add vendor_part_number column
ALTER TABLE inventory_mapped
    ADD COLUMN IF NOT EXISTS vendor_part_number TEXT;

-- Add priority column
ALTER TABLE inventory_mapped
    ADD COLUMN IF NOT EXISTS priority INTEGER DEFAULT 0;

-- Add status column (Added, Skipped, Done)
ALTER TABLE inventory_mapped
    ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'Added';

-- Add updated_at column
ALTER TABLE inventory_mapped
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now());

-- Add mapped_on column
ALTER TABLE inventory_mapped
    ADD COLUMN IF NOT EXISTS mapped_on TIMESTAMP WITH TIME ZONE;

-- Add synced_at column (NULL means not yet synced)
ALTER TABLE inventory_mapped
    ADD COLUMN IF NOT EXISTS synced_at TIMESTAMP WITH TIME ZONE;

-- Create unique constraint on customer_item + username (for upsert conflict resolution)
-- First drop existing unique constraint if it conflicts
ALTER TABLE inventory_mapped
    DROP CONSTRAINT IF EXISTS inventory_mapped_username_receipt_number_row_id_key;

-- Add new index for the customer_item + username pair (used for upserts)
CREATE INDEX IF NOT EXISTS idx_inventory_mapped_customer_item
    ON inventory_mapped(username, customer_item);

-- Unique constraint for customer_item + username pair (enables upsert on_conflict)
ALTER TABLE inventory_mapped
    ADD CONSTRAINT IF NOT EXISTS inventory_mapped_customer_item_username_key
    UNIQUE (customer_item, username);


-- ============================================================================
-- PART 2: vendor_mapping_entries table
-- The vendor mapping entries route expects these columns.
-- ============================================================================

-- Add row_number column (ordering row in the mapping sheet)
ALTER TABLE vendor_mapping_entries
    ADD COLUMN IF NOT EXISTS row_number INTEGER DEFAULT 0;

-- Add vendor_description column (already may exist from migration 017, safe to skip
