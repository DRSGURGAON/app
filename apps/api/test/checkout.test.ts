import { describe, it, expect, beforeAll, afterAll, beforeEach } from 'vitest';
import { randomUUID } from 'node:crypto';
import { makeCtx, reset, setting, mkProduct, mkUser, mkAddress, mkZone, mkCoupon, openStore, giveCoins } from './helpers.js';
import { createOrder, transitionOrder, getOrderDetail, expireUnpaidOrders, type CheckoutInput } from '../src/services/orders.js';
import { AppError } from '../src/lib/errors.js';
import { getBalance } from '../src/services/coins.js';

const ctx = makeCtx();
const db = ctx.db;
afterAll(async () => { await db.end(); });
beforeEach(async () => { await reset(db); await openStore(db); await setting(db, 'delivery', { base_fee: 25, far_fee: 70, fallback_mode: 'ask_zone' }); });

async function setup(price = 1000, stock = 10) {
  const u = await mkUser(db); const zone = await mkZone(db, 'Loharu Town', 'base'); const a = await mkAddress(db, u.id, { zone: zone.id });
  const p = await mkProduct(db, { price, stock });
  return { u, a, p, zone };
}
const input = (p: any, a: any, over: Partial<CheckoutInput> = {}): CheckoutInput => ({
  idempotency_key: randomUUID(), items: [{ product_id: p.id, qty: 1 }], fulfilment: 'delivery', address_id: a?.id, payment_method: 'cod', ...over });
const product = async (id: string) => (await db.query('SELECT stock_qty, reserved_qty FROM products WHERE id=$1', [id])).rows[0];
const err = async (fn: () => Promise<unknown>) => { try { await fn(); } catch (e) { return e as AppError; } throw new Error('expected an error'); };
const admin = { type: 'admin' as const, id: null };

describe('placing a COD order', () => {
  it('creates the order with server-computed totals, snapshots, and reserves stock', async () => {
    const { u, a, p } = await setup(1000, 10);
    const r = await createOrder(ctx, u.id, input(p, a, { payment_method: 'cod' }));
    const o = await getOrderDetail(db, r.orderId, u.id);
    expect(o).toMatchObject({ status: 'placed', payment_status: 'cod_pending', fulfilment_type: 'delivery' });
    expect(o.order_no).toMatch(/^ASM\d{6}-00001$/);
    expect(o.totals).toMatchObject({ subtotal: '1000.00', delivery_fee: '25.00', total: '1025.00' });
    expect(o.delivery).toMatchObject({ method: 'zone', zone: 'Loharu Town', rule: 'zone_base' });
    expect(o.items[0]).toMatchObject({ sku: expect.any(String), name: p.name, unit_price: '1000.00', qty: 1 });
    expect(await product(p.id)).toEqual({ stock_qty: 10, reserved_qty: 1 });
    expect(o.history.map((h: any) => h.to_status)).toEqual(['placed']);
    expect((await db.query('SELECT count(*)::int n FROM notifications WHERE user_id=$1', [u.id])).rows[0].n).toBe(1);
  });
  it('order items keep their price snapshot when the catalogue price changes later', async () => {
    const { u, a, p } = await setup();
    const r = await createOrder(ctx, u.id, input(p, a));
    await db.query('UPDATE products SET price=1, mrp=1, name=$2 WHERE id=$1', [p.id, 'Renamed']);
    const o = await getOrderDetail(db, r.orderId, u.id);
    expect(o.items[0]).toMatchObject({ unit_price: '1000.00', name: p.name }); expect(o.totals.total).toBe('1025.00');
  });
  it('pickup: zero delivery fee, no address needed', async () => {
    const { u, p } = await setup(1000, 5);
    const r = await createOrder(ctx, u.id, input(p, null, { fulfilment: 'pickup' }));
    const o = await getOrderDetail(db, r.orderId, u.id);
    expect(o.totals.delivery_fee).toBe('0.00'); expect(o.totals.total).toBe('1000.00'); expect(o.address).toBeNull();
  });
  it('rejects a cart below the minimum on the server, reserving nothing', async () => {
    const { u, a, p } = await setup(998, 5);
    const e = await err(() => createOrder(ctx, u.id, input(p, a)));
    expect(e.code).toBe('MIN_ORDER_NOT_MET'); expect(await product(p.id)).toEqual({ stock_qty: 5, reserved_qty: 0 });
    expect((await db.query('SELECT count(*)::int n FROM orders')).rows[0].n).toBe(0);
  });
  it('rejects delivery without an address and an unsupported distance without a zone', async () => {
    const { u, p } = await setup();
    expect((await err(() => createOrder(ctx, u.id, input(p, null)))).code).toBe('ADDRESS_REQUIRED');
    const a2 = await mkAddress(db, u.id, { pincode: '999999' });
    expect((await err(() => createOrder(ctx, u.id, input(p, a2)))).code).toBe('DELIVERY_ZONE_REQUIRED');
  });
  it("another customer's address cannot be used", async () => {
    const { p } = await setup(); const other = await mkUser(db); const theirs = await mkAddress(db, other.id);
    const u = await mkUser(db);
    expect((await err(() => createOrder(ctx, u.id, input(p, theirs)))).status).toBe(404);
  });
  it('PRICE_CHANGED when the total the customer saw is no longer right', async () => {
    const { u, a, p } = await setup();
    const e = await err(() => createOrder(ctx, u.id, input(p, a, { expected_total: '1000.00' }))); // forgot the fee
    expect(e.code).toBe('PRICE_CHANGED'); expect((e.details as any).quote.totals.total).toBe('1025.00');
    expect((await db.query('SELECT count(*)::int n FROM orders')).rows[0].n).toBe(0);
    await createOrder(ctx, u.id, input(p, a, { expected_total: '1025.00' }));
  });
  it('blocked while the store is closed', async () => {
    const { u, a, p } = await setup(); await setting(db, 'store', { temporarily_closed: true });
    expect((await err(() => createOrder(ctx, u.id, input(p, a)))).code).toBe('STORE_CLOSED');
  });
});

describe('duplicate submission & concurrency', () => {
  it('same Idempotency-Key returns the original order (no second order, no second reservation)', async () => {
    const { u, a, p } = await setup(); const body = input(p, a);
    const r1 = await createOrder(ctx, u.id, body); const r2 = await createOrder(ctx, u.id, body);
    expect(r2).toMatchObject({ orderId: r1.orderId, replay: true });
    expect((await db.query('SELECT count(*)::int n FROM orders')).rows[0].n).toBe(1); expect((await product(p.id)).reserved_qty).toBe(1);
  });
  it('5 simultaneous taps with the same key create exactly one order', async () => {
    const { u, a, p } = await setup(); const body = input(p, a);
    const res = await Promise.all(Array.from({ length: 5 }, () => createOrder(ctx, u.id, body)));
    expect(new Set(res.map((r) => r.orderId)).size).toBe(1);
    expect((await db.query('SELECT count(*)::int n FROM orders')).rows[0].n).toBe(1); expect((await product(p.id)).reserved_qty).toBe(1);
  });
  it('never oversells: 12 customers race for 3 units -> exactly 3 orders succeed', async () => {
    const zone = await mkZone(db, 'Z', 'base'); const p = await mkProduct(db, { price: 1000, stock: 3 });
    const users = await Promise.all(Array.from({ length: 12 }, () => mkUser(db)));
    const addrs = await Promise.all(users.map((u) => mkAddress(db, u.id, { zone: zone.id })));
    const results = await Promise.allSettled(users.map((u, i) => createOrder(ctx, u.id, input(p, addrs[i]))));
    const ok = results.filter((r) => r.status === 'fulfilled'); const bad = results.filter((r) => r.status === 'rejected') as PromiseRejectedResult[];
    expect(ok).toHaveLength(3); expect(bad).toHaveLength(9);
    expect(bad.every((b) => ['OUT_OF_STOCK', 'STOCK_INSUFFICIENT', 'INSUFFICIENT_STOCK'].includes(b.reason.code))).toBe(true);
    expect(await product(p.id)).toEqual({ stock_qty: 3, reserved_qty: 3 });
  });
  it('multi-item carts reserve in a consistent order (no deadlocks) under contention', async () => {
    const zone = await mkZone(db, 'Z', 'base'); const a1 = await mkProduct(db, { price: 600, stock: 50 }); const b1 = await mkProduct(db, { price: 600, stock: 50 });
    const users = await Promise.all(Array.from({ length: 10 }, () => mkUser(db))); const addrs = await Promise.all(users.map((u) => mkAddress(db, u.id, { zone: zone.id })));
    const res = await Promise.allSettled(users.map((u, i) => createOrder(ctx, u.id, input(a1, addrs[i], { items: i % 2 ? [{ product_id: a1.id, qty: 1 }, { product_id: b1.id, qty: 1 }] : [{ product_id: b1.id, qty: 1 }, { product_id: a1.id, qty: 1 }] }))));
    expect(res.every((r) => r.status === 'fulfilled')).toBe(true);
    expect((await product(a1.id)).reserved_qty).toBe(10); expect((await product(b1.id)).reserved_qty).toBe(10);
  });
  it('coupon usage limit holds under concurrency (limit 2, 6 customers)', async () => {
    const zone = await mkZone(db, 'Z', 'base'); const p = await mkProduct(db, { price: 1000, stock: 50 });
    await mkCoupon(db, { code: 'TWO', type: 'fixed', value: 50, limit: 2 });
    const users = await Promise.all(Array.from({ length: 6 }, () => mkUser(db))); const addrs = await Promise.all(users.map((u) => mkAddress(db, u.id, { zone: zone.id })));
    const res = await Promise.allSettled(users.map((u, i) => createOrder(ctx, u.id, input(p, addrs[i], { coupon_code: 'TWO' }))));
    expect(res.filter((r) => r.status === 'fulfilled')).toHaveLength(2);
    expect((await db.query(`SELECT used_count FROM coupons WHERE code='TWO'`)).rows[0].used_count).toBe(2);
    expect(((res.find((r) => r.status === 'rejected') as PromiseRejectedResult).reason as AppError).code).toBe('COUPON_LIMIT_REACHED');
  });
  it('per-customer coupon limit (1): same customer cannot reuse it', async () => {
    const { u, a, p } = await setup(1000, 50); await mkCoupon(db, { code: 'ONCE', type: 'fixed', value: 50, perUser: 1 });
    await createOrder(ctx, u.id, input(p, a, { coupon_code: 'ONCE' }));
    expect((await err(() => createOrder(ctx, u.id, input(p, a, { coupon_code: 'ONCE' })))).code).toBe('COUPON_USER_LIMIT');
  });
});

describe('first-order discount', () => {
  it('only one live order can carry it, even with two simultaneous checkouts', async () => {
    await setting(db, 'first_order', { enabled: true, type: 'fixed', value: 100, min_spend: 0, max_discount: null });
    const { u, a, p } = await setup(1000, 50);
    const [r1, r2] = await Promise.all([createOrder(ctx, u.id, input(p, a)), createOrder(ctx, u.id, input(p, a))]);
    const orders = (await db.query('SELECT first_order_discount FROM orders WHERE user_id=$1', [u.id])).rows.map((r) => r.first_order_discount).sort();
    expect(r1.orderId).not.toBe(r2.orderId); expect(orders).toEqual(['0.00', '100.00']);
  });
  it('database index rejects a second discounted live order even if code were bypassed', async () => {
    const { u, a, p } = await setup(1000, 50);
    await setting(db, 'first_order', { enabled: true, type: 'fixed', value: 100, min_spend: 0, max_discount: null });
    const r = await createOrder(ctx, u.id, input(p, a));
    await expect(db.query(`INSERT INTO orders (order_no,user_id,idempotency_key,status,fulfilment_type,payment_method,payment_status,customer_phone,mrp_total,subtotal,first_order_discount,total,min_order_value,pricing_snapshot)
      VALUES ('X1',$1,'k2','placed','pickup','cod','cod_pending','9999999999',1,1,5,1,1,'{}')`, [u.id])).rejects.toThrow(/orders_one_first_order_discount/);
    // after cancelling, the customer gets the discount again
    await transitionOrder(ctx, r.orderId, 'cancelled', { type: 'customer', id: u.id }, { reason: 'Changed my mind' });
    const r3 = await createOrder(ctx, u.id, input(p, a)); expect((await getOrderDetail(db, r3.orderId)).totals.first_order_discount).toBe('100.00');
  });
});

describe('order lifecycle (delivery)', () => {
  it('walks the full flow, rejects skipping steps, fulfils stock and credits coins exactly once', async () => {
    const { u, a, p } = await setup(1000, 10);
    const r = await createOrder(ctx, u.id, input(p, a, { items: [{ product_id: p.id, qty: 2 }] })); // 2000 -> will earn 20 coins
    const id = r.orderId;
    expect((await err(() => transitionOrder(ctx, id, 'delivered', admin))).code).toBe('INVALID_TRANSITION');
    for (const s of ['accepted', 'packing', 'ready_for_dispatch', 'out_for_delivery'] as const) await transitionOrder(ctx, id, s, admin);
    expect(await product(p.id)).toEqual({ stock_qty: 10, reserved_qty: 2 }); // nothing leaves stock until handed over
    expect(await getBalance(db, u.id)).toBe(0);
    await transitionOrder(ctx, id, 'delivered', admin);
    expect(await product(p.id)).toEqual({ stock_qty: 8, reserved_qty: 0 });
    expect(await getBalance(db, u.id)).toBe(20);
    const o = await getOrderDetail(db, id);
    expect(o).toMatchObject({ status: 'delivered', payment_status: 'cod_collected' }); expect(o.coins.credited).toBe(true);
    expect(o.history.map((h: any) => h.to_status)).toEqual(['placed', 'accepted', 'packing', 'ready_for_dispatch', 'out_for_delivery', 'delivered']);
    // replaying the terminal transition is rejected, so coins can never be credited twice
    expect((await err(() => transitionOrder(ctx, id, 'delivered', admin))).code).toBe('INVALID_TRANSITION');
    expect(await getBalance(db, u.id)).toBe(20);
    const mv = await db.query('SELECT type, qty_delta, reserved_delta FROM stock_movements WHERE product_id=$1 ORDER BY id', [p.id]);
    expect(mv.rows.map((m) => m.type)).toEqual(['reserve', 'fulfil']);
  });
  it('pickup flow ends at collected and uses ready_for_pickup', async () => {
    const { u, p } = await setup(1000, 10); const r = await createOrder(ctx, u.id, input(p, null, { fulfilment: 'pickup' }));
    expect((await err(() => transitionOrder(ctx, r.orderId, 'out_for_delivery', admin))).code).toBe('INVALID_TRANSITION');
    for (const s of ['accepted', 'packing', 'ready_for_pickup', 'collected'] as const) await transitionOrder(ctx, r.orderId, s, admin);
    expect((await getOrderDetail(db, r.orderId)).status).toBe('collected'); expect(await getBalance(db, u.id)).toBe(10);
  });
  it('admin rejection and cancellation need a reason', async () => {
    const { u, a, p } = await setup(); const r = await createOrder(ctx, u.id, input(p, a));
    expect((await err(() => transitionOrder(ctx, r.orderId, 'rejected', admin, {}))).code).toBe('REASON_REQUIRED');
    await transitionOrder(ctx, r.orderId, 'rejected', admin, { reason: 'Item damaged' });
    const o = await getOrderDetail(db, r.orderId); expect(o).toMatchObject({ status: 'rejected', cancel_reason: 'Item damaged' });
  });
});

describe('cancellation unwinds everything', () => {
  it('customer cancel (placed): stock released, coins returned, coupon released', async () => {
    const { u, a, p } = await setup(1000, 10); await giveCoins(db, u.id, 40); await mkCoupon(db, { code: 'C100', type: 'fixed', value: 100, limit: 1 });
    const r = await createOrder(ctx, u.id, input(p, a, { coupon_code: 'C100', use_coins: 30 }));
    const o1 = await getOrderDetail(db, r.orderId); expect(o1.totals).toMatchObject({ coupon_discount: '100.00', coin_discount: '30.00', total: '895.00' });
    expect(await getBalance(db, u.id)).toBe(10); expect((await product(p.id)).reserved_qty).toBe(1);
    await transitionOrder(ctx, r.orderId, 'cancelled', { type: 'customer', id: u.id }, { reason: 'Ordered by mistake' });
    expect(await getBalance(db, u.id)).toBe(40); expect(await product(p.id)).toEqual({ stock_qty: 10, reserved_qty: 0 });
    expect((await db.query(`SELECT used_count FROM coupons WHERE code='C100'`)).rows[0].used_count).toBe(0);
    expect((await db.query(`SELECT status FROM coupon_redemptions`)).rows[0].status).toBe('released');
    const o = await getOrderDetail(db, r.orderId); expect(o.status).toBe('cancelled');
    // another customer can now use the (limit 1) coupon
    const other = await mkUser(db); const a2 = await mkAddress(db, other.id, { zone: (await db.query('SELECT id FROM delivery_zones LIMIT 1')).rows[0].id });
    await createOrder(ctx, other.id, input(p, a2, { coupon_code: 'C100' }));
  });
  it('a customer cannot cancel once the store accepted the order, nor cancel someone else’s', async () => {
    const { u, a, p } = await setup(); const r = await createOrder(ctx, u.id, input(p, a));
    const stranger = await mkUser(db);
    expect((await err(() => transitionOrder(ctx, r.orderId, 'cancelled', { type: 'customer', id: stranger.id }, { reason: 'nope nope' }))).status).toBe(404);
    await transitionOrder(ctx, r.orderId, 'accepted', admin);
    expect((await err(() => transitionOrder(ctx, r.orderId, 'cancelled', { type: 'customer', id: u.id }, { reason: 'too late' }))).code).toBe('INVALID_TRANSITION');
    await transitionOrder(ctx, r.orderId, 'cancelled', admin, { reason: 'Customer called to cancel' }); // admin still can
  });
  it('coins redeemed are spent immediately (cannot double spend across two orders)', async () => {
    const { u, a, p } = await setup(1000, 50); await giveCoins(db, u.id, 50);
    await createOrder(ctx, u.id, input(p, a, { use_coins: 50 }));
    const r2 = await createOrder(ctx, u.id, input(p, a, { use_coins: 50 }));
    expect((await getOrderDetail(db, r2.orderId)).totals.coin_discount).toBe('0.00'); expect(await getBalance(db, u.id)).toBe(0);
  });
  it('coin credit is idempotent by reference even if the transition code ran twice', async () => {
    const { u, a, p } = await setup(1000, 10); const r = await createOrder(ctx, u.id, input(p, a));
    for (const s of ['accepted', 'packing', 'ready_for_dispatch', 'out_for_delivery', 'delivered'] as const) await transitionOrder(ctx, r.orderId, s, admin);
    const { postLedger } = await import('../src/services/coins.js'); const c = await db.connect();
    try { await c.query('BEGIN'); const again = await postLedger(c, { userId: u.id, type: 'earn', coins: 10, ref: `order:${r.orderId}:earn` }); await c.query('COMMIT'); expect(again.duplicate).toBe(true); } finally { c.release(); }
    expect(await getBalance(db, u.id)).toBe(10);
  });
});

describe('online orders awaiting payment', () => {
  it('unpaid online orders expire, releasing stock', async () => {
    const { u, a, p } = await setup(1000, 10); const r = await createOrder(ctx, u.id, input(p, a, { payment_method: 'online' }));
    const o = await getOrderDetail(db, r.orderId); expect(o).toMatchObject({ status: 'pending_payment', payment_status: 'pending' });
    expect(await expireUnpaidOrders(ctx)).toBe(0); // window still open
    await db.query(`UPDATE orders SET payment_expires_at = now() - interval '1 minute'`);
    expect(await expireUnpaidOrders(ctx)).toBe(1);
    expect(await getOrderDetail(db, r.orderId)).toMatchObject({ status: 'cancelled', payment_status: 'failed' });
    expect(await product(p.id)).toEqual({ stock_qty: 10, reserved_qty: 0 });
  });
});
