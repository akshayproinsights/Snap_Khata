-- Migration: add_customer_invoice_paid_status
-- Purpose: Add tracking for whether a customer invoice (Udhar) transaction is paid and link it to its payment transaction.

-- Add is_paid column to track if an invoice (transaction_type = 'INVOICE') has been fully paid.
-- Default to false.
ALTER TABLE public.ledger_transactions
ADD COLUMN IF NOT EXISTS is_paid boolean DEFAULT false;

-- Add linked_transaction_id to link an INVOICE to a PAYMENT (and viceversa if needed).
-- This relies on the transaction ID within the same table.
ALTER TABLE public.ledger_transactions
ADD COLUMN IF NOT EXISTS linked_transaction_id BIGINT;

-- Add foreign key constraint to ensure linked_transaction_id references a valid transaction.
-- Using ON DELETE SET NULL so if a payment is deleted, the invoice link is simply cleared.
ALTER TABLE public.ledger_transactions
ADD CONSTRAINT fk_ledger_transactions_linked_txn
FOREIGN KEY (linked_transaction_id)
REFERENCES public.ledger_transactions(id)
ON DELETE SET NULL;

-- Optional: Add an index on the linked_transaction_id for faster lookups
CREATE INDEX IF NOT EXISTS idx_ledger_tx_linked_txn ON public.ledger_transactions(linked_transaction_id);
