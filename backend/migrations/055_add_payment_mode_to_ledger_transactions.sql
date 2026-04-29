-- Migration 055: Add payment_mode to ledger_transactions
-- Purpose: Persist the payment mode (Cash / Credit / Online) directly on each
--          ledger transaction so the mobile order-detail page can display it
--          correctly without re-deriving it from verified_invoices at read-time.
--
-- Previously payment_mode was never written to ledger_transactions, causing
-- the order-detail page to default every invoice to "Cash" even when the
-- verified invoice was marked "Credit".

ALTER TABLE public.ledger_transactions
  ADD COLUMN IF NOT EXISTS payment_mode TEXT DEFAULT 'Cash';

-- Back-fill existing INVOICE rows from verified_invoices so historical data
-- is also corrected. Rows that cannot be matched remain 'Cash' (safe default).
UPDATE public.ledger_transactions lt
SET    payment_mode = vi.payment_mode
FROM   public.verified_invoices vi
WHERE  lt.receipt_number = vi.receipt_number
  AND  lt.username       = vi.username
  AND  lt.transaction_type = 'INVOICE'
  AND  vi.payment_mode IS NOT NULL
  AND  vi.payment_mode <> '';

SELECT 'Migration 055: payment_mode added and back-filled on ledger_transactions' AS status;
