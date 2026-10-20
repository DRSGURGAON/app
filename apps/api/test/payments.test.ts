import { describe, it, expect, beforeAll, afterAll, beforeEach } from 'vitest';
import { randomUUID } from 'node:crypto';
import { makeCtx, reset, setting, mkProduct, mkUser, mkAddress, mkZone, openStore, giveCoins } from './helpers.js';
import { createOrder, transitionOrder, getOrderDetail, expireUnpaidOrders } from '../src/services/orders.js';
import { createPaymentSession, confirmPayment, handleWebhook, processPendingRefunds, adminRefund } from '../src/services/payments.js';
import { getBalance } from '../src/services/coins.js';
import { AppError } from '../src/lib/errors.js';
import { withTx } from '../src/db/pool.js';
import { applyPaymentCaptured } from '../src/services/payments.js';

const ctx = makeCtx();
const db = ctx.db;
const mock = ctx.payments;
afterAll(async () => { await db.end(); });
beforeEach(async () => { await reset(db); await openStore(db); await setting(db, 'delivery', { base_fee: 25, far_fee: 70 }); });

async function onlineOrder(price = 1000) {
  const u = await mkUser(db); const z = await mkZone(db, 'Town', 'base'); const a = await mkAddress(db, u.id, { zone: z.id }); const p = await mkProduct(db, { price, stock: 10 });
  const r = await createOrder(ctx, u.id, { idempotency_key: randomUUID(), items: [{ product_id: p.id, qty: 1 }], fulfilment: 'delivery', address_id: a.id, payment_method: 'online' });
  const session = await createPaymentSession(ctx, r.orderId, u.id);
  return { u, p, orderId: r.orderId, session, total: price + 25 };
}
const err = async (fn: () => Promise<unknown>) => { try { await fn(); } catch (e) { return e as AppError; } throw new Error('expected an error'); };
const body = (event: string, o: { orderId: string; payId: string; amount: number }) => JSON.stringify({ event, created_at: 1, payload: { payment: { entity: { id: o.payId, order_id: o.orderId, amount: o.amount, method: 'upi', error_description: 'bank declined' } } } });
const refundBody = (payId: string, refundId: string, amount: number) => JSON.stringify({ event: 'refund.processed', created_at: 2, payload: { refund: { entity: { id: refundId, payment_id: payId, amount } } } });
const post = (raw: string, eventId?: string, sig?: string) => handleWebhook(ctx, Buffer.from(raw), sig ?? mock.signWebhook(raw), eventId);

describe('payment session', () => {
  it('creates a provider order for the exact server total and reuses it on retry', async () => {
    const { session, total, orderId, u } = await onlineOrder();
    expect(session).toMatchObject({ provider: 'mock', mode: 'sandbox', amount_paise: total * 100, currency: 'INR' });
    const again = await createPaymentSession(ctx, orderId, u.id);
    expect(again.provider_order_id).toBe(session.provider_order_id);
    expect((await db.query('SELECT count(*)::int n FROM payments')).rows[0].n).toBe(1);
  });
  it('is refused for COD orders, other customers, and expired windows', async () => {
    const { orderId, u } = await onlineOrder();
    const stranger = await mkUser(db);
    expect((await err(() => createPaymentSession(ctx, orderId, stranger.id))).status).toBe(404);
    await db.query(`UPDATE orders SET payment_expires_at = now() - interval '1 second'`);
    expect((await err(() => createPaymentSession(ctx, orderId, u.id))).code).toBe('PAYMENT_EXPIRED');
    const cod = await mkProduct(db, { price: 1000 }); const a = await mkAddress(db, u.id, { zone: (await db.query('SELECT id FROM delivery_zones LIMIT 1')).rows[0].id });
    const c = await createOrder(ctx, u.id, { idempotency_key: randomUUID(), items: [{ product_id: cod.id, qty: 1 }], fulfilment: 'delivery', address_id: a.id, payment_method: 'cod' });
    expect((await err(() => createPaymentSession(ctx, c.orderId, u.id))).code).toBe('NOT_ONLINE');
  });
});

describe('client confirmation is never trusted on its own', () => {
  it('bad signature -> rejected, order stays unpaid', async () => {
    const { u, session, orderId } = await onlineOrder();
    const e = await err(() => confirmPayment(ctx, u.id, { providerOrderId: session.provider_order_id, providerPaymentId: 'pay_fake', signature: 'deadbeef' }));
    expect(e.code).toBe('BAD_SIGNATURE'); expect((await getOrderDetail(db, orderId)).status).toBe('pending_payment');
  });
  it('valid-looking signature for a payment the provider does not know -> not paid', async () => {
    const { u, session, orderId } = await onlineOrder();
    const { hmacHex } = await import('../src/lib/crypto.js'); const { MockPaymentProvider } = await import('../src/providers/payments.js');
    const sig = hmacHex(MockPaymentProvider.SECRET, `${session.provider_order_id}|pay_invented`);
    expect((await err(() => confirmPayment(ctx, u.id, { providerOrderId: session.provider_order_id, providerPaymentId: 'pay_invented', signature: sig }))).code).toBe('PAYMENT_PROVIDER_ERROR');
    expect((await getOrderDetail(db, orderId)).payment_status).toBe('pending');
  });
  it('payment reported but provider says only "authorized" -> stays pending', async () => {
    const { u, session, orderId, total } = await onlineOrder();
    const s = mock.simulatePayment(session.provider_order_id, total * 100, 'authorized');
    const r = await confirmPayment(ctx, u.id, { providerOrderId: session.provider_order_id, providerPaymentId: s.providerPaymentId, signature: s.signature });
    expect(r.status).toBe('pending'); expect((await getOrderDetail(db, orderId)).status).toBe('pending_payment');
  });
  it('captured payment -> order placed + paid; confirming again is harmless', async () => {
    const { u, session, orderId, total } = await onlineOrder();
    const s = mock.simulatePayment(session.provider_order_id, total * 100);
    const a = { providerOrderId: session.provider_order_id, providerPaymentId: s.providerPaymentId, signature: s.signature };
    expect((await confirmPayment(ctx, u.id, a)).status).toBe('paid'); expect((await confirmPayment(ctx, u.id, a)).status).toBe('paid');
    const o = await getOrderDetail(db, orderId); expect(o).toMatchObject({ status: 'placed', payment_status: 'paid' });
    expect(o.history.map((h: any) => h.to_status)).toEqual(['pending_payment', 'placed']);
    expect((await db.query(`SELECT count(*)::int n FROM notifications WHERE title='Payment received'`)).rows[0].n).toBe(1);
  });
  it("a customer cannot confirm someone else's payment", async () => {
    const { session, total } = await onlineOrder(); const evil = await mkUser(db);
    const s = mock.simulatePayment(session.provider_order_id, total * 100);
    expect((await err(() => confirmPayment(ctx, evil.id, { providerOrderId: session.provider_order_id, providerPaymentId: s.providerPaymentId, signature: s.signature }))).status).toBe(403);
  });
  it('a payment for the wrong amount never marks the order paid', async () => {
    const { u, session, orderId } = await onlineOrder();
    const s = mock.simulatePayment(session.provider_order_id, 100); // Rs 1 instead of Rs 1025
    const r = await confirmPayment(ctx, u.id, { providerOrderId: session.provider_order_id, providerPaymentId: s.providerPaymentId, signature: s.signature });
    expect(r.status).toBe('amount_mismatch');
    expect(await getOrderDetail(db, orderId)).toMatchObject({ status: 'pending_payment', payment_status: 'pending' });
    expect((await db.query('SELECT status, failure_reason FROM payments')).rows[0]).toMatchObject({ status: 'failed' });
    expect((await db.query(`SELECT count(*)::int n FROM audit_logs WHERE action='payment.amount_mismatch'`)).rows[0].n).toBe(1);
  });
});

describe('webhooks', () => {
  it('rejects a bad / missing signature and malformed JSON', async () => {
    const { session, total } = await onlineOrder(); const raw = body('payment.captured', { orderId: session.provider_order_id, payId: 'p1', amount: total * 100 });
    expect((await post(raw, 'e1', 'bad')).status).toBe(400);
    expect((await handleWebhook(ctx, Buffer.from(raw), undefined, 'e1')).status).toBe(400);
    expect((await post('{not json', 'e2')).status).toBe(400);
    expect((await db.query('SELECT count(*)::int n FROM payment_events')).rows[0].n).toBe(0);
  });
  it('payment.captured marks paid; the same event delivered twice is a no-op', async () => {
    const { session, total, orderId } = await onlineOrder(); const raw = body('payment.captured', { orderId: session.provider_order_id, payId: 'pay_A', amount: total * 100 });
    const r1 = await post(raw, 'evt_1'); const r2 = await post(raw, 'evt_1');
    expect(r1.body).toMatchObject({ ok: true, result: 'paid' }); expect(r2.body).toMatchObject({ ok: true, result: 'duplicate_event' });
    expect(await getOrderDetail(db, orderId)).toMatchObject({ status: 'placed', payment_status: 'paid' });
    expect((await db.query('SELECT count(*)::int n FROM order_status_history WHERE order_id=$1', [orderId])).rows[0].n).toBe(2);
  });
  it('same payment under a NEW event id is still idempotent', async () => {
    const { session, total, orderId } = await onlineOrder(); const raw = body('payment.captured', { orderId: session.provider_order_id, payId: 'pay_A', amount: total * 100 });
    await post(raw, 'evt_1'); const r = await post(raw, 'evt_2');
    expect(r.body.result).toBe('duplicate'); expect((await getOrderDetail(db, orderId)).status).toBe('placed');
  });
  it('payment.failed leaves the order retryable; a late failure never undoes a success', async () => {
    const { session, total, orderId, u } = await onlineOrder();
    await post(body('payment.failed', { orderId: session.provider_order_id, payId: 'pay_X', amount: total * 100 }), 'f1');
    expect(await getOrderDetail(db, orderId)).toMatchObject({ status: 'pending_payment', payment_status: 'pending' });
    expect((await db.query('SELECT status, failure_reason FROM payments')).rows[0]).toMatchObject({ status: 'pending', failure_reason: 'bank declined' }); // attempt failed, order still payable
    const retry = await createPaymentSession(ctx, orderId, u.id); expect(retry.provider_order_id).toBe(session.provider_order_id);
    await post(body('payment.captured', { orderId: session.provider_order_id, payId: 'pay_Y', amount: total * 100 }), 'f2');
    await post(body('payment.failed', { orderId: session.provider_order_id, payId: 'pay_X', amount: total * 100 }), 'f3');
    expect((await getOrderDetail(db, orderId)).payment_status).toBe('paid'); expect((await db.query('SELECT status FROM payments')).rows[0].status).toBe('paid');
  });
  it('webhook amount tampering is caught', async () => {
    const { session, orderId } = await onlineOrder();
    await post(body('payment.captured', { orderId: session.provider_order_id, payId: 'pay_Z', amount: 5000 }), 'm1');
    expect(await getOrderDetail(db, orderId)).toMatchObject({ status: 'pending_payment', payment_status: 'pending' });
  });
  it('unknown provider orders and unrelated events are accepted but ignored', async () => {
    expect((await post(body('payment.captured', { orderId: 'order_unknown', payId: 'p', amount: 100 }), 'u1')).body.result).toBe('unknown_order');
    expect((await post(JSON.stringify({ event: 'subscription.charged' }), 'u2')).body.result).toBe('ignored');
  });
  it('simultaneous duplicate deliveries do not double-process', async () => {
    const { session, total, orderId } = await onlineOrder(); const raw = body('payment.captured', { orderId: session.provider_order_id, payId: 'pay_C', amount: total * 100 });
    const res = await Promise.all(Array.from({ length: 6 }, () => post(raw, 'evt_same')));
    expect(res.filter((r) => r.body.result === 'paid')).toHaveLength(1);
    expect((await db.query(`SELECT count(*)::int n FROM order_status_history WHERE order_id=$1 AND to_status='placed'`, [orderId])).rows[0].n).toBe(1);
  });
});

describe('duplicate payments', () => {
  it('a second payment on an already-paid order is refunded, not kept', async () => {
    const { u, session, total, orderId } = await onlineOrder();
    const pay1 = mock.simulatePayment(session.provider_order_id, total * 100);
    await confirmPayment(ctx, u.id, { providerOrderId: session.provider_order_id, providerPaymentId: pay1.providerPaymentId, signature: pay1.signature });
    // simulate a second provider order for the same order (e.g. created after a mismatch) that the customer also paid
    await db.query(`INSERT INTO payments (order_id, provider, provider_order_id, amount, status, mode) VALUES ($1,'mock','mock_order_second',$2,'created','sandbox')`, [orderId, `${total}.00`]);
    await post(body('payment.captured', { orderId: 'mock_order_second', payId: 'pay_dup', amount: total * 100 }), 'dup1');
    const refunds = (await db.query('SELECT status, amount FROM refunds ORDER BY created_at')).rows;
    expect(refunds).toEqual([{ status: 'processed', amount: `${total}.00` }]);
    expect(await getOrderDetail(db, orderId)).toMatchObject({ status: 'placed', payment_status: 'paid' }); // the real payment is untouched
  });
  it('expiry marks the abandoned payment attempt failed', async () => {
    const { orderId } = await onlineOrder();
    await db.query(`UPDATE orders SET payment_expires_at = now() - interval '1 minute'`); await expireUnpaidOrders(ctx);
    expect((await db.query('SELECT status FROM payments WHERE order_id=$1', [orderId])).rows[0].status).toBe('failed');
  });
});

describe('late payment & refunds', () => {
  it('money arriving after the order expired is queued for refund and refunded automatically', async () => {
    const { session, total, orderId, p } = await onlineOrder();
    await db.query(`UPDATE orders SET payment_expires_at = now() - interval '1 minute'`); await expireUnpaidOrders(ctx);
    expect((await getOrderDetail(db, orderId)).status).toBe('cancelled');
    await post(body('payment.captured', { orderId: session.provider_order_id, payId: 'pay_late', amount: total * 100 }), 'late1');
    const o = await getOrderDetail(db, orderId);
    expect(o.status).toBe('refunded'); expect(o.payment_status).toBe('refunded'); // mock provider refunds instantly
    expect(o.refunds[0]).toMatchObject({ status: 'processed', amount: `${total}.00` });
    expect((await db.query('SELECT reserved_qty FROM products WHERE id=$1', [p.id])).rows[0].reserved_qty).toBe(0);
  });
  it('rejecting a paid online order refunds it, returns coins and ends as refunded', async () => {
    const u = await mkUser(db); const z = await mkZone(db, 'Town', 'base'); const a = await mkAddress(db, u.id, { zone: z.id }); const p = await mkProduct(db, { price: 1000, stock: 10 });
    await giveCoins(db, u.id, 30);
    const r = await createOrder(ctx, u.id, { idempotency_key: randomUUID(), items: [{ product_id: p.id, qty: 1 }], fulfilment: 'delivery', address_id: a.id, payment_method: 'online', use_coins: 30 });
    const s = await createPaymentSession(ctx, r.orderId, u.id); expect(s.amount_paise).toBe(99500); // 1000 - 30 + 25
    const pay = mock.simulatePayment(s.provider_order_id, 99500);
    await confirmPayment(ctx, u.id, { providerOrderId: s.provider_order_id, providerPaymentId: pay.providerPaymentId, signature: pay.signature });
    expect(await getBalance(db, u.id)).toBe(0);
    await transitionOrder(ctx, r.orderId, 'rejected', { type: 'admin', id: null }, { reason: 'Out of stock at counter' });
    let o = await getOrderDetail(db, r.orderId); expect(o).toMatchObject({ status: 'refund_pending', payment_status: 'refund_pending' });
    expect(o.history.map((h: any) => h.to_status)).toEqual(['pending_payment', 'placed', 'rejected', 'refund_pending']);
    await processPendingRefunds(ctx);
    o = await getOrderDetail(db, r.orderId); expect(o).toMatchObject({ status: 'refunded', payment_status: 'refunded' });
    expect(await getBalance(db, u.id)).toBe(30);
  });
  it('refund webhook confirmation is idempotent and a provider failure leaves the refund retryable', async () => {
    const { u, session, total, orderId } = await onlineOrder();
    const pay = mock.simulatePayment(session.provider_order_id, total * 100);
    await confirmPayment(ctx, u.id, { providerOrderId: session.provider_order_id, providerPaymentId: pay.providerPaymentId, signature: pay.signature });
    const realRefund = mock.refund.bind(mock); let calls = 0;
    (mock as any).refund = async () => { calls++; throw new Error('provider down'); };
    await transitionOrder(ctx, orderId, 'cancelled', { type: 'admin', id: null }, { reason: 'Customer asked to cancel' });
    await processPendingRefunds(ctx);
    expect(calls).toBe(1); expect((await db.query('SELECT status FROM refunds')).rows[0].status).toBe('pending'); expect((await getOrderDetail(db, orderId)).status).toBe('refund_pending');
    (mock as any).refund = async () => ({ providerRefundId: 'rfnd_1', status: 'pending' as const }); // provider accepts, settles later
    await processPendingRefunds(ctx); expect((await db.query('SELECT status, provider_refund_id FROM refunds')).rows[0]).toMatchObject({ status: 'processing', provider_refund_id: 'rfnd_1' });
    const raw = refundBody(pay.providerPaymentId, 'rfnd_1', total * 100);
    await post(raw, 'r1'); await post(raw, 'r1'); await post(raw, 'r2');
    expect(await getOrderDetail(db, orderId)).toMatchObject({ status: 'refunded', payment_status: 'refunded' });
    expect((await db.query(`SELECT count(*)::int n FROM notifications WHERE title='Refund processed'`)).rows[0].n).toBe(1);
    (mock as any).refund = realRefund;
  });
  it('admin partial refund after delivery; cannot exceed what was paid; full refund reverses earned coins', async () => {
    const { u, session, total, orderId } = await onlineOrder(2000); // earns 20 coins
    const pay = mock.simulatePayment(session.provider_order_id, total * 100);
    await confirmPayment(ctx, u.id, { providerOrderId: session.provider_order_id, providerPaymentId: pay.providerPaymentId, signature: pay.signature });
    for (const s of ['accepted', 'packing', 'ready_for_dispatch', 'out_for_delivery', 'delivered'] as const) await transitionOrder(ctx, orderId, s, { type: 'admin', id: null });
    expect(await getBalance(db, u.id)).toBe(20);
    const adm = await adminId();
    await adminRefund(ctx, orderId, adm, '500', 'Two items returned');
    expect(await getOrderDetail(db, orderId)).toMatchObject({ status: 'delivered', payment_status: 'partially_refunded' });
    expect((await err(() => adminRefund(ctx, orderId, adm, '99999', 'too much'))).code).toBe('BAD_REFUND_AMOUNT');
    expect((await err(() => adminRefund(ctx, orderId, adm, undefined, 'x'))).code).toBe('REASON_REQUIRED');
    await adminRefund(ctx, orderId, adm, undefined, 'Remainder refunded');
    expect(await getOrderDetail(db, orderId)).toMatchObject({ status: 'refunded', payment_status: 'refunded' });
    expect(await getBalance(db, u.id)).toBe(0); // earned coins reversed
    expect((await db.query(`SELECT type, coins FROM wallet_transactions WHERE user_id=$1 ORDER BY id`, [u.id])).rows.map((r) => `${r.type}:${r.coins}`)).toEqual(['earn:20', 'earn_reversal:-20']);
  });
});

async function adminId() {
  const r = await db.query(`INSERT INTO admin_users (email, name, password_hash, role) VALUES ($1,'A','x','owner') ON CONFLICT (email) DO UPDATE SET name='A' RETURNING id`, ['a@test.local']);
  return r.rows[0].id as string;
}
void applyPaymentCaptured; void withTx; void beforeAll;
