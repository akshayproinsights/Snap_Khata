-- ============================================================================
-- MIGRATION 003: UDHAR (CREDIT) TRACKING
-- Adds columns and tables for tracking customer pending balances.
-- ============================================================================

-- 1. Add payment and tax tracking columns to existing invoice/verification tables
ALTER TABLE invoices 
ADD COLUMN IF NOT EXISTS payment_mode TEXT DEFAULT 'Cash',
ADD COLUMN IF NOT EXISTS received_amount NUMERIC,
ADD COLUMN IF NOT EXISTS balance_due NUMERIC,
ADD COLUMN IF NOT EXISTS customer_details TEXT,
ADD COLUMN IF NOT EXISTS gst_mode TEXT DEFAULT 'none',
ADD COLUMN IF NOT EXISTS taxable_row_ids TEXT;

ALTER TABLE verified_invoices 
ADD COLUMN IF NOT EXISTS payment_mode TEXT DEFAULT 'Cash',
ADD COLUMN IF NOT EXISTS received_amount NUMERIC,
ADD COLUMN IF NOT EXISTS balance_due NUMERIC,
ADD COLUMN IF NOT EXISTS customer_details TEXT,
ADD COLUMN IF NOT EXISTS gst_mode TEXT DEFAULT 'none',
ADD COLUMN IF NOT EXISTS taxable_row_ids TEXT;

-- ALTER TABLE verified_headers 
-- ADD COLUMN IF NOT EXISTS payment_mode TEXT DEFAULT 'Cash',
-- ADD COLUMN IF NOT EXISTS received_amount NUMERIC,
-- ADD COLUMN IF NOT EXISTS balance_due NUMERIC,
-- ADD COLUMN IF NOT EXISTS customer_details TEXT;

ALTER TABLE verification_dates 
ADD COLUMN IF NOT EXISTS payment_mode TEXT DEFAULT 'Cash',
ADD COLUMN IF NOT EXISTS received_amount NUMERIC,
ADD COLUMN IF NOT EXISTS balance_due NUMERIC,
ADD COLUMN IF NOT EXISTS customer_details TEXT,
ADD COLUMN IF NOT EXISTS gst_mode TEXT DEFAULT 'none',
ADD COLUMN IF NOT EXISTS taxable_row_ids TEXT;

-- 2. Create Customer Ledgers table
CREATE TABLE IF NOT EXISTS customer_ledgers (
    id SERIAL PRIMARY KEY,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    username TEXT NOT NULL,
    customer_name TEXT NOT NULL,
    customer_phone TEXT,
    balance_due NUMERIC DEFAULT 0,
    last_payment_date TIMESTAMP WITH TIME ZONE,
    UNIQUE(username, customer_name)
);

CREATE INDEX IF NOT EXISTS idx_customer_ledgers_username ON customer_ledgers(username);
CREATE INDEX IF NOT EXISTS idx_customer_ledgers_customer_name ON customer_ledgers(username, customer_name);

-- 3. Create Ledger Transactions table
-- Records every change to the ledger (Invoice generated vs Payment received)
CREATE TABLE IF NOT EXISTS ledger_transactions (
    id SERIAL PRIMARY KEY,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    username TEXT NOT NULL,
    ledger_id INTEGER REFERENCES customer_ledgers(id) ON DELETE CASCADE,
    transaction_type TEXT NOT NULL, -- 'INVOICE' (increases debt), 'PAYMENT' (decreases debt)
    amount NUMERIC NOT NULL,
    receipt_number TEXT,
    notes TEXT
);

CREATE INDEX IF NOT EXISTS idx_ledger_transactions_ledger_id ON ledger_transactions(ledger_id);
CREATE INDEX IF NOT EXISTS idx_ledger_transactions_username ON ledger_transactions(username);


-- 4. Enable RLS and setup policies
ALTER TABLE customer_ledgers ENABLE ROW LEVEL SECURITY;
ALTER TABLE ledger_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own customer ledgers"
ON customer_ledgers FOR SELECT
USING (username = current_setting('app.current_user', true));

CREATE POLICY "Service role can manage all customer ledgers"
ON customer_ledgers FOR ALL
USING (true) WITH CHECK (true);

CREATE POLICY "Users can view their own ledger transactions"
ON ledger_transactions FOR SELECT
USING (username = current_setting('app.current_user', true));

CREATE POLICY "Service role can manage all ledger transactions"
ON ledger_transactions FOR ALL
USING (true) WITH CHECK (true);

SELECT 'Udhar (Credit) Tracking migration completed successfully!' as status;
