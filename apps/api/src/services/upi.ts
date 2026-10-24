import type { Tx } from '../db/pool.js';
import { withTx } from '../db/pool.js';
import { AppError, conflict, notFound } from '../lib/errors.js';
import { audit } from '../lib/audit.js';
import { fromPaise, toPaise } from '../lib/money.js';
import { applyPaymentCaptured, applyRefundProcessed } from './payments.js';
import { loadSettings, type AppSettings } from './settings.js';
import { transitionOrder, type AppCtx } from './orders.js';

// UPI paid straight to the store's own UPI ID. There is no gateway, so nothing the phone reports is trusted:
// the customer can only say "I have paid"; a staff member confirms the amount and UTR they can see in the bank app.

export const UPI_PROVIDER = 'upi_manual';
export const UTR_RE = /^\d{12}$/;

/** Standard UPI intent link ("upi://pay?..."). A merchant category code adds mc + tr, as banks issue for merchant UPI IDs. */
export function buildUpiLink(s: Pick<AppSettings['upi'], 'vpa' | 'payee_name' | 'merchant_code'>, a: { amountPaise: number; orderNo: string }): string {
  const params: [string, string][] = [['pa', s.vpa], ['pn', s.payee_name], ['am', fromPaise(a.amountPaise)], ['cu', 'INR'], ['tn', `Order ${a.orderNo}`]];
  if (s.merchant_code) params.push(['mc', s.merchant_code], ['tr', a.orderNo]);
  // '@' stays literal: UPI IDs are conventionally written unescaped and not every UPI app decodes %40.
  return 'upi://pay?' + params.map(([k, v]) => `${k}=${encodeURIComponent(v).replace(/%40/g, '@')}`).join('&');
}

// iPhone has no system chooser for upi:// links, so each app is opened by its own scheme.
// These schemes are defined by the apps themselves and must be checked on real iPhones.
const IOS_APP_SCHEMES = [
  { app: 'PhonePe', prefix: 'phonepe://pay?' },
  { app: 'Google Pay', prefix: 'tez://upi/pay?' },
  { app: 'Paytm', prefix: 'paytmmp://pay?' },
];
export function iosAppLinks(upiLink: string) {
  const query = upiLink.slice(upiLink.indexOf('?') + 1);
  return IOS_APP_SCHEMES.map(({ app, prefix }) => ({ app, link: prefix + query }));
}

async function loadUpiOrder(q: Tx | AppCtx['db'], orderId: string, userId: string | null, lock: boolean) {
  const r = await q.query(`SELECT * FROM orders WHERE id=$1${userId ? ' AND user_id=$2' : ''}${lock ? ' FOR UPDATE' : ''}`, userId ? [orderId, userId] : [orderId]);
  if (!r.rowCount) throw notFound('Order not found');
  const order = r.rows[0];
  if (order.payment_method !== 'upi') throw conflict('NOT_UPI', 'This order is not a UPI order');
  return order;
}

async function loadUpiPayment(q: Tx | AppCtx['db'], orderId: string, lock: boolean) {
  const p = await q.query(`SELECT * FROM payments WHERE order_id=$1 AND provider=$2 ORDER BY created_at LIMIT 1${lock ? ' FOR UPDATE' : ''}`, [orderId, UPI_PROVIDER]);
  if (!p.rowCount) throw conflict('UPI_PAYMENT_MISSING', 'No UPI payment record exists for this order');
  return p.rows[0];
}

/** What the customer app needs to pay (or follow) a UPI order. */
export async function getUpiPaymentInfo(ctx: AppCtx, orderId: string, userId: string) {
  const order = await loadUpiOrder(ctx.db, orderId, userId, false);
  const pay = await loadUpiPayment(ctx.db, orderId, false);
  const s = (await loadSettings(ctx.db)).upi;
  const amountPaise = toPaise(order.total);
  const configured = s.enabled && !!s.vpa;
  const payable = configured && order.status === 'pending_payment' && order.payment_status === 'pending'
    && order.payment_expires_at !== null && new Date(order.payment_expires_at) > new Date();
  const link = payable ? buildUpiLink(s, { amountPaise, orderNo: order.order_no }) : null;
  return {
    order_id: order.id, order_no: order.order_no, order_status: order.status, payment_status: order.payment_status,
    amount: order.total, amount_paise: amountPaise, payable, expires_at: order.payment_expires_at,
    vpa: configured ? s.vpa : null, payee_name: s.payee_name, merchant_mode: !!s.merchant_code,
    link, ios_app_links: link ? iosAppLinks(link) : [],
    claimed_utr: pay.claimed_utr as string | null, verified: pay.status === 'paid' || pay.status === 'refunded' || pay.status === 'partially_refunded',
  };
}

/** Customer: "I have paid". Only moves the payment to 'verifying'; the order is NOT placed until staff confirm. */
export async function reportUpiPayment(ctx: AppCtx, orderId: string, userId: string, utr: string | null) {
  if (utr !== null && !UTR_RE.test(utr)) throw new AppError(400, 'INVALID_UTR', 'UTR / UPI reference must be exactly 12 digits');
  await withTx(ctx.db, async (tx) => {
    // Lock the customer first (same order as checkout) so the unverified-orders limit cannot be raced.
    await tx.query('SELECT id FROM users WHERE id=$1 FOR UPDATE', [userId]);
    const order = await loadUpiOrder(tx, orderId, userId, true);
    const pay = await loadUpiPayment(tx, orderId, true);

    if (order.payment_status === 'verifying') {
      // Already reported: only fill in a UTR that was missing.
      if (utr && !pay.claimed_utr) await tx.query('UPDATE payments SET claimed_utr=$2 WHERE id=$1', [pay.id, utr]);
      return;
    }
    if (order.status !== 'pending_payment' || order.payment_status !== 'pending') {
      if (order.payment_status === 'paid') return; // already confirmed by staff
      throw conflict('NOT_PAYABLE', 'This order can no longer be paid. If money was deducted, please contact the store with your UTR.');
    }
    if (!order.payment_expires_at || new Date(order.payment_expires_at) <= new Date()) {
      throw conflict('PAYMENT_EXPIRED', 'The payment time for this order has ended. If money was deducted, please contact the store with your UTR.');
    }
    const s = (await loadSettings(tx)).upi;
    const open = (await tx.query(`SELECT count(*)::int n FROM orders WHERE user_id=$1 AND payment_status='verifying'`, [userId])).rows[0].n;
    if (open >= s.max_unverified_per_customer) {
      throw conflict('TOO_MANY_UNVERIFIED', 'Your earlier UPI payments are still being checked by the store. Please wait for them to be confirmed.');
    }

    await tx.query(`UPDATE payments SET status='pending', claimed_utr=COALESCE($2, claimed_utr), claimed_at=now() WHERE id=$1`, [pay.id, utr]);
    // No automatic expiry once reported: the money may already be in the bank, so only staff may cancel from here.
    await tx.query(`UPDATE orders SET payment_status='verifying', payment_expires_at=NULL WHERE id=$1`, [order.id]);
    await tx.query(`INSERT INTO order_status_history (order_id, from_status, to_status, note, actor_type, actor_id) VALUES ($1,'pending_payment','pending_payment',$2,'customer',$3)`,
      [order.id, utr ? `Customer reported UPI payment (UTR ${utr})` : 'Customer reported UPI payment', userId]);
  });
}

export type UpiConfirmOutcome = 'paid' | 'duplicate' | 'late_refund';

/**
 * Staff: the money is in the bank. Amount and UTR are what staff read in the bank app, never the customer's claim.
 * Settles through applyPaymentCaptured, so late payments (order already cancelled) queue a refund exactly like the gateway flow.
 */
export async function confirmUpiPayment(ctx: AppCtx, orderId: string, adminId: string, a: { amountPaise: number; utr: string; acceptUtrMismatch?: boolean }, ip?: string | null): Promise<UpiConfirmOutcome> {
  if (!UTR_RE.test(a.utr)) throw new AppError(400, 'INVALID_UTR', 'UTR / UPI reference must be exactly 12 digits');
  try {
    return await withTx(ctx.db, async (tx) => {
      const order = await loadUpiOrder(tx, orderId, null, true);
      const pay = await loadUpiPayment(tx, orderId, true);
      if (['paid', 'refunded', 'partially_refunded'].includes(pay.status)) {
        if (pay.provider_payment_id === a.utr) return 'duplicate' as const; // double click / two staff
        throw conflict('ALREADY_CONFIRMED', `This order was already confirmed with UTR ${pay.provider_payment_id}`);
      }
      const totalPaise = toPaise(order.total);
      if (a.amountPaise !== totalPaise) {
        throw conflict('AMOUNT_MISMATCH', `The bank shows ₹${fromPaise(a.amountPaise)} but this order is ₹${fromPaise(totalPaise)}. Do not confirm; contact the customer.`);
      }
      if (pay.claimed_utr && pay.claimed_utr !== a.utr && !a.acceptUtrMismatch) {
        throw conflict('UTR_MISMATCH', `The customer entered UTR ${pay.claimed_utr}, which differs from ${a.utr}. Check the bank app; confirm again only if you are sure.`);
      }
      const used = await tx.query(`SELECT o.order_no FROM payments p JOIN orders o ON o.id=p.order_id WHERE p.provider_payment_id=$1`, [a.utr]);
      if (used.rowCount) throw conflict('UTR_ALREADY_USED', `UTR ${a.utr} has already been used for order ${used.rows[0].order_no}`);

      await tx.query('UPDATE payments SET verified_by=$2, verified_at=now() WHERE id=$1', [pay.id, adminId]);
      const outcome = await applyPaymentCaptured(tx, { providerOrderId: pay.provider_order_id, providerPaymentId: a.utr, amountPaise: a.amountPaise, method: 'upi' });
      if (outcome !== 'paid' && outcome !== 'duplicate' && outcome !== 'late_refund') {
        throw new AppError(409, 'UPI_CONFIRM_FAILED', `Could not confirm this payment (${outcome})`);
      }
      await audit(tx, {
        actorType: 'admin', actorId: adminId, action: 'payment.upi_confirmed', entity: 'order', entityId: orderId,
        before: { status: order.status, payment_status: order.payment_status, claimed_utr: pay.claimed_utr },
        after: { utr: a.utr, amount: fromPaise(a.amountPaise), outcome, utr_mismatch_accepted: !!(pay.claimed_utr && pay.claimed_utr !== a.utr) }, ip,
      });
      return outcome;
    });
  } catch (e: any) {
    // Two staff confirming different orders with the same UTR at the same moment: the UNIQUE index is the final guard.
    if (e?.code === '23505' && String(e.constraint ?? e.detail ?? '').includes('provider_payment_id')) throw conflict('UTR_ALREADY_USED', `UTR ${a.utr} has already been used for another order`);
    throw e;
  }
}

/** Staff: no matching money in the bank. Cancels the order (stock, coins and coupon are returned) with the reason shown to the customer. */
export async function rejectUpiPayment(ctx: AppCtx, orderId: string, adminId: string, reason: string, ip?: string | null) {
  const order = await loadUpiOrder(ctx.db, orderId, null, false);
  if (order.status !== 'pending_payment') throw conflict('NOT_PENDING', 'Only an unpaid UPI order can be rejected. Use refund for a confirmed payment.');
  await transitionOrder(ctx, orderId, 'cancelled', { type: 'admin', id: adminId }, { reason: `UPI payment not received: ${reason.trim()}`, ip });
}

/** Staff sent a queued refund back by UPI / bank transfer themselves; record it so the order shows Refunded. */
export async function recordManualRefund(ctx: AppCtx, orderId: string, refundId: string, adminId: string, reference: string, ip?: string | null) {
  const ref = reference.trim();
  if (!/^[A-Za-z0-9][A-Za-z0-9 /_-]{3,59}$/.test(ref)) throw new AppError(400, 'INVALID_REFERENCE', 'Enter the refund UTR / reference (4–60 letters or digits)');
  try {
    await withTx(ctx.db, async (tx) => {
      const r = await tx.query(
        `SELECT r.*, p.provider, p.provider_payment_id FROM refunds r JOIN payments p ON p.id=r.payment_id WHERE r.id=$1 AND r.order_id=$2 FOR UPDATE OF r`, [refundId, orderId]);
      if (!r.rowCount) throw notFound('Refund not found');
      const refund = r.rows[0];
      if (refund.provider !== UPI_PROVIDER) throw conflict('NOT_MANUAL_REFUND', 'This refund is processed by the payment gateway, not manually');
      if (refund.status === 'processed') return;
      // Our own id goes on the row first, so applyRefundProcessed settles exactly this refund (not another one of equal amount).
      await tx.query('UPDATE refunds SET provider_refund_id=$2, processed_by=$3 WHERE id=$1', [refund.id, `manual:${ref}`, adminId]);
      await applyRefundProcessed(tx, { providerPaymentId: refund.provider_payment_id, providerRefundId: `manual:${ref}`, amountPaise: toPaise(refund.amount) });
      await audit(tx, { actorType: 'admin', actorId: adminId, action: 'refund.manual_processed', entity: 'order', entityId: orderId, after: { refundId, amount: refund.amount, reference: ref }, ip });
    });
  } catch (e: any) {
    if (e?.code === '23505' && String(e.constraint ?? e.detail ?? '').includes('provider_refund_id')) throw conflict('REFERENCE_ALREADY_USED', 'That refund reference is already recorded on another refund');
    throw e;
  }
}
