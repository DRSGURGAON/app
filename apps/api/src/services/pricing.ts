import type { Queryable } from '../db/pool.js';
import { AppError } from '../lib/errors.js';
import { allocate, fromPaise, inclusiveTax, toPaise, type Paise } from '../lib/money.js';
import { calculateDeliveryFee, resolveDistance, type DeliveryQuote, type RoutingProvider, type ZoneRow } from './delivery.js';
import { checkCoupon, computeDiscount, eligibleLines, isFirstOrderEligible, type CouponRow, type PricedLine } from './coupons.js';
import { getBalance } from './coins.js';
import { storeOpenState, type AppSettings } from './settings.js';

export interface QuoteItem { product_id: string; qty: number }
export interface AddressInput { id?: string | null; latitude: number | null; longitude: number | null; zone_id: string | null; pincode: string | null }
export interface QuoteRequest {
  items: QuoteItem[];
  fulfilment: 'delivery' | 'pickup';
  address?: AddressInput | null;
  coupon_code?: string | null;
  use_coins?: number;
  payment_method?: 'cod' | 'online' | 'upi';
}
export interface QuoteDeps {
  q: Queryable; userId: string | null; settings: AppSettings; routing: RoutingProvider | null; lock?: boolean; now?: Date;
}
export interface Blocker { code: string; message: string; details?: unknown }

interface ProductRow {
  id: string; sku: string; name: string; name_hi: string | null; brand: string | null; category_id: string; subcategory_id: string | null;
  unit: string; pack_size: string | null; mrp: string; price: string; tax_rate: string; stock_qty: number; reserved_qty: number;
  max_per_order: number | null; is_active: boolean; coins_eligible: boolean; offers_eligible: boolean; image_url: string | null;
}

export interface InternalLine {
  product: ProductRow; qty: number; unitPaise: Paise; mrpPaise: Paise; linePaise: Paise;
  promoAlloc: Paise; coinAlloc: Paise; netPaise: Paise; taxPaise: Paise; coinsEligible: boolean;
}

export interface Quote {
  lines: Array<{
    product_id: string; sku: string; name: string; name_hi: string | null; brand: string | null; unit: string; pack_size: string | null; image_url: string | null;
    mrp: string; unit_price: string; qty: number; line_total: string; available: number; issue: Blocker | null;
  }>;
  totals: {
    mrp_total: string; subtotal: string; savings: string; coupon_discount: string; first_order_discount: string; coin_discount: string;
    delivery_fee: string | null; tax_included: string; total: string | null; total_before_delivery: string;
  };
  coupon: { code: string; applied: boolean; title?: string; error?: Blocker } | null;
  first_order: { enabled: boolean; eligible: boolean; applied: boolean; discount: string; note?: string };
  coins: { enabled: boolean; balance: number; requested: number; applied: number; max_usable: number; coin_value: string; will_earn: number; earn_note?: string };
  min_order: { required: string; current: string; shortfall: string; met: boolean; basis: string };
  delivery: {
    fulfilment: 'delivery' | 'pickup'; fee: string | null; rule: string | null; distance_km: number | null; method: string | null;
    zone: { id: string; name: string } | null; pending: boolean; error: Blocker | null; zones_to_choose: Array<{ id: string; name: string; name_hi: string | null }> | null;
  };
  store: { open: boolean; reason?: string };
  blockers: Blocker[];
  can_checkout: boolean;
}

export interface QuoteInternal {
  lines: InternalLine[]; couponRow: CouponRow | null; couponPaise: Paise; firstOrderPaise: Paise; coinsApplied: number; coinPaise: Paise;
  deliveryQuote: DeliveryQuote | null; distanceReason: string | null; totalPaise: Paise | null; minOrderPaise: Paise; coinsToEarn: Paise;
  subtotalPaise: Paise; mrpTotalPaise: Paise; taxPaise: Paise;
}

export async function resolveZone(q: Queryable, a: AddressInput | null | undefined): Promise<ZoneRow | null> {
  if (!a) return null;
  if (a.zone_id) {
    const r = await q.query('SELECT * FROM delivery_zones WHERE id=$1 AND is_active', [a.zone_id]);
    if (r.rowCount) return r.rows[0] as ZoneRow;
  }
  if (a.pincode) {
    const r = await q.query('SELECT * FROM delivery_zones WHERE is_active AND $1 = ANY(pincodes) ORDER BY sort_order, name LIMIT 1', [a.pincode]);
    if (r.rowCount) return r.rows[0] as ZoneRow;
  }
  return null;
}

const blocker = (e: unknown): Blocker =>
  e instanceof AppError ? { code: e.code, message: e.message, details: e.details } : { code: 'INTERNAL', message: 'Something went wrong' };

export async function buildQuote(req: QuoteRequest, deps: QuoteDeps): Promise<{ quote: Quote; internal: QuoteInternal }> {
  const { q, settings: S } = deps;
  const blockers: Blocker[] = [];

  // ---- store / fulfilment / payment switches
  const store = storeOpenState(S.store, deps.now);
  if (!store.open) blockers.push({ code: 'STORE_CLOSED', message: store.reason ?? 'The store is closed right now' });
  if (req.fulfilment === 'delivery' && !S.store.delivery_enabled) blockers.push({ code: 'DELIVERY_DISABLED', message: 'Home delivery is not available right now. Please choose Store Pickup.' });
  if (req.fulfilment === 'pickup' && !S.store.pickup_enabled) blockers.push({ code: 'PICKUP_DISABLED', message: 'Store pickup is not available right now.' });
  if (req.payment_method === 'cod' && !S.order.cod_enabled) blockers.push({ code: 'COD_DISABLED', message: 'Cash on Delivery is not available right now.' });
  if (req.payment_method === 'online' && !S.order.online_enabled) blockers.push({ code: 'ONLINE_DISABLED', message: 'Online payment is not available right now.' });
  if (req.payment_method === 'upi' && !(S.upi.enabled && S.upi.vpa)) blockers.push({ code: 'UPI_DISABLED', message: 'UPI payment is not available right now.' });

  // ---- cart lines (merge duplicates)
  const merged = new Map<string, number>();
  for (const it of req.items) merged.set(it.product_id, (merged.get(it.product_id) ?? 0) + it.qty);
  if (merged.size === 0) blockers.push({ code: 'CART_EMPTY', message: 'Your cart is empty' });
  if (merged.size > S.order.max_lines) blockers.push({ code: 'TOO_MANY_LINES', message: `You can order up to ${S.order.max_lines} different items at once` });

  const ids = [...merged.keys()];
  const prodRes = ids.length
    ? await q.query(
        `SELECT p.*, (SELECT url FROM product_images i WHERE i.product_id = p.id ORDER BY sort_order, created_at LIMIT 1) AS image_url
           FROM products p WHERE p.id = ANY($1::uuid[])`, [ids])
    : { rows: [] as ProductRow[] };
  const byId = new Map<string, ProductRow>((prodRes.rows as ProductRow[]).map((p) => [p.id, p]));

  const outLines: Quote['lines'] = [];
  const lines: InternalLine[] = [];
  for (const [pid, qty] of merged) {
    const p = byId.get(pid);
    if (!p || !p.is_active) {
      const issue = { code: 'PRODUCT_UNAVAILABLE', message: 'This item is no longer available' };
      blockers.push({ ...issue, details: { product_id: pid } });
      outLines.push({ product_id: pid, sku: p?.sku ?? '', name: p?.name ?? 'Unavailable item', name_hi: p?.name_hi ?? null, brand: p?.brand ?? null, unit: p?.unit ?? '', pack_size: p?.pack_size ?? null, image_url: p?.image_url ?? null, mrp: p?.mrp ?? '0.00', unit_price: p?.price ?? '0.00', qty, line_total: '0.00', available: 0, issue });
      continue;
    }
    const available = Math.max(p.stock_qty - p.reserved_qty, 0);
    let issue: Blocker | null = null;
    if (p.max_per_order !== null && qty > p.max_per_order) issue = { code: 'MAX_QTY', message: `You can order at most ${p.max_per_order} of "${p.name}"`, details: { max: p.max_per_order } };
    else if (qty > available) issue = available === 0
      ? { code: 'OUT_OF_STOCK', message: `"${p.name}" is out of stock`, details: { available } }
      : { code: 'INSUFFICIENT_STOCK', message: `Only ${available} left of "${p.name}"`, details: { available } };
    if (issue) blockers.push({ ...issue, details: { ...(issue.details as object), product_id: pid } });

    const unit = toPaise(p.price), mrp = toPaise(p.mrp);
    const lineP = unit * qty;
    lines.push({ product: p, qty, unitPaise: unit, mrpPaise: mrp, linePaise: lineP, promoAlloc: 0, coinAlloc: 0, netPaise: lineP, taxPaise: 0, coinsEligible: p.coins_eligible });
    outLines.push({ product_id: p.id, sku: p.sku, name: p.name, name_hi: p.name_hi, brand: p.brand, unit: p.unit, pack_size: p.pack_size, image_url: p.image_url, mrp: p.mrp, unit_price: p.price, qty, line_total: fromPaise(lineP), available, issue });
  }

  const subtotal = lines.reduce((s, l) => s + l.linePaise, 0);
  const mrpTotal = lines.reduce((s, l) => s + l.mrpPaise * l.qty, 0);

  // ---- promotions: one per order. An explicitly entered coupon wins over the automatic first-order discount.
  const priced: PricedLine[] = lines.map((l) => ({ productId: l.product.id, categoryId: l.product.category_id, subcategoryId: l.product.subcategory_id, linePaise: l.linePaise, offersEligible: l.product.offers_eligible }));
  const firstEligible = deps.userId ? await isFirstOrderEligible(q, deps.userId) : false;

  let couponRow: CouponRow | null = null, couponPaise = 0, firstOrderPaise = 0;
  let couponOut: Quote['coupon'] = null;
  let promoLines: PricedLine[] = [];
  if (req.coupon_code && req.coupon_code.trim()) {
    try {
      const r = await checkCoupon(q, { code: req.coupon_code, userId: deps.userId, lines: priced, firstOrderEligible: firstEligible, lock: deps.lock, now: deps.now });
      couponRow = r.coupon; couponPaise = r.discountPaise; promoLines = r.eligible;
      couponOut = { code: r.coupon.code, applied: true, title: r.coupon.title };
    } catch (e) {
      const b = blocker(e);
      couponOut = { code: req.coupon_code.trim().toUpperCase(), applied: false, error: b };
      blockers.push({ ...b, details: { ...(b.details as object | undefined), coupon: true } });
    }
  }
  const fo = S.first_order;
  const foOut: Quote['first_order'] = { enabled: fo.enabled, eligible: fo.enabled && firstEligible, applied: false, discount: '0.00' };
  if (!couponRow && fo.enabled && firstEligible) {
    const elig = eligibleLines({ category_ids: [], product_ids: [] }, priced);
    const eligPaise = elig.reduce((s, l) => s + l.linePaise, 0);
    if (eligPaise > 0 && eligPaise >= toPaise(fo.min_spend)) {
      firstOrderPaise = computeDiscount(fo.type, String(fo.value), fo.max_discount === null ? null : String(fo.max_discount), eligPaise);
      if (firstOrderPaise > 0) { promoLines = elig; foOut.applied = true; foOut.discount = fromPaise(firstOrderPaise); }
    } else if (eligPaise > 0) {
      foOut.note = `Spend ₹${fromPaise(toPaise(fo.min_spend)).replace(/\.00$/, '')} or more to get your first-order discount`;
    }
  } else if (couponRow && fo.enabled && firstEligible) {
    foOut.note = 'Your coupon is applied instead of the first-order discount (only one offer per order).';
  }
  const promoPaise = couponPaise + firstOrderPaise;
  if (promoPaise > 0) {
    const weights = lines.map((l) => (promoLines.some((p) => p.productId === l.product.id) ? l.linePaise : 0));
    const parts = allocate(promoPaise, weights);
    lines.forEach((l, i) => { l.promoAlloc = parts[i]!; });
  }

  // ---- delivery (needs address)
  let delivery: DeliveryQuote | null = null;
  let deliveryErr: Blocker | null = null;
  let distanceReason: string | null = null;
  let zonesToChoose: Quote['delivery']['zones_to_choose'] = null;
  if (req.fulfilment === 'pickup') {
    delivery = calculateDeliveryFee({ fulfilment: 'pickup', distanceKm: null, distanceMethod: 'none', zone: null, settings: S.delivery });
  } else if (!req.address) {
    deliveryErr = { code: 'ADDRESS_REQUIRED', message: 'Select a delivery address to see the delivery charge' };
  } else {
    const zone = await resolveZone(q, req.address);
    const addrPoint = req.address.latitude !== null && req.address.longitude !== null ? { lat: req.address.latitude, lng: req.address.longitude } : null;
    const storePoint = S.store.latitude !== null && S.store.longitude !== null ? { lat: S.store.latitude, lng: S.store.longitude } : null;
    const dist = await resolveDistance({ store: storePoint, address: addrPoint, settings: S.delivery, provider: deps.routing });
    distanceReason = dist.reason ?? null;
    try {
      delivery = calculateDeliveryFee({ fulfilment: 'delivery', distanceKm: dist.km, distanceMethod: dist.method, zone, settings: S.delivery });
    } catch (e) {
      deliveryErr = blocker(e);
      if (deliveryErr.code === 'DELIVERY_ZONE_REQUIRED') {
        const z = await q.query('SELECT id, name, name_hi FROM delivery_zones WHERE is_active ORDER BY sort_order, name');
        zonesToChoose = z.rows;
      }
    }
  }
  if (deliveryErr) blockers.push(deliveryErr);

  // ---- minimum order (merchandise before delivery fee)
  let minOrder = toPaise(S.order.min_order);
  if (delivery?.zone_min_order_paise != null) minOrder = delivery.zone_min_order_paise;
  if (req.fulfilment === 'pickup' && !S.order.min_applies_to_pickup) minOrder = 0;

  // ---- coins
  const balance = deps.userId && S.coins.enabled ? await getBalance(q, deps.userId) : 0;
  const coinValuePaise = Math.round(S.coins.coin_value * 100);
  const afterPromo = subtotal - promoPaise;
  let coinsApplied = 0, coinPaise = 0, maxUsable = 0;
  if (S.coins.enabled && deps.userId && coinValuePaise > 0 && subtotal >= toPaise(S.coins.min_order_to_redeem)) {
    const room = Math.max(afterPromo - 100, 0); // customer always pays at least Rs 1 of merchandise
    maxUsable = Math.max(0, Math.min(balance, S.coins.max_redeem_coins_per_order, Math.floor(room / coinValuePaise)));
    coinsApplied = Math.max(0, Math.min(Math.floor(req.use_coins ?? 0), maxUsable));
    coinPaise = coinsApplied * coinValuePaise;
  }
  if (coinPaise > 0) {
    const parts = allocate(coinPaise, lines.map((l) => l.linePaise - l.promoAlloc));
    lines.forEach((l, i) => { l.coinAlloc = parts[i]!; });
  }
  for (const l of lines) {
    l.netPaise = l.linePaise - l.promoAlloc - l.coinAlloc;
    l.taxPaise = inclusiveTax(l.netPaise, l.product.tax_rate);
  }
  const taxPaise = lines.reduce((s, l) => s + l.taxPaise, 0);

  // minimum order check
  let minBasis = subtotal;
  const basisNotes = ['product selling prices, before delivery fee'];
  if (S.order.min_after_coupon) { minBasis -= promoPaise; basisNotes.push('after coupon/first-order discount'); }
  if (S.order.min_after_coins) { minBasis -= coinPaise; basisNotes.push('after coins'); }
  const minMet = minBasis >= minOrder;
  if (!minMet && lines.length > 0) {
    blockers.push({ code: 'MIN_ORDER_NOT_MET', message: `Minimum order is ₹${fromPaise(minOrder).replace(/\.00$/, '')}. Add items worth ₹${fromPaise(minOrder - minBasis).replace(/\.00$/, '')} more.`, details: { required: fromPaise(minOrder), current: fromPaise(minBasis) } });
  }

  // ---- coins to earn (credited only after fulfilment)
  let coinsToEarn = 0, earnNote: string | undefined;
  if (S.coins.enabled) {
    const allowedCats = S.coins.eligible_category_ids;
    const base = lines.filter((l) => l.coinsEligible && (allowedCats.length === 0 || allowedCats.includes(l.product.category_id) || (l.product.subcategory_id !== null && allowedCats.includes(l.product.subcategory_id))))
      .reduce((s, l) => s + l.netPaise, 0);
    if (subtotal < toPaise(S.coins.min_order_to_earn)) earnNote = `Orders of ₹${fromPaise(toPaise(S.coins.min_order_to_earn)).replace(/\.00$/, '')} or more earn coins`;
    else if (promoPaise > 0 && !S.coins.earn_on_discounted_orders) earnNote = 'Orders that use a coupon or first-order discount do not earn coins';
    else coinsToEarn = Math.floor(base / (S.coins.earn_spend_unit * 100)) * S.coins.earn_coins_per_unit;
  }

  const merchPayable = subtotal - promoPaise - coinPaise;
  const feePaise = delivery ? delivery.fee_paise : null;
  const totalPaise = feePaise === null ? null : merchPayable + feePaise;

  const quote: Quote = {
    lines: outLines,
    totals: {
      mrp_total: fromPaise(mrpTotal), subtotal: fromPaise(subtotal), savings: fromPaise(Math.max(mrpTotal - subtotal, 0)),
      coupon_discount: fromPaise(couponPaise), first_order_discount: fromPaise(firstOrderPaise), coin_discount: fromPaise(coinPaise),
      delivery_fee: feePaise === null ? null : fromPaise(feePaise), tax_included: fromPaise(taxPaise),
      total: totalPaise === null ? null : fromPaise(totalPaise), total_before_delivery: fromPaise(merchPayable),
    },
    coupon: couponOut,
    first_order: foOut,
    coins: { enabled: S.coins.enabled, balance, requested: Math.max(0, Math.floor(req.use_coins ?? 0)), applied: coinsApplied, max_usable: maxUsable, coin_value: S.coins.coin_value.toFixed(2), will_earn: coinsToEarn, earn_note: earnNote },
    min_order: { required: fromPaise(minOrder), current: fromPaise(minBasis), shortfall: fromPaise(Math.max(minOrder - minBasis, 0)), met: minMet, basis: basisNotes.join(', ') },
    delivery: {
      fulfilment: req.fulfilment, fee: feePaise === null ? null : fromPaise(feePaise), rule: delivery?.rule ?? null,
      distance_km: delivery?.distance_km ?? null, method: delivery?.distance_method ?? null, zone: delivery?.zone ?? null,
      pending: req.fulfilment === 'delivery' && !delivery, error: deliveryErr, zones_to_choose: zonesToChoose,
    },
    store,
    blockers,
    can_checkout: blockers.length === 0 && lines.length > 0 && totalPaise !== null,
  };
  return {
    quote,
    internal: { lines, couponRow, couponPaise, firstOrderPaise, coinsApplied, coinPaise, deliveryQuote: delivery, distanceReason, totalPaise, minOrderPaise: minOrder, coinsToEarn, subtotalPaise: subtotal, mrpTotalPaise: mrpTotal, taxPaise },
  };
}
