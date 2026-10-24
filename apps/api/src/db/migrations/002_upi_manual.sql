-- UPI paid directly to the store's own UPI ID, confirmed by staff against the bank app (no payment gateway).
-- Flow: order 'pending_payment' -> customer reports payment ('verifying') -> staff confirms amount + UTR -> 'placed' / 'paid'.

ALTER TABLE orders DROP CONSTRAINT orders_payment_method_check;
ALTER TABLE orders ADD CONSTRAINT orders_payment_method_check CHECK (payment_method IN ('cod','online','upi'));

ALTER TABLE orders DROP CONSTRAINT orders_payment_status_check;
ALTER TABLE orders ADD CONSTRAINT orders_payment_status_check CHECK (payment_status IN (
  'cod_pending','cod_collected','pending','verifying','paid','failed','refund_pending','refunded','partially_refunded'));

-- claimed_utr: what the customer typed (unverified, NOT unique, so a guessed UTR cannot block a real one).
-- provider_payment_id (already UNIQUE) holds the UTR staff read from the bank app: one bank reference settles one payment.
ALTER TABLE payments
  ADD COLUMN claimed_utr text CHECK (claimed_utr ~ '^[0-9]{12}$'),
  ADD COLUMN claimed_at  timestamptz,
  ADD COLUMN verified_by uuid REFERENCES admin_users(id),
  ADD COLUMN verified_at timestamptz;

-- Manual (non-gateway) refunds record who sent the money back.
ALTER TABLE refunds ADD COLUMN processed_by uuid REFERENCES admin_users(id);

CREATE INDEX orders_payment_verifying ON orders (placed_at) WHERE payment_status = 'verifying';
