import { describe, it, expect, afterAll, beforeEach } from 'vitest';
import { randomUUID } from 'node:crypto';
import { makeCtx, reset, setting, mkProduct, mkUser, openStore } from './helpers.js';
import { createOrder, getOrderDetail, transitionOrder } from '../src/services/orders.js';
import { adminRefund, confirmPayment, createPaymentSession, processPendingRefunds } from '../src/services/payments.js';
import { confirmUpiPayment, recordManualRefund } from '../src/services/upi.js';
import type { AppError } from '../src/lib/errors.js';

// Cancelling an order that was already (partly) refunded: refund exactly the remainder, once, and keep refund history.
const ctx = makeCtx();
const db = ctx.db;
afterAll(async () => { await db.end(); });
beforeEach(async () => { await reset(db); await openStore(db); await setting(db, 'upi', { enabled: true, vpa: 'shop@canara' }); });

const err = async (fn: () => Promise<unknown>) => { try { await fn(); } catch (e) { return e as AppError; } throw new Error('expected an error'); };
const mkAdmin = async () => (await db.query(`INSERT INTO admin_users (email,name,password_hash,role) VALUES ($1,'Owner','x','owner') RETURNING id`, [`${randomUUID()}@t.test`])).rows[0].id as string;
const refundsOf = async (orderId: string) => (await db.query('SELECT id, amount, status FROM refunds WHERE order_id=$1 ORDER BY created_at, id', [orderId])).rows;
const committed = async (orderId: string) => (await db.query(`SELECT COALESCE(SUM(amount),0)::numeric(12,2)::text s FROM refunds WHERE order_id=$1 AND status IN ('pending','processing','processed')`, [orderId])).rows[0].s;
const cancel = (orderId: string, admin: string) => transitionOrder(ctx, orderId, 'cancelled', { type: 'admin', id: admin }, { reason: 'customer did not collect' });

/** ₹1,000 pickup order paid by UPI and confirmed by staff. */
async function paidUpiOrder(admin: string) {
  const u = await mkUser(db); const p = await mkProduct(db, { price: 1000, stock: 10 });
  const r = await createOrder(ctx, u.id, { idempotency_key: randomUUID(), items: [{ product_id: p.id, qty: 1 }], fulfilment: 'pickup', payment_method: 'upi' });
  await confirmUpiPayment(ctx, r.orderId, admin, { amountPaise: 100000, utr: String(400000000000 + Math.floor(Math.random() * 99999999999)) });
  return { orderId: r.orderId, p, u };
}
async function refundAndSend(orderId: string, admin: string, amount: string | undefined, ref: string) {
  await adminRefund(ctx, orderId, admin, amount, 'damaged item');
  const pending = (await db.query(`SELECT id FROM refunds WHERE order_id=$1 AND status='pending' ORDER BY created_at DESC LIMIT 1`, [orderId])).rows[0];
  await recordManualRefund(ctx, orderId, pending.id, admin, ref);
}

describe('H1: cancel after a partial refund refunds only the remainder, exactly once', () => {
  it('₹1,000 paid, ₹200 refunded, then cancelled → one ₹800 refund queued; total never exceeds ₹1,000', async () => {
    const admin = await mkAdmin(); const { orderId, p } = await paidUpiOrder(admin);
    await refundAndSend(orderId, admin, '200', 'UPI 600000000001');
    expect((await getOrderDetail(db, orderId)).payment_status).toBe('partially_refunded');

    await cancel(orderId, admin);
    const rows = await refundsOf(orderId);
    expect(rows.map((r) => [r.amount, r.status])).toEqual([['200.00', 'processed'], ['800.00', 'pending']]);
    expect(await committed(orderId)).toBe('1000.00');
    expect(await getOrderDetail(db, orderId)).toMatchObject({ status: 'refund_pending', payment_status: 'refund_pending', can_cancel: false });
    expect((await db.query('SELECT reserved_qty FROM products WHERE id=$1', [p.id])).rows[0].reserved_qty).toBe(0);

    // A second cancellation is refused, and staff cannot refund beyond what was paid.
    expect((await err(() => cancel(orderId, admin))).code).toBe('INVALID_TRANSITION');
    expect((await err(() => adminRefund(ctx, orderId, admin, '1', 'extra'))).code).toBe('BAD_REFUND_AMOUNT');
    expect(await refundsOf(orderId)).toHaveLength(2);

    // Staff send the ₹800 → order and payment end fully refunded.
    await recordManualRefund(ctx, orderId, rows[1].id, admin, 'UPI 600000000002');
    expect(await getOrderDetail(db, orderId)).toMatchObject({ status: 'refunded', payment_status: 'refunded' });
    expect((await db.query(`SELECT status FROM payments WHERE order_id=$1 AND is_primary`, [orderId])).rows[0].status).toBe('refunded');
  });

  it('a refund still pending counts as committed: no double refund of the same ₹200', async () => {
    const admin = await mkAdmin(); const { orderId } = await paidUpiOrder(admin);
    await adminRefund(ctx, orderId, admin, '200', 'damaged item'); // UPI: stays pending until staff send it
    await cancel(orderId, admin);
    expect((await refundsOf(orderId)).map((r) => [r.amount, r.status])).toEqual([['200.00', 'pending'], ['800.00', 'pending']]);
    expect(await committed(orderId)).toBe('1000.00');
  });

  it('a refund the gateway is still PROCESSING counts as committed', async () => {
    const admin = await mkAdmin(); const { orderId } = await paidUpiOrder(admin);
    await adminRefund(ctx, orderId, admin, '200', 'damaged item');
    await db.query(`UPDATE refunds SET status='processing' WHERE order_id=$1`, [orderId]);
    await cancel(orderId, admin);
    expect((await refundsOf(orderId)).map((r) => [r.amount, r.status])).toEqual([['200.00', 'processing'], ['800.00', 'pending']]);
    expect(await committed(orderId)).toBe('1000.00');
  });

  it('a FAILED refund returned no money, so it is not counted', async () => {
    const admin = await mkAdmin(); const { orderId } = await paidUpiOrder(admin);
    await adminRefund(ctx, orderId, admin, '200', 'damaged item');
    await db.query(`UPDATE refunds SET status='failed' WHERE order_id=$1`, [orderId]);
    await cancel(orderId, admin);
    const rows = await refundsOf(orderId);
    expect(rows.map((r) => [r.amount, r.status])).toEqual([['200.00', 'failed'], ['1000.00', 'pending']]);
    expect(await committed(orderId)).toBe('1000.00');
  });

  it('a full refund still pending + cancel → no second refund, order waits for that refund', async () => {
    const admin = await mkAdmin(); const { orderId } = await paidUpiOrder(admin);
    await adminRefund(ctx, orderId, admin, undefined, 'full refund');
    await cancel(orderId, admin);
    expect((await refundsOf(orderId)).map((r) => [r.amount, r.status])).toEqual([['1000.00', 'pending']]);
    expect(await getOrderDetail(db, orderId)).toMatchObject({ status: 'refund_pending', payment_status: 'refund_pending' });
  });

  it('concurrent staff refund + cancellation never refund more than was paid', async () => {
    const admin = await mkAdmin();
    for (let i = 0; i < 5; i++) {
      const { orderId } = await paidUpiOrder(admin);
      await refundAndSend(orderId, admin, '200', `UPI 61000000000${i}`);
      const res = await Promise.allSettled([adminRefund(ctx, orderId, admin, '800', 'rest'), cancel(orderId, admin)]);
      expect(res[1].status).toBe('fulfilled'); // the cancellation always succeeds
      expect(await committed(orderId)).toBe('1000.00');
      expect((await refundsOf(orderId)).filter((r) => r.amount === '800.00')).toHaveLength(1);
    }
  });

  it('gateway (mock) order: partial refund then cancel → remainder sent through the gateway, order refunded', async () => {
    const admin = await mkAdmin(); const u = await mkUser(db); const p = await mkProduct(db, { price: 1000, stock: 10 });
    const r = await createOrder(ctx, u.id, { idempotency_key: randomUUID(), items: [{ product_id: p.id, qty: 1 }], fulfilment: 'pickup', payment_method: 'online' });
    const s = await createPaymentSession(ctx, r.orderId, u.id);
    const sim = ctx.payments.simulatePayment(s.provider_order_id, 100000);
    await confirmPayment(ctx, u.id, { providerOrderId: s.provider_order_id, providerPaymentId: sim.providerPaymentId, signature: sim.signature });
    await adminRefund(ctx, r.orderId, admin, '200', 'damaged item'); // mock gateway processes it immediately
    expect((await getOrderDetail(db, r.orderId)).payment_status).toBe('partially_refunded');
    await cancel(r.orderId, admin);
    await processPendingRefunds(ctx);
    expect((await refundsOf(r.orderId)).map((x) => [x.amount, x.status])).toEqual([['200.00', 'processed'], ['800.00', 'processed']]);
    expect(await getOrderDetail(db, r.orderId)).toMatchObject({ status: 'refunded', payment_status: 'refunded' });
  });
});

describe('M1: cancellation keeps refunded / partially refunded payment status', () => {
  it('fully refunded order cancelled → status cancelled, payment stays "refunded", no new refund', async () => {
    const admin = await mkAdmin(); const { orderId } = await paidUpiOrder(admin);
    await refundAndSend(orderId, admin, undefined, 'UPI 600000000003');
    expect((await getOrderDetail(db, orderId)).payment_status).toBe('refunded');
    await cancel(orderId, admin);
    expect(await getOrderDetail(db, orderId)).toMatchObject({ status: 'cancelled', payment_status: 'refunded' });
    expect(await refundsOf(orderId)).toHaveLength(1);
    expect((await db.query(`SELECT status FROM payments WHERE order_id=$1 AND is_primary`, [orderId])).rows[0].status).toBe('refunded');
  });

  it('partially refunded order cancelled → never "failed"; history keeps both refunds', async () => {
    const admin = await mkAdmin(); const { orderId } = await paidUpiOrder(admin);
    await refundAndSend(orderId, admin, '300', 'UPI 600000000004');
    await cancel(orderId, admin);
    const o = await getOrderDetail(db, orderId);
    expect(o.payment_status).not.toBe('failed');
    expect(o.payment_status).toBe('refund_pending');
    expect(o.refunds.map((x: any) => [x.amount, x.status])).toEqual([['300.00', 'processed'], ['700.00', 'pending']]);
  });

  it('unpaid UPI order cancelled → payment "failed"; COD order keeps cod_pending', async () => {
    const admin = await mkAdmin(); const u = await mkUser(db); const p = await mkProduct(db, { price: 1000, stock: 10 });
    const upi = await createOrder(ctx, u.id, { idempotency_key: randomUUID(), items: [{ product_id: p.id, qty: 1 }], fulfilment: 'pickup', payment_method: 'upi' });
    const cod = await createOrder(ctx, u.id, { idempotency_key: randomUUID(), items: [{ product_id: p.id, qty: 1 }], fulfilment: 'pickup', payment_method: 'cod' });
    await cancel(upi.orderId, admin); await cancel(cod.orderId, admin);
    expect(await getOrderDetail(db, upi.orderId)).toMatchObject({ status: 'cancelled', payment_status: 'failed' });
    expect(await getOrderDetail(db, cod.orderId)).toMatchObject({ status: 'cancelled', payment_status: 'cod_pending' });
    expect(await refundsOf(upi.orderId)).toHaveLength(0);
  });
});
