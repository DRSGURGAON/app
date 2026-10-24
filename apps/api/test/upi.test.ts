import { describe, it, expect, beforeAll, afterAll, beforeEach } from 'vitest';
import { randomUUID } from 'node:crypto';
import type { FastifyInstance } from 'fastify';
import { buildApp } from '../src/app.js';
import { makeCtx, reset, setting, mkProduct, mkUser, openStore, giveCoins } from './helpers.js';
import { createOrder, expireUnpaidOrders, getOrderDetail, listUserOrders, transitionOrder } from '../src/services/orders.js';
import { adminRefund, processPendingRefunds } from '../src/services/payments.js';
import { buildUpiLink, confirmUpiPayment, getUpiPaymentInfo, iosAppLinks, recordManualRefund, rejectUpiPayment, reportUpiPayment } from '../src/services/upi.js';
import { loadConfig } from '../src/config.js';
import { createPaymentProvider } from '../src/providers/payments.js';
import { hashPassword } from '../src/lib/crypto.js';
import type { AppError } from '../src/lib/errors.js';

const ctx = makeCtx();
const db = ctx.db;
let app: FastifyInstance;
beforeAll(async () => { app = await buildApp(ctx); await app.ready(); });
afterAll(async () => { await app.close(); await db.end(); });
beforeEach(async () => {
  await reset(db); await openStore(db);
  await setting(db, 'upi', { enabled: true, vpa: 'ardhsainik@sbi', payee_name: 'Ardh Sainik Canteen' });
});

const UTR = '412345678901';
const err = async (fn: () => Promise<unknown>) => { try { await fn(); } catch (e) { return e as AppError; } throw new Error('expected an error'); };
const mkAdmin = async (role = 'owner') => (await db.query(`INSERT INTO admin_users (email,name,password_hash,role) VALUES ($1,'Staff','x',$2) RETURNING id`, [`${randomUUID()}@t.test`, role])).rows[0].id as string;
const stockOf = async (id: string) => (await db.query('SELECT stock_qty, reserved_qty FROM products WHERE id=$1', [id])).rows[0];
const upiPay = async (orderId: string) => (await db.query(`SELECT * FROM payments WHERE order_id=$1 AND provider='upi_manual'`, [orderId])).rows[0];

async function upiOrder(o: { price?: number; userId?: string; coins?: number } = {}) {
  const u = o.userId ? { id: o.userId } : await mkUser(db);
  const p = await mkProduct(db, { price: o.price ?? 1000, stock: 10 });
  const r = await createOrder(ctx, u.id, { idempotency_key: randomUUID(), items: [{ product_id: p.id, qty: 1 }], fulfilment: 'pickup', payment_method: 'upi', use_coins: o.coins ?? 0 });
  const order = await getOrderDetail(db, r.orderId);
  return { u, p, orderId: r.orderId, total: order.totals.total as string };
}

describe('UPI link', () => {
  it('builds a standard upi:// link; a merchant code adds mc + tr', () => {
    const personal = buildUpiLink({ vpa: 'shop@sbi', payee_name: 'Ardh Sainik Canteen', merchant_code: '' }, { amountPaise: 102550, orderNo: 'ASM261024-00001' });
    expect(personal).toBe('upi://pay?pa=shop@sbi&pn=Ardh%20Sainik%20Canteen&am=1025.50&cu=INR&tn=Order%20ASM261024-00001');
    const merchant = buildUpiLink({ vpa: 'shop@sbi', payee_name: 'Shop', merchant_code: '5411' }, { amountPaise: 99900, orderNo: 'ASM1' });
    expect(merchant).toBe('upi://pay?pa=shop@sbi&pn=Shop&am=999.00&cu=INR&tn=Order%20ASM1&mc=5411&tr=ASM1');
    const ios = iosAppLinks(merchant);
    expect(ios.map((l) => l.app)).toEqual(['PhonePe', 'Google Pay', 'Paytm']);
    expect(ios[0]!.link).toBe('phonepe://pay?pa=shop@sbi&pn=Shop&am=999.00&cu=INR&tn=Order%20ASM1&mc=5411&tr=ASM1');
  });
});

describe('UPI checkout', () => {
  it('waits for payment with stock reserved and one UPI payment record', async () => {
    const { orderId, p, u } = await upiOrder();
    const o = await getOrderDetail(db, orderId);
    expect(o).toMatchObject({ status: 'pending_payment', payment_method: 'upi', payment_status: 'pending' });
    expect(o.payment_expires_at).not.toBeNull();
    expect(await stockOf(p.id)).toMatchObject({ reserved_qty: 1 });
    expect(await upiPay(orderId)).toMatchObject({ status: 'created', amount: '1000.00', method: 'upi', provider_payment_id: null });
    const info = await getUpiPaymentInfo(ctx, orderId, u.id);
    expect(info).toMatchObject({ payable: true, vpa: 'ardhsainik@sbi', amount: '1000.00', amount_paise: 100000, merchant_mode: false });
    expect(info.link).toContain('pa=ardhsainik@sbi&pn=Ardh%20Sainik%20Canteen&am=1000.00&cu=INR');
  });

  it('is blocked when UPI is switched off or no UPI ID is set', async () => {
    await setting(db, 'upi', { enabled: false });
    expect((await err(() => upiOrder())).code).toBe('UPI_DISABLED');
    await setting(db, 'upi', { enabled: true, vpa: '' });
    expect((await err(() => upiOrder())).code).toBe('UPI_DISABLED');
  });

  it('rejects an invalid UPI ID in settings', async () => {
    await expect(setting(db, 'upi', { vpa: 'not a upi id' })).rejects.toThrow(/UPI ID/);
    await expect(setting(db, 'upi', { merchant_code: '12' })).rejects.toThrow(/4 digits/);
  });
});

describe('customer reports payment', () => {
  it('moves to "verifying", stops the expiry timer and keeps the order visible; customer can no longer cancel', async () => {
    const { orderId, u } = await upiOrder();
    await reportUpiPayment(ctx, orderId, u.id, UTR);
    const o = await getOrderDetail(db, orderId, u.id);
    expect(o).toMatchObject({ status: 'pending_payment', payment_status: 'verifying', payment_expires_at: null, can_cancel: false });
    expect(await upiPay(orderId)).toMatchObject({ status: 'pending', claimed_utr: UTR, provider_payment_id: null });
    expect(await expireUnpaidOrders(ctx)).toBe(0);
    expect((await getOrderDetail(db, orderId)).status).toBe('pending_payment');
    expect((await listUserOrders(db, u.id, 20)).map((x: any) => x.id)).toContain(orderId);
    expect((await err(() => transitionOrder(ctx, orderId, 'cancelled', { type: 'customer', id: u.id }, { reason: 'changed mind' }))).code).toBe('INVALID_TRANSITION');
  });

  it('an unreported order still expires and releases stock', async () => {
    const { orderId, p } = await upiOrder();
    await db.query(`UPDATE orders SET payment_expires_at = now() - interval '1 second' WHERE id=$1`, [orderId]);
    expect(await expireUnpaidOrders(ctx)).toBe(1);
    expect((await getOrderDetail(db, orderId)).status).toBe('cancelled');
    expect(await stockOf(p.id)).toMatchObject({ reserved_qty: 0 });
  });

  it('validates the UTR, the owner, the payment window and the unverified limit', async () => {
    const { orderId, u } = await upiOrder();
    expect((await err(() => reportUpiPayment(ctx, orderId, u.id, '12345'))).code).toBe('INVALID_UTR');
    const stranger = await mkUser(db);
    expect((await err(() => reportUpiPayment(ctx, orderId, stranger.id, UTR))).status).toBe(404);
    expect((await err(() => getUpiPaymentInfo(ctx, orderId, stranger.id))).status).toBe(404);
    await db.query(`UPDATE orders SET payment_expires_at = now() - interval '1 second' WHERE id=$1`, [orderId]);
    expect((await err(() => reportUpiPayment(ctx, orderId, u.id, UTR))).code).toBe('PAYMENT_EXPIRED');

    await setting(db, 'upi', { max_unverified_per_customer: 1 });
    const a = await upiOrder({ userId: u.id }); const b = await upiOrder({ userId: u.id });
    await reportUpiPayment(ctx, a.orderId, u.id, null);
    expect((await err(() => reportUpiPayment(ctx, b.orderId, u.id, null))).code).toBe('TOO_MANY_UNVERIFIED');
  });

  it('reporting again only fills in a missing UTR', async () => {
    const { orderId, u } = await upiOrder();
    await reportUpiPayment(ctx, orderId, u.id, null);
    await reportUpiPayment(ctx, orderId, u.id, UTR);
    await reportUpiPayment(ctx, orderId, u.id, '999999999999');
    expect((await upiPay(orderId)).claimed_utr).toBe(UTR);
  });
});

describe('staff confirmation', () => {
  it('wrong amount is refused and changes nothing', async () => {
    const { orderId, u } = await upiOrder(); const admin = await mkAdmin();
    await reportUpiPayment(ctx, orderId, u.id, UTR);
    expect((await err(() => confirmUpiPayment(ctx, orderId, admin, { amountPaise: 99900, utr: UTR }))).code).toBe('AMOUNT_MISMATCH');
    expect(await getOrderDetail(db, orderId)).toMatchObject({ status: 'pending_payment', payment_status: 'verifying' });
  });

  it('correct amount + UTR places the order, records who verified, notifies, audits; repeat is harmless', async () => {
    const { orderId, u, p } = await upiOrder(); const admin = await mkAdmin();
    await reportUpiPayment(ctx, orderId, u.id, UTR);
    expect(await confirmUpiPayment(ctx, orderId, admin, { amountPaise: 100000, utr: UTR })).toBe('paid');
    expect(await getOrderDetail(db, orderId)).toMatchObject({ status: 'placed', payment_status: 'paid', payment_expires_at: null });
    expect(await upiPay(orderId)).toMatchObject({ status: 'paid', provider_payment_id: UTR, verified_by: admin, is_primary: true });
    expect(await stockOf(p.id)).toMatchObject({ reserved_qty: 1 });
    expect((await db.query(`SELECT count(*)::int n FROM audit_logs WHERE action='payment.upi_confirmed' AND entity_id=$1`, [orderId])).rows[0].n).toBe(1);
    expect((await db.query(`SELECT title FROM notifications WHERE user_id=$1 ORDER BY created_at DESC LIMIT 1`, [u.id])).rows[0].title).toBe('Payment received');

    expect(await confirmUpiPayment(ctx, orderId, admin, { amountPaise: 100000, utr: UTR })).toBe('duplicate');
    expect((await err(() => confirmUpiPayment(ctx, orderId, admin, { amountPaise: 100000, utr: '512345678901' }))).code).toBe('ALREADY_CONFIRMED');
    expect((await db.query(`SELECT count(*)::int n FROM order_status_history WHERE order_id=$1 AND to_status='placed'`, [orderId])).rows[0].n).toBe(1);
  });

  it('staff can confirm a payment the customer never reported', async () => {
    const { orderId } = await upiOrder(); const admin = await mkAdmin();
    expect(await confirmUpiPayment(ctx, orderId, admin, { amountPaise: 100000, utr: UTR })).toBe('paid');
  });

  it('one bank UTR can settle only one order', async () => {
    const admin = await mkAdmin();
    const a = await upiOrder(); const b = await upiOrder();
    await confirmUpiPayment(ctx, a.orderId, admin, { amountPaise: 100000, utr: UTR });
    const e = await err(() => confirmUpiPayment(ctx, b.orderId, admin, { amountPaise: 100000, utr: UTR }));
    expect(e.code).toBe('UTR_ALREADY_USED');
    expect((await getOrderDetail(db, b.orderId)).status).toBe('pending_payment');
  });

  it('a different UTR than the customer typed needs an explicit override', async () => {
    const { orderId, u } = await upiOrder(); const admin = await mkAdmin();
    await reportUpiPayment(ctx, orderId, u.id, UTR);
    expect((await err(() => confirmUpiPayment(ctx, orderId, admin, { amountPaise: 100000, utr: '512345678901' }))).code).toBe('UTR_MISMATCH');
    expect(await confirmUpiPayment(ctx, orderId, admin, { amountPaise: 100000, utr: '512345678901', acceptUtrMismatch: true })).toBe('paid');
  });

  it('a customer UTR claim cannot block the real payer (claims are not unique)', async () => {
    const admin = await mkAdmin();
    const attacker = await upiOrder(); const real = await upiOrder();
    await reportUpiPayment(ctx, attacker.orderId, attacker.u.id, UTR);
    await reportUpiPayment(ctx, real.orderId, real.u.id, UTR);
    expect(await confirmUpiPayment(ctx, real.orderId, admin, { amountPaise: 100000, utr: UTR })).toBe('paid');
  });

  it('money confirmed after the order expired is queued as a manual refund, never sent to the gateway', async () => {
    const { orderId } = await upiOrder(); const admin = await mkAdmin();
    await db.query(`UPDATE orders SET payment_expires_at = now() - interval '1 second' WHERE id=$1`, [orderId]);
    await expireUnpaidOrders(ctx);
    expect(await confirmUpiPayment(ctx, orderId, admin, { amountPaise: 100000, utr: UTR })).toBe('late_refund');
    expect(await getOrderDetail(db, orderId)).toMatchObject({ status: 'refund_pending', payment_status: 'refund_pending' });
    const refund = (await db.query('SELECT * FROM refunds WHERE order_id=$1', [orderId])).rows[0];
    expect(refund.status).toBe('pending');
    await processPendingRefunds(ctx); // mock gateway: must not touch a UPI refund
    expect((await db.query('SELECT status, provider_refund_id FROM refunds WHERE id=$1', [refund.id])).rows[0]).toMatchObject({ status: 'pending', provider_refund_id: null });
    await recordManualRefund(ctx, orderId, refund.id, admin, 'UPI 612345678901');
    expect(await getOrderDetail(db, orderId)).toMatchObject({ status: 'refunded', payment_status: 'refunded' });
  });
});

describe('staff rejection and refunds', () => {
  it('reject cancels the order and returns stock and coins, with the reason shown to the customer', async () => {
    const u = await mkUser(db); await giveCoins(db, u.id, 100);
    const { orderId, p } = await upiOrder({ userId: u.id, coins: 50 }); const admin = await mkAdmin();
    expect((await db.query('SELECT balance FROM wallets WHERE user_id=$1', [u.id])).rows[0].balance).toBe(50);
    await reportUpiPayment(ctx, orderId, u.id, UTR);
    await rejectUpiPayment(ctx, orderId, admin, 'No credit of this amount in the bank');
    const o = await getOrderDetail(db, orderId, u.id);
    expect(o).toMatchObject({ status: 'cancelled', payment_status: 'failed' });
    expect(o.cancel_reason).toContain('No credit of this amount');
    expect(await stockOf(p.id)).toMatchObject({ reserved_qty: 0 });
    expect((await db.query('SELECT balance FROM wallets WHERE user_id=$1', [u.id])).rows[0].balance).toBe(100);
    expect((await upiPay(orderId)).status).toBe('failed');
  });

  it('a confirmed payment cannot be rejected', async () => {
    const { orderId } = await upiOrder(); const admin = await mkAdmin();
    await confirmUpiPayment(ctx, orderId, admin, { amountPaise: 100000, utr: UTR });
    expect((await err(() => rejectUpiPayment(ctx, orderId, admin, 'mistake'))).code).toBe('NOT_PENDING');
  });

  it('partial refund on a confirmed UPI order stays with staff until they record the reference', async () => {
    const { orderId } = await upiOrder(); const admin = await mkAdmin();
    await confirmUpiPayment(ctx, orderId, admin, { amountPaise: 100000, utr: UTR });
    await adminRefund(ctx, orderId, admin, '200', 'One item damaged');
    const refund = (await db.query('SELECT * FROM refunds WHERE order_id=$1', [orderId])).rows[0];
    expect(refund).toMatchObject({ status: 'pending', amount: '200.00' });

    await recordManualRefund(ctx, orderId, refund.id, admin, 'UPI 612345678901');
    await recordManualRefund(ctx, orderId, refund.id, admin, 'UPI 612345678901'); // idempotent
    expect((await db.query('SELECT status, processed_by FROM refunds WHERE id=$1', [refund.id])).rows[0]).toMatchObject({ status: 'processed', processed_by: admin });
    expect((await getOrderDetail(db, orderId)).payment_status).toBe('partially_refunded');

    await adminRefund(ctx, orderId, admin, '100', 'Second item');
    const second = (await db.query(`SELECT id FROM refunds WHERE order_id=$1 AND status='pending'`, [orderId])).rows[0];
    expect((await err(() => recordManualRefund(ctx, orderId, second.id, admin, 'UPI 612345678901'))).code).toBe('REFERENCE_ALREADY_USED');
    expect((await err(() => recordManualRefund(ctx, orderId, second.id, admin, '!'))).code).toBe('INVALID_REFERENCE');
  });
});

describe('PAYMENT_PROVIDER=none (launch without a gateway)', () => {
  const prodEnv = { NODE_ENV: 'production', DATABASE_URL: 'postgres://x/y', JWT_SECRET: 'j'.repeat(32), OTP_HMAC_SECRET: 'o'.repeat(32), OTP_PROVIDER: 'msg91', MSG91_AUTH_KEY: 'k', MSG91_TEMPLATE_ID: 't' };
  it('is allowed in production, while mock payments are still refused', () => {
    expect(createPaymentProvider(loadConfig({ ...prodEnv, PAYMENT_PROVIDER: 'none' } as any)).name).toBe('none');
    expect(() => loadConfig({ ...prodEnv, PAYMENT_PROVIDER: 'mock' } as any)).toThrow(/mock is not allowed/);
  });
  it('blocks gateway checkout but still allows UPI and COD', async () => {
    const noGateway = { ...ctx, payments: createPaymentProvider(loadConfig({ ...prodEnv, PAYMENT_PROVIDER: 'none' } as any)) };
    const u = await mkUser(db); const p = await mkProduct(db, { price: 1000, stock: 10 });
    const base = { items: [{ product_id: p.id, qty: 1 }], fulfilment: 'pickup' as const };
    expect((await err(() => createOrder(noGateway, u.id, { ...base, idempotency_key: randomUUID(), payment_method: 'online' }))).code).toBe('ONLINE_DISABLED');
    expect((await createOrder(noGateway, u.id, { ...base, idempotency_key: randomUUID(), payment_method: 'upi' })).replay).toBe(false);
    expect((await createOrder(noGateway, u.id, { ...base, idempotency_key: randomUUID(), payment_method: 'cod' })).replay).toBe(false);
  });
});

describe('UPI over HTTP', () => {
  const json = (r: { body: string }) => JSON.parse(r.body);
  async function customer(phone = '9876500011') {
    const a = await app.inject({ method: 'POST', url: '/v1/auth/otp/request', payload: { phone } });
    const b = await app.inject({ method: 'POST', url: '/v1/auth/otp/verify', payload: { phone, code: json(a).dev_code } });
    return { authorization: `Bearer ${json(b).access_token}` };
  }
  async function admin(role: 'owner' | 'staff') {
    const email = `${role}-${randomUUID().slice(0, 6)}@t.test`;
    await db.query(`INSERT INTO admin_users (email,name,password_hash,role) VALUES ($1,$2,$3,$4)`, [email, role, await hashPassword('correct-horse-9'), role]);
    const r = await app.inject({ method: 'POST', url: '/v1/admin/login', payload: { email, password: 'correct-horse-9' } });
    return { authorization: `Bearer ${json(r).token}` };
  }

  it('customer pays by UPI, staff confirms; only staff can confirm', async () => {
    const cfg = json(await app.inject({ method: 'GET', url: '/v1/config' }));
    expect(cfg.upi).toEqual({ enabled: true });
    const p = await mkProduct(db, { price: 1000, stock: 5 });
    const c = await customer();
    const placed = await app.inject({ method: 'POST', url: '/v1/orders', headers: { ...c, 'idempotency-key': randomUUID() }, payload: { items: [{ product_id: p.id, qty: 1 }], fulfilment: 'pickup', payment_method: 'upi' } });
    expect(placed.statusCode).toBe(201);
    const id = json(placed).order.id as string;

    const info = json(await app.inject({ method: 'GET', url: `/v1/orders/${id}/upi`, headers: c })).upi;
    expect(info.payable).toBe(true); expect(info.link).toMatch(/^upi:\/\/pay\?pa=ardhsainik@sbi/);

    expect((await app.inject({ method: 'POST', url: `/v1/orders/${id}/upi/report`, headers: c, payload: { utr: '123' } })).statusCode).toBe(400);
    const rep = await app.inject({ method: 'POST', url: `/v1/orders/${id}/upi/report`, headers: c, payload: { utr: UTR } });
    expect(rep.statusCode).toBe(200); expect(json(rep).order.payment_status).toBe('verifying');

    const confirmBody = { amount: '1000', utr: UTR };
    expect((await app.inject({ method: 'POST', url: `/v1/admin/orders/${id}/upi/confirm`, payload: confirmBody })).statusCode).toBe(401);
    expect((await app.inject({ method: 'POST', url: `/v1/admin/orders/${id}/upi/confirm`, headers: c, payload: confirmBody })).statusCode).toBe(401);

    const staff = await admin('staff');
    const list = json(await app.inject({ method: 'GET', url: '/v1/admin/orders?payment_status=verifying', headers: staff }));
    expect(list.items.map((o: any) => o.id)).toEqual([id]);
    const defaultList = json(await app.inject({ method: 'GET', url: '/v1/admin/orders', headers: staff }));
    expect(defaultList.items.map((o: any) => o.id)).toContain(id); // reported UPI orders are visible by default

    const ok = await app.inject({ method: 'POST', url: `/v1/admin/orders/${id}/upi/confirm`, headers: staff, payload: confirmBody });
    expect(ok.statusCode).toBe(200);
    expect(json(ok)).toMatchObject({ outcome: 'paid', order: { status: 'placed', payment_status: 'paid' } });

    // staff role has no refunds:write
    const refund = (await db.query('SELECT id FROM refunds LIMIT 1')).rows[0];
    expect(refund).toBeUndefined();
    const staffRefund = await app.inject({ method: 'POST', url: `/v1/admin/orders/${id}/refund`, headers: staff, payload: { amount: '100', reason: 'test' } });
    expect(staffRefund.statusCode).toBe(403);
  });
});
