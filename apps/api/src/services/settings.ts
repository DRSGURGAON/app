import { z } from 'zod';
import type { Queryable } from '../db/pool.js';
import { DEFAULT_POLICIES } from './policies.js';

const hhmm = z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/);
const money = z.number().min(0).max(1_000_000);

export const settingsSchemas = {
  store: z.object({
    name_hi: z.string().default('अर्धसैनिक कैंटीन'),
    name_en: z.string().default('Ardh Sainik Canteen Store Mart'),
    tagline: z.string().default('Groceries & daily needs, delivered'),
    phone: z.string().default('9485519555'),
    address_hi: z.string().default('फतिया ताल रोड, नजदीक सिंघला हॉस्पिटल, लोहारू, भिवानी, हरियाणा'),
    address_en: z.string().default('Fatiya Tal Road, Near Singhla Hospital, Loharu, Bhiwani, Haryana'),
    pincode: z.string().default('127308'),
    // Store coordinates must be set by the owner in Admin → Delivery. Null = not configured yet.
    latitude: z.number().min(-90).max(90).nullable().default(null),
    longitude: z.number().min(-180).max(180).nullable().default(null),
    logo_url: z.string().nullable().default(null),
    open_time: hhmm.default('09:00'),
    close_time: hhmm.default('21:00'),
    timezone: z.string().default('Asia/Kolkata'),
    temporarily_closed: z.boolean().default(false),
    closed_message: z.string().default('The store is temporarily closed. Please check back soon.'),
    delivery_enabled: z.boolean().default(true),
    pickup_enabled: z.boolean().default(true),
    pickup_instructions: z.string().default('Show your order number at the counter.'),
    enforce_hours: z.boolean().default(true),
  }),
  delivery: z.object({
    near_radius_km: z.number().min(0.1).max(50).default(2),
    // STARTING VALUE ONLY - the owner decides the real short-distance fee in Admin → Delivery.
    base_fee: money.default(30),
    far_fee: money.default(70),
    max_radius_km: z.number().min(0).max(200).default(0), // 0 = no maximum
    zone_mode: z.enum(['radius', 'zones']).default('radius'),
    zone_overrides_enabled: z.boolean().default(false),
    fallback_mode: z.enum(['ask_zone', 'straight_line', 'block']).default('ask_zone'),
    straight_line_factor: z.number().min(1).max(3).default(1.0),
  }),
  order: z.object({
    min_order: money.default(999),
    min_applies_to_pickup: z.boolean().default(true),
    min_after_coupon: z.boolean().default(false),
    min_after_coins: z.boolean().default(false),
    cod_enabled: z.boolean().default(true),
    online_enabled: z.boolean().default(true),
    max_lines: z.number().int().min(1).max(200).default(60),
    payment_window_minutes: z.number().int().min(5).max(120).default(20),
  }),
  // UPI paid straight to the store's own UPI ID; staff confirm each payment in the bank app (no gateway).
  upi: z.object({
    enabled: z.boolean().default(false),
    // A merchant / business UPI ID is strongly recommended: some UPI apps decline amount-prefilled payments to personal IDs.
    vpa: z.string().trim().max(100).refine((v) => v === '' || /^[a-zA-Z0-9._-]{2,256}@[a-zA-Z][a-zA-Z0-9.-]{1,63}$/.test(v), 'Enter a UPI ID like shopname@bank').default(''),
    payee_name: z.string().trim().min(1).max(50).default('Ardh Sainik Canteen'),
    // 4-digit merchant category code from the bank, only for a merchant UPI ID. Empty = personal UPI ID.
    merchant_code: z.string().trim().regex(/^(\d{4})?$/, 'Merchant category code is 4 digits (leave empty for a personal UPI ID)').default(''),
    max_unverified_per_customer: z.number().int().min(1).max(10).default(3),
  }),
  coins: z.object({
    enabled: z.boolean().default(true),
    earn_coins_per_unit: z.number().int().min(0).max(1000).default(1),
    earn_spend_unit: z.number().int().min(1).max(100000).default(100),
    coin_value: z.number().min(0).max(1000).default(1), // rupees per coin
    max_redeem_coins_per_order: z.number().int().min(0).max(100000).default(50),
    min_order_to_earn: money.default(999),
    min_order_to_redeem: money.default(999),
    earn_on_discounted_orders: z.boolean().default(false), // coupon / first-order discounts
    expiry_days: z.number().int().min(0).max(3650).default(365), // 0 = never
    eligible_category_ids: z.array(z.string().uuid()).default([]), // empty = every category
  }),
  first_order: z.object({
    enabled: z.boolean().default(false),
    type: z.enum(['percent', 'fixed']).default('percent'),
    value: z.number().min(0).default(5),
    min_spend: money.default(999),
    max_discount: money.nullable().default(100),
  }),
  notifications: z.object({
    order_updates: z.boolean().default(true),
    promotions: z.boolean().default(false),
  }),
  policies: z.object({
    privacy: z.object({ en: z.string(), hi: z.string() }).default(DEFAULT_POLICIES.privacy),
    terms: z.object({ en: z.string(), hi: z.string() }).default(DEFAULT_POLICIES.terms),
    delivery: z.object({ en: z.string(), hi: z.string() }).default(DEFAULT_POLICIES.delivery),
    cancellation: z.object({ en: z.string(), hi: z.string() }).default(DEFAULT_POLICIES.cancellation),
    refund: z.object({ en: z.string(), hi: z.string() }).default(DEFAULT_POLICIES.refund),
  }),
};

export type SettingKey = keyof typeof settingsSchemas;
export type AppSettings = { [K in SettingKey]: z.infer<(typeof settingsSchemas)[K]> };
export const SETTING_KEYS = Object.keys(settingsSchemas) as SettingKey[];

export async function loadSettings(q: Queryable): Promise<AppSettings> {
  const { rows } = await q.query('SELECT key, value FROM settings');
  const stored = new Map<string, unknown>(rows.map((r) => [r.key, r.value]));
  const out: any = {};
  for (const k of SETTING_KEYS) {
    const parsed = settingsSchemas[k].safeParse(stored.get(k) ?? {});
    // A corrupt stored value falls back to defaults rather than taking the store offline.
    out[k] = parsed.success ? parsed.data : settingsSchemas[k].parse({});
  }
  return out as AppSettings;
}

export async function saveSetting(q: Queryable, key: SettingKey, value: unknown, adminId: string | null): Promise<unknown> {
  const parsed = settingsSchemas[key].parse(value);
  await q.query(
    `INSERT INTO settings (key, value, updated_by) VALUES ($1,$2,$3)
     ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = now(), updated_by = EXCLUDED.updated_by`,
    [key, JSON.stringify(parsed), adminId],
  );
  return parsed;
}

/** Is the store accepting orders right now? (server time converted to store timezone) */
export function storeOpenState(s: AppSettings['store'], now = new Date()): { open: boolean; reason?: string } {
  if (s.temporarily_closed) return { open: false, reason: s.closed_message };
  if (!s.enforce_hours) return { open: true };
  const parts = new Intl.DateTimeFormat('en-GB', { timeZone: s.timezone, hour: '2-digit', minute: '2-digit', hour12: false }).formatToParts(now);
  const hh = parts.find((p) => p.type === 'hour')!.value;
  const mm = parts.find((p) => p.type === 'minute')!.value;
  const cur = `${hh === '24' ? '00' : hh}:${mm}`;
  const open = s.open_time <= s.close_time
    ? cur >= s.open_time && cur < s.close_time
    : cur >= s.open_time || cur < s.close_time; // overnight window
  return open ? { open: true } : { open: false, reason: `Store hours are ${s.open_time}–${s.close_time}.` };
}
