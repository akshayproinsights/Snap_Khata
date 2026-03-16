-- ============================================================================
-- MIGRATION 037: INVENTORY INVOICES
-- Creates a parent table for inventory items to track overall invoice data
-- such as payment details and udhar tracking basis.
-- ============================================================================

CREATE TABLE IF NOT EXISTS inventory_invoices (
    id SERIAL PRIMARY KEY,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    username TEXT NOT NULL,
    invoice_number TEXT,
    vendor_name TEXT,
    invoice_date TEXT,
    receipt_link TEXT,
    total_amount NUMERIC DEFAULT 0,
    payment_mode TEXT DEFAULT 'Cash',
    amount_paid NUMERIC DEFAULT 0,
    balance_owed NUMERIC DEFAULT 0,
    vendor_notes TEXT
);

CREATE INDEX IF NOT EXISTS idx_inventory_invoices_username ON inventory_invoices(username);
CREATE INDEX IF NOT EXISTS idx_inventory_invoices_invoice_number ON inventory_invoices(invoice_number);
CREATE INDEX IF NOT EXISTS idx_inventory_invoices_vendor_name ON inventory_invoices(vendor_name);
CREATE INDEX IF NOT EXISTS idx_inventory_invoices_invoice_date ON inventory_invoices(invoice_date);

-- Enable RLS
ALTER TABLE inventory_invoices ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own inventory invoices"
ON inventory_invoices FOR SELECT
USING (username = current_setting('app.current_user', true));

CREATE POLICY "Users can insert their own inventory invoices"
ON inventory_invoices FOR INSERT
WITH CHECK (username = current_setting('app.current_user', true));

CREATE POLICY "Users can update their own inventory invoices"
ON inventory_invoices FOR UPDATE
USING (username = current_setting('app.current_user', true))
WITH CHECK (username = current_setting('app.current_user', true));

CREATE POLICY "Users can delete their own inventory invoices"
ON inventory_invoices FOR DELETE
USING (username = current_setting('app.current_user', true));

CREATE POLICY "Service role can manage all inventory invoices"
ON inventory_invoices FOR ALL
USING (true) WITH CHECK (true);


-- Add linking column to inventory_items
ALTER TABLE inventory_items 
ADD COLUMN IF NOT EXISTS inventory_invoice_id INTEGER REFERENCES inventory_invoices(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_inventory_items_invoice_id ON inventory_items(inventory_invoice_id);

SELECT 'Inventory Invoices migration completed successfully!' as status;
