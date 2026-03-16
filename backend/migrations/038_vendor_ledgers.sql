-- ============================================================================
-- MIGRATION 038: VENDOR LEDGERS (PAYABLES)
-- Adds columns and tables for tracking vendor payable balances.
-- ============================================================================

-- 1. Create Vendor Ledgers table
CREATE TABLE IF NOT EXISTS vendor_ledgers (
    id SERIAL PRIMARY KEY,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    username TEXT NOT NULL,
    vendor_name TEXT NOT NULL,
    balance_due NUMERIC DEFAULT 0,
    last_payment_date TIMESTAMP WITH TIME ZONE,
    UNIQUE(username, vendor_name)
);

CREATE INDEX IF NOT EXISTS idx_vendor_ledgers_username ON vendor_ledgers(username);
CREATE INDEX IF NOT EXISTS idx_vendor_ledgers_vendor_name ON vendor_ledgers(username, vendor_name);

-- 2. Create Vendor Ledger Transactions table
-- Records every change to the vendor ledger (Invoice verified vs Payment made)
CREATE TABLE IF NOT EXISTS vendor_ledger_transactions (
    id SERIAL PRIMARY KEY,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    username TEXT NOT NULL,
    ledger_id INTEGER REFERENCES vendor_ledgers(id) ON DELETE CASCADE,
    transaction_type TEXT NOT NULL, -- 'INVOICE' (increases debt), 'PAYMENT' (decreases debt)
    amount NUMERIC NOT NULL,
    invoice_number TEXT,
    notes TEXT
);

CREATE INDEX IF NOT EXISTS idx_vendor_ledger_transactions_ledger_id ON vendor_ledger_transactions(ledger_id);
CREATE INDEX IF NOT EXISTS idx_vendor_ledger_transactions_username ON vendor_ledger_transactions(username);


-- 3. Enable RLS and setup policies
ALTER TABLE vendor_ledgers ENABLE ROW LEVEL SECURITY;
ALTER TABLE vendor_ledger_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own vendor ledgers"
ON vendor_ledgers FOR SELECT
USING (username = current_setting('app.current_user', true));

CREATE POLICY "Service role can manage all vendor ledgers"
ON vendor_ledgers FOR ALL
USING (true) WITH CHECK (true);

CREATE POLICY "Users can view their own vendor ledger transactions"
ON vendor_ledger_transactions FOR SELECT
USING (username = current_setting('app.current_user', true));

CREATE POLICY "Service role can manage all vendor ledger transactions"
ON vendor_ledger_transactions FOR ALL
USING (true) WITH CHECK (true);

SELECT 'Vendor Ledgers migration completed successfully!' as status;
