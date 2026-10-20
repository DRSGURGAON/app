import { describe, it, expect, beforeAll, afterAll, beforeEach } from 'vitest';
import { makeCtx, reset, setting, mkProduct, mkUser, mkAddress, mkZone, mkCoupon, mkCategory, openStore, giveCoins } from './helpers.js';
import { buildQuote } from '../src/services/pricing.js';
import { loadSettings } from '../src/services/settings.js';
import type { RoutingProvider } from '../src/services/delivery.js';

const ctx = makeCtx();
const db = ctx.db;
beforeAll(async () => { await reset(db); });
afterAll(async () => { await db.end(); });
beforeEach(async () => { await reset(db); await openStore(db); await setting(db, 'delivery', { base_fee: 25, far_fee: 70 }); });

async function quote(req: any, userId: string | null = null, routing: RoutingProvider | null = null) {
  const settings = await loadSettings(db);
  return (await buildQuote({ fulfilment: 'pickup', ...req }, { q: db, userId, settings, routing })).quote;
}

describe('minimum order (Rs 999 default)', () => {
  it('blocks below 999 and reports exact shortfall', async () => {
    const p = await mkProduct(db, { price: 998 });
    const q = await quote({ items: [{ product_id: p.id, qty: 1 }] });
    expect(q.min_order).toMatchObject({ required: '999.00', current: '998.00', shortfall: '1.00', met: false });
    expect(q.can_checkout).toBe(false);
    expect(q.blockers.map((b) => b.code)).toContain('MIN_ORDER_NOT_MET');
  });
  it('accepts exactly 999 (inclusive)', async () => {
    const p = await mkProduct(db, { price: 999 });
    const q = await quote({ items: [{ product_id: p.id, qty: 1 }] });
    expect(q.min_order.met).toBe(true); expect(q.can_checkout).toBe(true);
  });
  it('is measured on merchandise BEFORE delivery fee (fee never helps meet the minimum)', async () => {
    const p = await mkProduct(db, { price: 950 });
    const u = await mkUser(db); const a = await mkAddress(db, u.id, { lat: 28.401, lng: 75.801 });
    const settings = await loadSettings(db);
    const r = await buildQuote({ items: [{ product_id: p.id, qty: 1 }], fulfilment: 'delivery', address: { latitude: 28.401, longitude: 75.801, zone_id: null, pincode: a.pincode } },
      { q: db, userId: u.id, settings: { ...settings, delivery: { ...settings.delivery, fallback_mode: 'straight_line' } }, routing: null });
    expect(r.quote.delivery.fee).toBe('25.00');
    expect(r.quote.min_order.met).toBe(false);
  });
  it('default: coupon/coins do not reduce the minimum-order basis; configurable', async () => {
    const u = await mkUser(db); const p = await mkProduct(db, { price: 1000 });
    await mkCoupon(db, { code: 'FLAT100', type: 'fixed', value: 100 });
    let q = await quote({ items: [{ product_id: p.id, qty: 1 }], coupon_code: 'FLAT100' }, u.id);
    expect(q.totals.coupon_discount).toBe('100.00'); expect(q.min_order.met).toBe(true); expect(q.min_order.current).toBe('1000.00');
    await setting(db, 'order', { min_after_coupon: true });
    q = await quote({ items: [{ product_id: p.id, qty: 1 }], coupon_code: 'FLAT100' }, u.id);
    expect(q.min_order.current).toBe('900.00'); expect(q.min_order.met).toBe(false);
  });
  it('pickup can be exempted from the minimum', async () => {
    const p = await mkProduct(db, { price: 100 });
    await setting(db, 'order', { min_applies_to_pickup: false });
    const q = await quote({ items: [{ product_id: p.id, qty: 1 }] });
    expect(q.min_order.met).toBe(true);
  });
  it('zone-specific minimum applies only when overrides are enabled', async () => {
    const z = await mkZone(db, 'Far village', 'far', ['127310'], { min_order: '1500' });
    const p = await mkProduct(db, { price: 1000 });
    const u = await mkUser(db);
    const addr = { latitude: null, longitude: null, zone_id: z.id, pincode: '127310' };
    let q = await quote({ items: [{ product_id: p.id, qty: 1 }], fulfilment: 'delivery', address: addr }, u.id);
    expect(q.min_order.required).toBe('999.00');
    await setting(db, 'delivery', { zone_overrides_enabled: true });
    q = await quote({ items: [{ product_id: p.id, qty: 1 }], fulfilment: 'delivery', address: addr }, u.id);
    expect(q.min_order.required).toBe('1500.00'); expect(q.delivery.fee).toBe('70.00'); expect(q.can_checkout).toBe(false);
  });
});

describe('delivery inside the quote', () => {
  const road = (m: number): RoutingProvider => ({ method: 'road_osrm', roadDistanceMeters: async () => m });
  const addr = { latitude: 28.41, longitude: 75.81, zone_id: null, pincode: '127308' };
  it('1 km -> admin base fee; exactly 2 km -> base; 2.01 km -> flat 70', async () => {
    const p = await mkProduct(db, { price: 1000 });
    const items = [{ product_id: p.id, qty: 1 }];
    expect((await quote({ items, fulfilment: 'delivery', address: addr }, null, road(1000))).delivery.fee).toBe('25.00');
    expect((await quote({ items, fulfilment: 'delivery', address: addr }, null, road(2000))).delivery.fee).toBe('25.00');
    const far = await quote({ items, fulfilment: 'delivery', address: addr }, null, road(2010));
    expect(far.delivery).toMatchObject({ fee: '70.00', rule: 'far_fixed', distance_km: 2.01, method: 'road_osrm' });
    expect(far.totals.total).toBe('1070.00');
  });
  it('pickup is always 0.00 even with an address supplied', async () => {
    const p = await mkProduct(db, { price: 1000 });
    const q = await quote({ items: [{ product_id: p.id, qty: 1 }], fulfilment: 'pickup', address: addr }, null, road(9000));
    expect(q.delivery.fee).toBe('0.00'); expect(q.totals.total).toBe('1000.00');
  });
  it('missing coordinates -> asks for a zone and lists them; chosen zone prices it', async () => {
    const z = await mkZone(db, 'Loharu Town', 'base'); await mkZone(db, 'Villages', 'far', ['127999']);
    const p = await mkProduct(db, { price: 1000 }); const items = [{ product_id: p.id, qty: 1 }];
    const noZone = await quote({ items, fulfilment: 'delivery', address: { latitude: null, longitude: null, zone_id: null, pincode: '000000' } }, null, road(1));
    expect(noZone.delivery.error?.code).toBe('DELIVERY_ZONE_REQUIRED'); expect(noZone.delivery.zones_to_choose).toHaveLength(2);
    expect(noZone.can_checkout).toBe(false); expect(noZone.totals.total).toBeNull();
    const withZone = await quote({ items, fulfilment: 'delivery', address: { latitude: null, longitude: null, zone_id: z.id, pincode: null } });
    expect(withZone.delivery).toMatchObject({ fee: '25.00', method: 'zone' }); expect(withZone.can_checkout).toBe(true);
  });
  it('routing service failure never silently produces a fee', async () => {
    const p = await mkProduct(db, { price: 1000 });
    const failing: RoutingProvider = { method: 'road_osrm', roadDistanceMeters: async () => { throw new Error('down'); } };
    const q = await quote({ items: [{ product_id: p.id, qty: 1 }], fulfilment: 'delivery', address: addr }, null, failing);
    expect(q.delivery.fee).toBeNull(); expect(q.delivery.error?.code).toBe('DELIVERY_ZONE_REQUIRED'); expect(q.can_checkout).toBe(false);
  });
  it('store coordinates not configured -> zone required', async () => {
    await setting(db, 'store', { latitude: null, longitude: null });
    const p = await mkProduct(db, { price: 1000 });
    const q = await quote({ items: [{ product_id: p.id, qty: 1 }], fulfilment: 'delivery', address: addr }, null, road(500));
    expect(q.delivery.error?.code).toBe('DELIVERY_ZONE_REQUIRED');
  });
  it('delivery without an address reports ADDRESS_REQUIRED, fee pending', async () => {
    const p = await mkProduct(db, { price: 1000 });
    const q = await quote({ items: [{ product_id: p.id, qty: 1 }], fulfilment: 'delivery' });
    expect(q.delivery.pending).toBe(true); expect(q.blockers.map((b) => b.code)).toContain('ADDRESS_REQUIRED');
  });
});

describe('stock & price validation', () => {
  it('flags out of stock / insufficient / inactive / max-per-order', async () => {
    const low = await mkProduct(db, { price: 1000, stock: 2 }); const none = await mkProduct(db, { price: 1000, stock: 0 });
    const off = await mkProduct(db, { price: 1000, active: false }); const cap = await mkProduct(db, { price: 1000, max: 2 });
    const q = await quote({ items: [{ product_id: low.id, qty: 3 }, { product_id: none.id, qty: 1 }, { product_id: off.id, qty: 1 }, { product_id: cap.id, qty: 3 }] });
    const codes = q.blockers.map((b) => b.code).sort();
    expect(codes).toEqual(expect.arrayContaining(['INSUFFICIENT_STOCK', 'OUT_OF_STOCK', 'PRODUCT_UNAVAILABLE', 'MAX_QTY']));
    expect(q.can_checkout).toBe(false);
    expect(q.lines.find((l) => l.product_id === low.id)!.available).toBe(2);
  });
  it('uses server prices, merges duplicate lines, reports real savings from MRP only', async () => {
    const p = await mkProduct(db, { price: 90, mrp: 100 }); const same = await mkProduct(db, { price: 500, mrp: 500 });
    const q = await quote({ items: [{ product_id: p.id, qty: 5 }, { product_id: p.id, qty: 6 }, { product_id: same.id, qty: 1 }] });
    expect(q.lines).toHaveLength(2);
    expect(q.totals).toMatchObject({ subtotal: '1490.00', mrp_total: '1600.00', savings: '110.00' });
  });
  it('tax is the GST contained in the (tax-inclusive) price, on discounted amounts', async () => {
    const p = await mkProduct(db, { price: 1180, tax: 18 });
    const q = await quote({ items: [{ product_id: p.id, qty: 1 }] });
    expect(q.totals.tax_included).toBe('180.00'); expect(q.totals.total).toBe('1180.00');
  });
});

describe('coupons', () => {
  it('percent with max cap, fixed, and min spend', async () => {
    const u = await mkUser(db); const p = await mkProduct(db, { price: 2000 }); const items = [{ product_id: p.id, qty: 1 }];
    await mkCoupon(db, { code: 'P20', type: 'percent', value: 20, max: 150 }); await mkCoupon(db, { code: 'MIN3K', type: 'fixed', value: 100, min: 3000 });
    expect((await quote({ items, coupon_code: 'p20' }, u.id)).totals.coupon_discount).toBe('150.00'); // case-insensitive + capped
    const q = await quote({ items, coupon_code: 'MIN3K' }, u.id);
    expect(q.coupon?.applied).toBe(false); expect(q.coupon?.error?.code).toBe('COUPON_MIN_SPEND'); expect(q.totals.coupon_discount).toBe('0.00');
  });
  it('rejects unknown, expired, not-started, inactive, and guest use', async () => {
    const u = await mkUser(db); const p = await mkProduct(db, { price: 1000 }); const items = [{ product_id: p.id, qty: 1 }];
    await mkCoupon(db, { code: 'OLD', end: '2021-01-01', start: '2020-01-01' }); await mkCoupon(db, { code: 'SOON', start: '2098-01-01', end: '2099-01-01' }); await mkCoupon(db, { code: 'OFF', active: false });
    const code = async (c: string, uid: string | null = u.id) => (await quote({ items, coupon_code: c }, uid)).coupon?.error?.code;
    expect(await code('NOPE')).toBe('COUPON_NOT_FOUND'); expect(await code('OLD')).toBe('COUPON_EXPIRED'); expect(await code('SOON')).toBe('COUPON_NOT_STARTED');
    expect(await code('OFF')).toBe('COUPON_INACTIVE'); expect(await code('OLD', null)).toBe('COUPON_EXPIRED');
    await mkCoupon(db, { code: 'GUEST' }); expect(await code('GUEST', null)).toBe('LOGIN_REQUIRED');
  });
  it('category/product targeting and offers_eligible=false exclusions', async () => {
    const u = await mkUser(db); const catA = await mkCategory(db, 'A'); const catB = await mkCategory(db, 'B');
    const a = await mkProduct(db, { category: catA.id, price: 1000 }); const b = await mkProduct(db, { category: catB.id, price: 1000 }); const x = await mkProduct(db, { category: catA.id, price: 1000, offers: false });
    await mkCoupon(db, { code: 'ONLYA', type: 'percent', value: 10, cats: [catA.id] });
    const q = await quote({ items: [{ product_id: a.id, qty: 1 }, { product_id: b.id, qty: 1 }, { product_id: x.id, qty: 1 }], coupon_code: 'ONLYA' }, u.id);
    expect(q.totals.coupon_discount).toBe('100.00'); // 10% of A only (x excluded by flag, b by category)
    const q2 = await quote({ items: [{ product_id: b.id, qty: 1 }], coupon_code: 'ONLYA' }, u.id);
    expect(q2.coupon?.error?.code).toBe('COUPON_NOT_ELIGIBLE_ITEMS');
  });
});

describe('first-order discount', () => {
  it('is off until the owner enables it; never invented', async () => {
    const u = await mkUser(db); const p = await mkProduct(db, { price: 1000 });
    const q = await quote({ items: [{ product_id: p.id, qty: 1 }] }, u.id);
    expect(q.first_order.enabled).toBe(false); expect(q.totals.first_order_discount).toBe('0.00');
  });
  it('applies for a new customer within rules; guests and returning customers get none', async () => {
    await setting(db, 'first_order', { enabled: true, type: 'percent', value: 10, min_spend: 999, max_discount: 80 });
    const u = await mkUser(db); const p = await mkProduct(db, { price: 1000 }); const items = [{ product_id: p.id, qty: 1 }];
    expect((await quote({ items }, u.id)).totals.first_order_discount).toBe('80.00');   // 10% = 100, capped at 80
    expect((await quote({ items }, null)).totals.first_order_discount).toBe('0.00');   // guest
    const cheap = await mkProduct(db, { price: 500 });
    expect((await quote({ items: [{ product_id: cheap.id, qty: 1 }] }, u.id)).first_order.note).toMatch(/Spend/);
  });
  it('an explicit coupon replaces (never stacks with) the first-order discount', async () => {
    await setting(db, 'first_order', { enabled: true, type: 'fixed', value: 50, min_spend: 0, max_discount: null });
    await mkCoupon(db, { code: 'FLAT100', type: 'fixed', value: 100 });
    const u = await mkUser(db); const p = await mkProduct(db, { price: 1000 });
    const q = await quote({ items: [{ product_id: p.id, qty: 1 }], coupon_code: 'FLAT100' }, u.id);
    expect(q.totals.coupon_discount).toBe('100.00'); expect(q.totals.first_order_discount).toBe('0.00'); expect(q.first_order.note).toMatch(/instead/);
  });
});

describe('coins in the quote', () => {
  it('redemption is clamped by balance, per-order cap, and keeps Rs 1 payable', async () => {
    const u = await mkUser(db); const p = await mkProduct(db, { price: 1000 }); const items = [{ product_id: p.id, qty: 1 }];
    await giveCoins(db, u.id, 30);
    let q = await quote({ items, use_coins: 500 }, u.id);
    expect(q.coins).toMatchObject({ balance: 30, applied: 30, max_usable: 30 }); expect(q.totals.coin_discount).toBe('30.00'); expect(q.totals.total_before_delivery).toBe('970.00');
    await giveCoins(db, u.id, 500);
    q = await quote({ items, use_coins: 9999 }, u.id);
    expect(q.coins.applied).toBe(50); // admin cap default 50 coins/order
    await setting(db, 'coins', { max_redeem_coins_per_order: 100000, coin_value: 2 });
    q = await quote({ items, use_coins: 9999 }, u.id);
    expect(q.coins.applied).toBe(499); expect(q.totals.coin_discount).toBe('998.00'); expect(q.totals.total_before_delivery).toBe('2.00'); // Rs 1 floor, whole coins only
  });
  it('minimum order to redeem is enforced', async () => {
    const u = await mkUser(db); await giveCoins(db, u.id, 40); await setting(db, 'coins', { min_order_to_redeem: 1500 });
    const p = await mkProduct(db, { price: 1000 });
    expect((await quote({ items: [{ product_id: p.id, qty: 1 }], use_coins: 10 }, u.id)).coins.applied).toBe(0);
  });
  it('earn: 1 coin per Rs 100 of eligible net spend; flags and discount rules respected', async () => {
    const u = await mkUser(db); const a = await mkProduct(db, { price: 1050 }); const noCoins = await mkProduct(db, { price: 500, coins: false });
    let q = await quote({ items: [{ product_id: a.id, qty: 1 }, { product_id: noCoins.id, qty: 1 }] }, u.id);
    expect(q.coins.will_earn).toBe(10); // only product `a`: floor(1050/100)
    await mkCoupon(db, { code: 'C50', type: 'fixed', value: 50 });
    q = await quote({ items: [{ product_id: a.id, qty: 1 }], coupon_code: 'C50' }, u.id);
    expect(q.coins.will_earn).toBe(0); expect(q.coins.earn_note).toMatch(/do not earn/);
    await setting(db, 'coins', { earn_on_discounted_orders: true });
    q = await quote({ items: [{ product_id: a.id, qty: 1 }], coupon_code: 'C50' }, u.id);
    expect(q.coins.will_earn).toBe(10); // net 1000 -> 10
  });
  it('category-restricted earning', async () => {
    const u = await mkUser(db); const c1 = await mkCategory(db, 'Eligible'); const c2 = await mkCategory(db, 'Other');
    await setting(db, 'coins', { eligible_category_ids: [c1.id] });
    const a = await mkProduct(db, { category: c1.id, price: 1000 }); const b = await mkProduct(db, { category: c2.id, price: 1000 });
    expect((await quote({ items: [{ product_id: a.id, qty: 1 }, { product_id: b.id, qty: 1 }] }, u.id)).coins.will_earn).toBe(10);
  });
});

describe('store state', () => {
  it('closed store / disabled fulfilment / disabled payment methods block checkout', async () => {
    const p = await mkProduct(db, { price: 1000 }); const items = [{ product_id: p.id, qty: 1 }];
    await setting(db, 'store', { temporarily_closed: true, closed_message: 'Closed for Diwali' });
    let q = await quote({ items }); expect(q.blockers[0]).toMatchObject({ code: 'STORE_CLOSED', message: 'Closed for Diwali' });
    await setting(db, 'store', { temporarily_closed: false, pickup_enabled: false });
    q = await quote({ items }); expect(q.blockers.map((b) => b.code)).toContain('PICKUP_DISABLED');
    await setting(db, 'store', { pickup_enabled: true }); await setting(db, 'order', { cod_enabled: false });
    q = await quote({ items, payment_method: 'cod' }); expect(q.blockers.map((b) => b.code)).toContain('COD_DISABLED');
  });
});
