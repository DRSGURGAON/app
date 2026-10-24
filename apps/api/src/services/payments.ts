import type { Tx } from '../db/pool.js';
import { withTx } from '../db/pool.js';
import { AppError, conflict, forbidden, notFound } from '../lib/errors.js';
import { audit } from '../lib/audit.js';
import { fromPaise, toPaise } from '../lib/money.js';
import type { NormalizedWebhook } from '../providers/payments.js';
import { postLedger } from './coins.js';
import { notifyUser } from './notifications.js';
import type { AppCtx } from './orders.js';

export interface PaymentSession {
  provider: string; mode: 'sandbox' | 'live'; key_id: string; provider_order_id: string; amount_paise: number; currency: 'INR';
  order_id: string; order_no: string; prefill: { name: string | null; contact: string };
}

/** Create (or reuse) the provider order for an unpaid online order. Safe to call repeatedly. */
export async function createPaymentSession(ctx: AppCtx, orderId: string, userId: string): Promise<PaymentSession> {
  const o = await ctx.db.query('SELECT * FROM orders WHERE id=$1 AND user_id=$2', [orderId, userId]);
  if (!o.rowCount) throw notFound('Order not found');
  const order = o.rows[0];
  if (order.payment_method !== 'online') throw conflict('NOT_ONLINE', 'This order is Cash on Delivery');
  if (order.status !== 'pending_payment') throw conflict('NOT_PAYABLE', order.payment_status === 'paid' ? 'This order is already paid' : 'This order can no longer be paid');
  if (new Date(order.payment_expires_at) <= new Date()) throw conflict('PAYMENT_EXPIRED', 'The payment window for this order has ended. Please place the order again.');

  const amountPaise = toPaise(order.total);
  const prefill = { name: order.customer_name as string | null, contact: order.customer_phone as string };
  const reuse = await ctx.db.query(`SELECT provider_order_id FROM payments WHERE order_id=$1 AND provider=$2 AND status IN ('created','pending') AND provider_order_id IS NOT NULL ORDER BY created_at DESC LIMIT 1`, [orderId, ctx.payments.name]);
  let providerOrderId: string;
  if (reuse.rowCount) providerOrderId = reuse.rows[0].provider_order_id;
  else {
    try {
      providerOrderId = (await ctx.payments.createOrder({ amountPaise, receipt: order.order_no })).providerOrderId;
    } catch (e) {
      throw new AppError(502, 'PAYMENT_PROVIDER_ERROR', 'Online payment is temporarily unavailable. Please try again or choose Cash on Delivery.', { cause: (e as Error).message });
    }
    await ctx.db.query(`INSERT INTO payments (order_id, provider, provider_order_id, amount, status, mode) VALUES ($1,$2,$3,$4,'created',$5)`,
      [orderId, ctx.payments.name, providerOrderId, order.total, ctx.payments.mode]);
  }
  return { provider: ctx.payments.name, mode: ctx.payments.mode, key_id: ctx.payments.publicKeyId, provider_order_id: providerOrderId, amount_paise: amountPaise, currency: 'INR', order_id: orderId, order_no: order.order_no, prefill };
}

export type CaptureOutcome = 'paid' | 'duplicate' | 'late_refund' | 'amount_mismatch' | 'unknown_order' | 'conflict';

/**
 * Lock order for money rows is always orders → payments → refunds (cancellation and adminRefund lock the order first).
 * Paths that start from a payment look up its order (payments.order_id never changes) and lock that first, so no two
 * of these transactions can wait on each other in a cycle. Returns false when no payment matches.
 */
async function lockOrderOfPayment(tx: Tx, column: 'provider_order_id' | 'provider_payment_id', value: string): Promise<boolean> {
  const ref = await tx.query(`SELECT order_id FROM payments WHERE ${column}=$1`, [value]);
  if (!ref.rowCount) return false;
  await tx.query('SELECT id FROM orders WHERE id=$1 FOR UPDATE', [ref.rows[0].order_id]);
  return true;
}

/** Idempotent: record a captured payment and move the order forward. Never trusts the client. */
export async function applyPaymentCaptured(tx: Tx, e: { providerOrderId: string; providerPaymentId: string; amountPaise: number; method?: string }): Promise<CaptureOutcome> {
  if (!(await lockOrderOfPayment(tx, 'provider_order_id', e.providerOrderId))) return 'unknown_order';
  const p = await tx.query('SELECT * FROM payments WHERE provider_order_id=$1 FOR UPDATE', [e.providerOrderId]);
  if (!p.rowCount) return 'unknown_order';
  const pay = p.rows[0];
  if (pay.status === 'paid' || pay.status === 'refunded' || pay.status === 'partially_refunded') {
    if (pay.provider_payment_id && pay.provider_payment_id !== e.providerPaymentId) {
      await audit(tx, { actorType: 'system', action: 'payment.duplicate_capture', entity: 'payment', entityId: pay.id, after: { extra_payment_id: e.providerPaymentId } });
      return 'conflict';
    }
    return 'duplicate';
  }
  if (e.amountPaise !== toPaise(pay.amount)) {
    await tx.query(`UPDATE payments SET status='failed', failure_reason=$2 WHERE id=$1`, [pay.id, `Amount mismatch: expected ${pay.amount}, provider reported ${fromPaise(e.amountPaise)}`]);
    await audit(tx, { actorType: 'system', action: 'payment.amount_mismatch', entity: 'payment', entityId: pay.id, after: { expected: pay.amount, got: fromPaise(e.amountPaise), providerPaymentId: e.providerPaymentId } });
    return 'amount_mismatch';
  }
  await tx.query(`UPDATE payments SET status='paid', provider_payment_id=$2, method=$3, failure_reason=NULL WHERE id=$1`, [pay.id, e.providerPaymentId, e.method ?? null]);

  const o = (await tx.query('SELECT * FROM orders WHERE id=$1 FOR UPDATE', [pay.order_id])).rows[0];
  if (o.status === 'pending_payment') {
    await tx.query(`UPDATE payments SET is_primary=true WHERE id=$1`, [pay.id]);
    await tx.query(`UPDATE orders SET status='placed', payment_status='paid', payment_expires_at=NULL WHERE id=$1`, [o.id]);
    await tx.query(`INSERT INTO order_status_history (order_id, from_status, to_status, note, actor_type) VALUES ($1,'pending_payment','placed','Online payment received','payment')`, [o.id]);
    await notifyUser(tx, o.user_id, 'order_update', 'Payment received', `Payment of ₹${o.total} received. Your order ${o.order_no} has been placed.`, { order_id: o.id });
    return 'paid';
  }
  if (o.status === 'cancelled' || o.status === 'rejected') {
    // Money arrived after the order was cancelled (e.g. payment window expired). Refund it.
    await tx.query(`UPDATE payments SET is_primary=true WHERE id=$1`, [pay.id]);
    await tx.query(`INSERT INTO refunds (payment_id, order_id, amount, reason) VALUES ($1,$2,$3,'Payment received after the order was cancelled')`, [pay.id, o.id, o.total]);
    await tx.query(`UPDATE orders SET status='refund_pending', payment_status='refund_pending' WHERE id=$1`, [o.id]);
    await tx.query(`INSERT INTO order_status_history (order_id, from_status, to_status, note, actor_type) VALUES ($1,$2,'refund_pending','Late payment will be refunded','system')`, [o.id, o.status]);
    return 'late_refund';
  }
  // Order already paid / progressed: this is a second payment for the same order. Keep the record, refund it.
  await tx.query(`INSERT INTO refunds (payment_id, order_id, amount, reason) VALUES ($1,$2,$3,'Duplicate payment for an order that was already paid')`, [pay.id, o.id, fromPaise(e.amountPaise)]);
  await audit(tx, { actorType: 'system', action: 'payment.duplicate_refund_queued', entity: 'payment', entityId: pay.id, after: { orderNo: o.order_no, providerPaymentId: e.providerPaymentId } });
  return 'duplicate';
}

export async function applyPaymentFailed(tx: Tx, e: { providerOrderId: string; providerPaymentId: string; reason?: string }) {
  const p = await tx.query('SELECT * FROM payments WHERE provider_order_id=$1 FOR UPDATE', [e.providerOrderId]);
  if (!p.rowCount || p.rows[0].status === 'paid') return; // a later success must not be overwritten by an earlier failure event
  // One failed attempt does not end the checkout: the provider order stays payable until the window expires.
  await tx.query(`UPDATE payments SET status='pending', failure_reason=$2 WHERE id=$1`, [p.rows[0].id, e.reason ?? 'Payment failed']);
}

/**
 * Customer-app confirmation. The signature proves the payment id belongs to our provider order, and we ALSO fetch the
 * payment from the provider server-to-server and require status=captured and the exact amount. Nothing is trusted from the client.
 */
export async function confirmPayment(ctx: AppCtx, userId: string, a: { providerOrderId: string; providerPaymentId: string; signature: string }) {
  const p = await ctx.db.query(`SELECT p.order_id, o.user_id FROM payments p JOIN orders o ON o.id=p.order_id WHERE p.provider_order_id=$1`, [a.providerOrderId]);
  if (!p.rowCount) throw notFound('Payment not found');
  if (p.rows[0].user_id !== userId) throw forbidden();
  if (!ctx.payments.verifyCheckoutSignature(a)) throw new AppError(400, 'BAD_SIGNATURE', 'Payment verification failed');
  let fetched;
  try { fetched = await ctx.payments.fetchPayment(a.providerPaymentId); } catch (e) {
    throw new AppError(502, 'PAYMENT_PROVIDER_ERROR', 'Could not confirm the payment right now. We will update your order automatically once it is confirmed.', { cause: (e as Error).message });
  }
  if (fetched.orderId !== a.providerOrderId) throw new AppError(400, 'PAYMENT_ORDER_MISMATCH', 'Payment does not belong to this order');
  if (fetched.status !== 'captured') return { orderId: p.rows[0].order_id as string, status: fetched.status === 'failed' ? ('failed' as const) : ('pending' as const) };
  const outcome = await withTx(ctx.db, (tx) => applyPaymentCaptured(tx, { providerOrderId: a.providerOrderId, providerPaymentId: a.providerPaymentId, amountPaise: fetched.amountPaise, method: fetched.method }));
  await processPendingRefunds(ctx); // late payments may have queued a refund
  return { orderId: p.rows[0].order_id as string, status: outcome === 'paid' || outcome === 'duplicate' ? ('paid' as const) : outcome };
}

// ------------------------------------------------------------------ refunds
export async function applyRefundProcessed(tx: Tx, e: { providerPaymentId: string; providerRefundId: string; amountPaise: number }) {
  if (!(await lockOrderOfPayment(tx, 'provider_payment_id', e.providerPaymentId))) return;
  const pay = await tx.query('SELECT * FROM payments WHERE provider_payment_id=$1 FOR UPDATE', [e.providerPaymentId]);
  if (!pay.rowCount) return;
  const payment = pay.rows[0];
  // match our refund row by provider refund id; fall back to the oldest unfinished refund for this payment
  let rf = await tx.query('SELECT * FROM refunds WHERE provider_refund_id=$1 FOR UPDATE', [e.providerRefundId]);
  if (!rf.rowCount) rf = await tx.query(`SELECT * FROM refunds WHERE payment_id=$1 AND status IN ('pending','processing') AND amount=$2 ORDER BY created_at LIMIT 1 FOR UPDATE`, [payment.id, fromPaise(e.amountPaise)]);
  if (!rf.rowCount) return;
  const refund = rf.rows[0];
  if (refund.status === 'processed') return; // idempotent
  await tx.query(`UPDATE refunds SET status='processed', provider_refund_id=COALESCE(provider_refund_id,$2) WHERE id=$1`, [refund.id, e.providerRefundId]);

  const refunded = toPaise((await tx.query(`SELECT COALESCE(SUM(amount),0) AS s FROM refunds WHERE payment_id=$1 AND status='processed'`, [payment.id])).rows[0].s);
  const full = refunded >= toPaise(payment.amount);
  await tx.query(`UPDATE payments SET status=$2 WHERE id=$1`, [payment.id, full ? 'refunded' : 'partially_refunded']);
  const o = (await tx.query('SELECT * FROM orders WHERE id=$1 FOR UPDATE', [payment.order_id])).rows[0];
  if (!payment.is_primary) { // a refunded duplicate payment: the order's own payment is unaffected
    await audit(tx, { actorType: 'system', action: 'payment.duplicate_refunded', entity: 'payment', entityId: payment.id, after: { orderNo: o.order_no } });
    return;
  }
  await tx.query(`UPDATE orders SET payment_status=$2, status=CASE WHEN $3 AND status IN ('refund_pending','delivered','collected') THEN 'refunded' ELSE status END WHERE id=$1`,
    [o.id, full ? 'refunded' : 'partially_refunded', full]);
  if (full && o.status !== 'refunded') {
    await tx.query(`INSERT INTO order_status_history (order_id, from_status, to_status, note, actor_type) VALUES ($1,$2,'refunded','Refund completed','payment')`, [o.id, o.status]);
    // A fully refunded order that had already earned coins gives them back.
    if (o.coins_credited_at && o.coins_to_earn > 0) {
      const w = await tx.query('SELECT balance FROM wallets WHERE user_id=$1', [o.user_id]);
      const take = Math.min(o.coins_to_earn, w.rows[0]?.balance ?? 0);
      if (take > 0) await postLedger(tx, { userId: o.user_id, type: 'earn_reversal', coins: -take, ref: `order:${o.id}:earn_reversal`, orderId: o.id, note: `Reversed: order ${o.order_no} refunded` });
    }
  }
  await notifyUser(tx, o.user_id, 'order_update', 'Refund processed', `₹${fromPaise(toPaise(refund.amount))} for order ${o.order_no} has been refunded to your original payment method.`, { order_id: o.id });
}

/** Ask the provider to refund every queued refund. Safe to retry: a failed call leaves the row pending. */
export async function processPendingRefunds(ctx: AppCtx): Promise<number> {
  const { rows } = await ctx.db.query(
    `SELECT r.id, r.amount, p.provider_payment_id, o.order_no FROM refunds r JOIN payments p ON p.id=r.payment_id JOIN orders o ON o.id=r.order_id
      WHERE r.status='pending' AND p.provider_payment_id IS NOT NULL AND p.provider=$1 ORDER BY r.created_at LIMIT 20`, [ctx.payments.name]); // UPI (upi_manual) refunds are sent back by staff, never via the gateway
  let done = 0;
  for (const r of rows) {
    const claim = await ctx.db.query(`UPDATE refunds SET status='processing' WHERE id=$1 AND status='pending' RETURNING id`, [r.id]);
    if (!claim.rowCount) continue;
    try {
      const res = await ctx.payments.refund({ providerPaymentId: r.provider_payment_id, amountPaise: toPaise(r.amount), receipt: `rf_${r.order_no}` });
      await ctx.db.query('UPDATE refunds SET provider_refund_id=$2 WHERE id=$1', [r.id, res.providerRefundId]);
      if (res.status === 'processed') await withTx(ctx.db, (tx) => applyRefundProcessed(tx, { providerPaymentId: r.provider_payment_id, providerRefundId: res.providerRefundId, amountPaise: toPaise(r.amount) }));
      done++;
    } catch {
      await ctx.db.query(`UPDATE refunds SET status='pending' WHERE id=$1 AND status='processing'`, [r.id]); // retry later
    }
  }
  return done;
}

/** Admin: refund (part of) a paid online order, e.g. after a return. */
export async function adminRefund(ctx: AppCtx, orderId: string, adminId: string, amountRupees: string | undefined, reason: string, ip?: string | null) {
  await withTx(ctx.db, async (tx) => {
    const o = (await tx.query('SELECT * FROM orders WHERE id=$1 FOR UPDATE', [orderId])).rows[0];
    if (!o) throw notFound('Order not found');
    const p = await tx.query(`SELECT * FROM payments WHERE order_id=$1 AND is_primary AND status IN ('paid','partially_refunded') LIMIT 1 FOR UPDATE`, [orderId]);
    if (!p.rowCount) throw conflict('NOT_REFUNDABLE', 'There is no captured online payment to refund on this order');
    const already = toPaise((await tx.query(`SELECT COALESCE(SUM(amount),0) AS s FROM refunds WHERE payment_id=$1 AND status IN ('pending','processing','processed')`, [p.rows[0].id])).rows[0].s);
    const remaining = toPaise(p.rows[0].amount) - already;
    const want = amountRupees ? toPaise(amountRupees) : remaining;
    if (want <= 0 || want > remaining) throw conflict('BAD_REFUND_AMOUNT', `Refund must be between ₹0.01 and ₹${fromPaise(remaining)}`);
    if (reason.trim().length < 3) throw new AppError(400, 'REASON_REQUIRED', 'Please give a reason for the refund');
    const r = await tx.query(`INSERT INTO refunds (payment_id, order_id, amount, reason, created_by) VALUES ($1,$2,$3,$4,$5) RETURNING id`, [p.rows[0].id, orderId, fromPaise(want), reason.trim(), adminId]);
    if (o.status === 'delivered' || o.status === 'collected') {
      await tx.query(`INSERT INTO order_status_history (order_id, from_status, to_status, note, actor_type, actor_id) VALUES ($1,$2,$2,$3,'admin',$4)`, [orderId, o.status, `Refund of ₹${fromPaise(want)} requested: ${reason.trim()}`, adminId]);
    }
    await audit(tx, { actorType: 'admin', actorId: adminId, action: 'refund.create', entity: 'order', entityId: orderId, after: { amount: fromPaise(want), reason, refundId: r.rows[0].id }, ip });
  });
  await processPendingRefunds(ctx);
}

// ------------------------------------------------------------------ webhooks
export async function handleWebhook(ctx: AppCtx, raw: Buffer, signature: string | undefined, eventId: string | undefined): Promise<{ status: number; body: Record<string, unknown> }> {
  if (!signature || !ctx.payments.verifyWebhookSignature(raw, signature)) return { status: 400, body: { ok: false, error: 'invalid signature' } };
  let payload: any;
  try { payload = JSON.parse(raw.toString('utf8')); } catch { return { status: 400, body: { ok: false, error: 'invalid json' } }; }
  const normalized: NormalizedWebhook = ctx.payments.parseWebhook(payload);
  const id = eventId || `${payload?.event}:${payload?.payload?.payment?.entity?.id ?? payload?.payload?.refund?.entity?.id ?? ''}:${payload?.created_at ?? ''}`;

  const result = await withTx(ctx.db, async (tx) => {
    const ins = await tx.query(`INSERT INTO payment_events (provider, event_id, event_type, payload) VALUES ($1,$2,$3,$4) ON CONFLICT (provider, event_id) DO NOTHING RETURNING id`,
      [ctx.payments.name, id, String(payload?.event ?? normalized.kind), JSON.stringify(payload)]);
    if (!ins.rowCount) return 'duplicate_event';
    let res = 'ignored';
    switch (normalized.kind) {
      case 'payment_captured': res = await applyPaymentCaptured(tx, normalized); break;
      case 'payment_failed': await applyPaymentFailed(tx, normalized); res = 'failed_recorded'; break;
      case 'refund_processed': await applyRefundProcessed(tx, normalized); res = 'refund_processed'; break;
      case 'refund_failed':
        await tx.query(`UPDATE refunds SET status='failed' WHERE provider_refund_id=$1 AND status<>'processed'`, [normalized.providerRefundId]); res = 'refund_failed'; break;
    }
    await tx.query(`UPDATE payment_events SET processed_at=now(), result=$2 WHERE id=$1`, [ins.rows[0].id, res]);
    return res;
  });
  if (normalized.kind === 'payment_captured') await processPendingRefunds(ctx);
  return { status: 200, body: { ok: true, result } };
}

