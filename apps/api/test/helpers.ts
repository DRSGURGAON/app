import { randomUUID } from 'node:crypto';
import { createPool, type Db } from '../src/db/pool.js';
import { loadConfig } from '../src/config.js';
import { MockPaymentProvider } from '../src/providers/payments.js';
import { MockOtpSender } from '../src/providers/otp.js';
import { NoopPush } from '../src/providers/fcm.js';
import type { AppCtx } from '../src/services/orders.js';
import { settingsSchemas, saveSetting, type SettingKey } from '../src/services/settings.js';

export function makeCtx(over: Partial<AppCtx> = {}): AppCtx & { db: Db; payments: MockPaymentProvider; otp: MockOtpSender } {
  const config = loadConfig({ ...process.env, NODE_ENV: 'test', DATABASE_URL: process.env.TEST_DATABASE_URL! } as any);
  const db = createPool(process.env.TEST_DATABASE_URL!, 20);
  return { db, config, payments: new MockPaymentProvider(), routing: null, push: new NoopPush(), otp: new MockOtpSender(), ...over } as any;
}

export async function reset(db: Db) {
  await db.query(`TRUNCATE settings, users, auth_otps, refresh_tokens, device_tokens, admin_users, delivery_zones, addresses, categories, products,
    product_images, stock_movements, coupons, banners, orders, order_items, order_status_history, coupon_redemptions, payments, payment_events,
    refunds, wallets, wallet_transactions, coin_lots, notifications, audit_logs, import_jobs, import_errors RESTART IDENTITY CASCADE`);
  await db.query('ALTER SEQUENCE order_no_seq RESTART WITH 1');
}

export async function setting(db: Db, key: SettingKey, patch: Record<string, unknown>) {
  const cur = (await db.query('SELECT value FROM settings WHERE key=$1', [key])).rows[0]?.value ?? {};
  await saveSetting(db, key, { ...settingsSchemas[key].parse({}), ...cur, ...patch }, null);
}

let n = 0;
export async function mkCategory(db: Db, name = `Cat ${++n}`, parent: string | null = null) {
  return (await db.query('INSERT INTO categories (name, slug, parent_id) VALUES ($1,$2,$3) RETURNING *', [name, `${name.toLowerCase().replace(/\W+/g, '-')}-${randomUUID().slice(0, 6)}`, parent])).rows[0];
}
export async function mkProduct(db: Db, o: { category?: string; price?: number; mrp?: number; stock?: number; name?: string; tax?: number; coins?: boolean; offers?: boolean; max?: number | null; active?: boolean; sub?: string | null } = {}) {
  const category = o.category ?? (await mkCategory(db)).id;
  const price = o.price ?? 500;
  return (await db.query(
    `INSERT INTO products (sku, name, category_id, subcategory_id, mrp, price, tax_rate, stock_qty, coins_eligible, offers_eligible, max_per_order, is_active)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12) RETURNING *`,
    [`SKU-${++n}-${randomUUID().slice(0, 4)}`, o.name ?? `Product ${n}`, category, o.sub ?? null, o.mrp ?? price, price, o.tax ?? 0, o.stock ?? 100, o.coins ?? true, o.offers ?? true, o.max ?? null, o.active ?? true])).rows[0];
}
export async function mkUser(db: Db, phone?: string) {
  const ph = phone ?? `9${String(100000000 + (++n))}`;
  return (await db.query('INSERT INTO users (phone, name) VALUES ($1,$2) RETURNING *', [ph, 'Test User'])).rows[0];
}
export async function mkAddress(db: Db, userId: string, o: { lat?: number | null; lng?: number | null; zone?: string | null; pincode?: string } = {}) {
  return (await db.query(
    `INSERT INTO addresses (user_id, full_name, phone, line1, pincode, latitude, longitude, zone_id) VALUES ($1,'Test User','9876543210','House 1, Main Road',$2,$3,$4,$5) RETURNING *`,
    [userId, o.pincode ?? '127308', o.lat ?? null, o.lng ?? null, o.zone ?? null])).rows[0];
}
export async function mkZone(db: Db, name: string, fee_mode: 'base' | 'far' | 'custom' = 'base', pincodes: string[] = ['127308'], extra: { custom_fee?: string; min_order?: string } = {}) {
  return (await db.query('INSERT INTO delivery_zones (name, fee_mode, pincodes, custom_fee, min_order) VALUES ($1,$2,$3,$4,$5) RETURNING *', [name, fee_mode, pincodes, extra.custom_fee ?? null, extra.min_order ?? null])).rows[0];
}
export async function mkCoupon(db: Db, o: Partial<{ code: string; type: 'percent' | 'fixed'; value: number; min: number; max: number | null; start: string; end: string; limit: number | null; perUser: number; cats: string[]; prods: string[]; first: boolean; active: boolean }> = {}) {
  return (await db.query(
    `INSERT INTO coupons (code, title, discount_type, discount_value, min_spend, max_discount, starts_at, ends_at, usage_limit, per_user_limit, category_ids, product_ids, first_order_only, is_active)
     VALUES ($1,'Test coupon',$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13) RETURNING *`,
    [o.code ?? 'SAVE10', o.type ?? 'percent', o.value ?? 10, o.min ?? 0, o.max ?? null, o.start ?? '2020-01-01', o.end ?? '2099-01-01', o.limit ?? null, o.perUser ?? 1, o.cats ?? [], o.prods ?? [], o.first ?? false, o.active ?? true])).rows[0];
}
/** Make the store open 24h so tests never depend on the wall clock. */
export async function openStore(db: Db, extra: Record<string, unknown> = {}) {
  await setting(db, 'store', { enforce_hours: false, latitude: 28.4, longitude: 75.8, ...extra });
}
export async function giveCoins(db: Db, userId: string, coins: number, ref = `test:${randomUUID()}`) {
  const { postLedger } = await import('../src/services/coins.js');
  const c = await db.connect();
  try { await c.query('BEGIN'); await postLedger(c, { userId, type: 'adjust', coins, ref, note: 'test grant' }); await c.query('COMMIT'); } finally { c.release(); }
}
