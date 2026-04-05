-- SnapKhata v2.1 — Inventory Items Schema Extension
-- Phase 2 migration: adds dedicated columns for all v2.1 OCR computed fields.
-- Currently these fields are stored in extra_fields JSONB (prefixed v2_).
-- Running this migration promotes them to proper indexed columns.
--
-- SAFE TO RUN: All statements use IF NOT EXISTS / have defaults.
-- Run once after verifying Phase 1 data in extra_fields looks correct.

ALTER TABLE inventory_items ADD COLUMN IF NOT EXISTS gross_amount       NUMERIC(12,2) DEFAULT 0;
ALTER TABLE inventory_items ADD COLUMN IF NOT EXISTS disc_type          TEXT          DEFAULT 'NONE';
ALTER TABLE inventory_items ADD COLUMN IF NOT EXISTS disc_amount        NUMERIC(12,2) DEFAULT 0;
ALTER TABLE inventory_items ADD COLUMN IF NOT EXISTS igst_percent       NUMERIC(5,2)  DEFAULT 0;
ALTER TABLE inventory_items ADD COLUMN IF NOT EXISTS igst_amount        NUMERIC(12,2) DEFAULT 0;
ALTER TABLE inventory_items ADD COLUMN IF NOT EXISTS cgst_amount        NUMERIC(12,2) DEFAULT 0;
ALTER TABLE inventory_items ADD COLUMN IF NOT EXISTS sgst_amount        NUMERIC(12,2) DEFAULT 0;
ALTER TABLE inventory_items ADD COLUMN IF NOT EXISTS net_amount         NUMERIC(12,2) DEFAULT 0;
ALTER TABLE inventory_items ADD COLUMN IF NOT EXISTS printed_total      NUMERIC(12,2) DEFAULT 0;
ALTER TABLE inventory_items ADD COLUMN IF NOT EXISTS mismatch_amount    NUMERIC(12,2) DEFAULT 0;
ALTER TABLE inventory_items ADD COLUMN IF NOT EXISTS needs_review       BOOLEAN       DEFAULT FALSE;
ALTER TABLE inventory_items ADD COLUMN IF NOT EXISTS tax_type           TEXT          DEFAULT 'NONE';
ALTER TABLE inventory_items ADD COLUMN IF NOT EXISTS vendor_gstin       TEXT;
ALTER TABLE inventory_items ADD COLUMN IF NOT EXISTS place_of_supply    TEXT;
ALTER TABLE inventory_items ADD COLUMN IF NOT EXISTS header_adjustments JSONB         DEFAULT '[]';

-- Useful indexes for Phase 2 filtering
CREATE INDEX IF NOT EXISTS idx_inventory_needs_review ON inventory_items (needs_review) WHERE needs_review = TRUE;
CREATE INDEX IF NOT EXISTS idx_inventory_tax_type     ON inventory_items (tax_type);
CREATE INDEX IF NOT EXISTS idx_inventory_vendor_gstin ON inventory_items (vendor_gstin);

-- Backfill from extra_fields for rows already written by Phase 1
-- Run ONLY if you want to promote Phase 1 data to proper columns.
-- Comment out if you prefer to start fresh.
UPDATE inventory_items
SET
    gross_amount    = (extra_fields->>'v2_gross_amount')::NUMERIC,
    disc_type       = extra_fields->>'v2_disc_type',
    disc_amount     = (extra_fields->>'v2_disc_amount')::NUMERIC,
    igst_percent    = (extra_fields->>'v2_igst_percent')::NUMERIC,
    igst_amount     = (extra_fields->>'v2_igst_amount')::NUMERIC,
    cgst_amount     = (extra_fields->>'v2_cgst_amount')::NUMERIC,
    sgst_amount     = (extra_fields->>'v2_sgst_amount')::NUMERIC,
    net_amount      = (extra_fields->>'v2_net_amount')::NUMERIC,
    printed_total   = (extra_fields->>'v2_printed_total')::NUMERIC,
    mismatch_amount = (extra_fields->>'v2_mismatch_amount')::NUMERIC,
    needs_review    = (extra_fields->>'v2_needs_review')::BOOLEAN,
    tax_type        = extra_fields->>'v2_tax_type',
    vendor_gstin    = extra_fields->>'v2_vendor_gstin',
    place_of_supply = extra_fields->>'v2_place_of_supply'
WHERE extra_fields ? 'v2_gross_amount';
