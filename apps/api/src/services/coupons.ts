import type { Queryable } from '../db/pool.js';
import { AppError } from '../lib/errors.js';
import { percentOf, toPaise, type Paise } from '../lib/money.js';

export interface CouponRow {
  id: string; code: string; title: string; description: string | null; discount_type: 'percent' | 'fixed'; discount_value: string;
  min_spend: string; max_discount: string | null; starts_at: Date; ends_at: Date; usage_limit: number | null; per_user_limit: number;
  used_count: number; category_ids: string[]; product_ids: string[]; first_order_only: boolean; festival: string | null; is_active: boolean;
}

export interface PricedLine {
  productId: string; categoryId: string; subcategoryId: string | null; linePaise: Paise; offersEligible: boolean;
}

export const normalizeCode = (c: string) => c.trim().toUpperCase().replace(/\s+/g, '');

export function eligibleLines(c: Pick<CouponRow, 'category_ids' | 'product_ids'>, lines: PricedLine[]): PricedLine[] {
  return lines.filter((l) =>
    l.offersEligible &&
    (c.product_ids.length === 0 || c.product_ids.includes(l.productId)) &&
    (c.category_ids.length === 0 || c.category_ids.includes(l.categoryId) || (l.subcategoryId !== null && c.category_ids.includes(l.subcategoryId))));
}

export function computeDiscount(type: 'percent' | 'fixed', value: string, maxDiscount: string | null, eligiblePaise: Paise): Paise {
  let d = type === 'percent' ? percentOf(eligiblePaise, value) : toPaise(value);
  if (maxDiscount !== null) d = Math.min(d, toPaise(maxDiscount));
  return Math.max(0, Math.min(d, eligiblePaise));
}

export interface CouponCheck { coupon: CouponRow; discountPaise: Paise; eligible: PricedLine[] }

/**
 * Validate a coupon for this customer and cart. Throws AppError with a specific code on any failure.
 * Pass `lock: true` inside the checkout transaction so concurrent redemptions are serialised.
 */
export async function checkCoupon(q: Queryable, args: {
  code: string; userId: string | null; lines: PricedLine[]; firstOrderEligible: boolean; lock?: boolean; now?: Date;
}): Promise<CouponCheck> {
  const code = normalizeCode(args.code);
  const { rows } = await q.query(`SELECT * FROM coupons WHERE code=$1 ${args.lock ? 'FOR UPDATE' : ''}`, [code]);
  const c = rows[0] as CouponRow | undefined;
  const now = args.now ?? new Date();
  if (!c) throw new AppError(422, 'COUPON_NOT_FOUND', 'This coupon code is not valid');
  if (!c.is_active) throw new AppError(422, 'COUPON_INACTIVE', 'This coupon is not active');
  if (now < new Date(c.starts_at)) throw new AppError(422, 'COUPON_NOT_STARTED', `This coupon starts on ${new Date(c.starts_at).toLocaleDateString('en-IN', { timeZone: 'Asia/Kolkata' })}`);
  if (now >= new Date(c.ends_at)) throw new AppError(422, 'COUPON_EXPIRED', 'This coupon has expired');
  if (!args.userId) throw new AppError(401, 'LOGIN_REQUIRED', 'Please log in to use a coupon');
  if (c.first_order_only && !args.firstOrderEligible) throw new AppError(422, 'COUPON_FIRST_ORDER_ONLY', 'This coupon is only for your first order');
  if (c.usage_limit !== null && c.used_count >= c.usage_limit) throw new AppError(422, 'COUPON_LIMIT_REACHED', 'This coupon has been fully redeemed');
  const used = await q.query(`SELECT count(*)::int AS n FROM coupon_redemptions WHERE coupon_id=$1 AND user_id=$2 AND status='active'`, [c.id, args.userId]);
  if (used.rows[0].n >= c.per_user_limit) throw new AppError(422, 'COUPON_USER_LIMIT', 'You have already used this coupon');

  const eligible = eligibleLines(c, args.lines);
  const eligiblePaise = eligible.reduce((s, l) => s + l.linePaise, 0);
  if (eligiblePaise === 0) throw new AppError(422, 'COUPON_NOT_ELIGIBLE_ITEMS', 'This coupon does not apply to the items in your cart');
  const minSpend = toPaise(c.min_spend);
  if (eligiblePaise < minSpend) {
    throw new AppError(422, 'COUPON_MIN_SPEND', `Add items worth ₹${((minSpend - eligiblePaise) / 100).toFixed(2).replace(/\.00$/, '')} more to use this coupon`, { shortfall_paise: minSpend - eligiblePaise });
  }
  const discountPaise = computeDiscount(c.discount_type, c.discount_value, c.max_discount, eligiblePaise);
  if (discountPaise <= 0) throw new AppError(422, 'COUPON_NO_DISCOUNT', 'This coupon gives no discount on your cart');
  return { coupon: c, discountPaise, eligible };
}

/** First-order = the customer has no live (non-cancelled, non-rejected, non-refunded) order yet. */
export async function isFirstOrderEligible(q: Queryable, userId: string): Promise<boolean> {
  const r = await q.query(`SELECT 1 FROM orders WHERE user_id=$1 AND status NOT IN ('cancelled','rejected','refunded') LIMIT 1`, [userId]);
  return r.rowCount === 0;
}
