import { randomUUID } from 'node:crypto';
import type { Db, Queryable, Tx } from '../db/pool.js';
import { withTx } from '../db/pool.js';
import type { Config } from '../config.js';
import type { RoutingProvider } from './delivery.js';
import type { PaymentProvider } from '../providers/payments.js';
import type { PushSender } from '../providers/fcm.js';
import type { OtpSender } from '../providers/otp.js';
import { AppError, conflict, forbidden, notFound } from '../lib/errors.js';
import { fromPaise, toPaise } from '../lib/money.js';
import { audit } from '../lib/audit.js';
import { buildQuote, type AddressInput, type Quote, type QuoteItem } from './pricing.js';
import { loadSettings } from './settings.js';
import { ensureWallet, postLedger } from './coins.js';
import { fulfilStock, releaseStock, reserveStock } from './stock.js';
import { notifyUser } from './notifications.js';

export interface AppCtx {
  db: Db; config: Config; payments: PaymentProvider; routing: RoutingProvider | null; push: PushSender; otp: OtpSender;
}

export type OrderStatus =
  | 'pending_payment' | 'placed' | 'accepted' | 'packing' | 'ready_for_dispatch' | 'out_for_delivery' | 'delivered'
  | 'ready_for_pickup' | 'collected' | 'cancelled' | 'rejected' | 'refund_pending' | 'refunded';

export const DELIVERY_FLOW: OrderStatus[] = ['placed', 'accepted', 'packing', 'ready_for_dispatch', 'out_for_delivery', 'delivered'];
export const PICKUP_FLOW: OrderStatus[] = ['placed', 'accepted', 'packing', 'ready_for_pickup', 'collected'];

export const STATUS_LABELS: Record<OrderStatus, { en: string; hi: string }> = {
  pending_payment: { en: 'Awaiting payment', hi: 'भुगतान का इंतज़ार' },
  placed: { en: 'Order placed', hi: 'ऑर्डर मिल गया' },
  accepted: { en: 'Accepted', hi: 'स्वीकार किया गया' },
  packing: { en: 'Packing', hi: 'पैकिंग हो रही है' },
  ready_for_dispatch: { en: 'Ready for dispatch', hi: 'भेजने के लिए तैयार' },
  out_for_delivery: { en: 'Out for delivery', hi: 'डिलीवरी के लिए निकला' },
  delivered: { en: 'Delivered', hi: 'डिलीवर हो गया' },
  ready_for_pickup: { en: 'Ready for pickup', hi: 'लेने के लिए तैयार' },
  collected: { en: 'Collected', hi: 'प्राप्त किया' },
  cancelled: { en: 'Cancelled', hi: 'रद्द' },
  rejected: { en: 'Rejected', hi: 'अस्वीकृत' },
  refund_pending: { en: 'Refund pending', hi: 'रिफंड प्रक्रिया में' },
  refunded: { en: 'Refunded', hi: 'रिफंड हो गया' },
};

const OPEN_STATUSES: OrderStatus[] = ['pending_payment', 'placed', 'accepted', 'packing', 'ready_for_dispatch', 'out_for_delivery', 'ready_for_pickup'];

/** Statuses an admin may move an order to from `from`. */
export function adminNextStatuses(from: OrderStatus, fulfilment: 'delivery' | 'pickup'): OrderStatus[] {
  const flow = fulfilment === 'delivery' ? DELIVERY_FLOW : PICKUP_FLOW;
  if (from === 'pending_payment') return ['cancelled'];
  const i = flow.indexOf(from);
  if (i === -1 || i === flow.length - 1) return [];
  const next: OrderStatus[] = [flow[i + 1]!];
  if (from === 'placed') next.push('rejected');
  next.push('cancelled');
  return next;
}

// A UPI order the customer has reported as paid is waiting for staff: only staff may cancel it (money may already be in the bank).
export const customerCanCancel = (s: OrderStatus, paymentStatus?: string) => (s === 'pending_payment' && paymentStatus !== 'verifying') || s === 'placed';

export interface CheckoutInput {
  idempotency_key: string;
  items: QuoteItem[];
  fulfilment: 'delivery' | 'pickup';
  address_id?: string | null;
  zone_id?: string | null;
  payment_method: 'cod' | 'online' | 'upi';
  coupon_code?: string | null;
  use_coins?: number;
  expected_total?: string | null;
  note?: string | null;
}

export function istDateStamp(d = new Date()): string {
  const p = new Intl.DateTimeFormat('en-GB', { timeZone: 'Asia/Kolkata', year: '2-digit', month: '2-digit', day: '2-digit' }).formatToParts(d);
  const g = (t: string) => p.find((x) => x.type === t)!.value;
  return `${g('year')}${g('month')}${g('day')}`;
}

export async function loadAddressInput(q: Queryable, userId: string, addressId: string, zoneOverride?: string | null) {
  const r = await q.query('SELECT * FROM addresses WHERE id=$1 AND user_id=$2 AND deleted_at IS NULL', [addressId, userId]);
  if (!r.rowCount) throw notFound('Address not found');
  const a = r.rows[0];
  const input: AddressInput = {
    id: a.id, latitude: a.latitude === null ? null : Number(a.latitude), longitude: a.longitude === null ? null : Number(a.longitude),
    zone_id: zoneOverride ?? a.zone_id, pincode: a.pincode,
  };
  return { row: a, input };
}

export async function createOrder(ctx: AppCtx, userId: string, input: CheckoutInput): Promise<{ orderId: string; replay: boolean; quote?: Quote }> {
  if (input.payment_method === 'online' && ctx.payments.name === 'none') throw new AppError(422, 'ONLINE_DISABLED', 'Online payment is not available right now.');
  try {
    return await withTx(ctx.db, async (tx) => {
      // Serialise this customer's checkouts: idempotency, first-order discount and coin balance all depend on it.
      const u = await tx.query('SELECT id, name, phone, status FROM users WHERE id=$1 FOR UPDATE', [userId]);
      if (!u.rowCount || u.rows[0].status !== 'active') throw forbidden('This account cannot place orders');
      const user = u.rows[0];

      const existing = await tx.query('SELECT id FROM orders WHERE user_id=$1 AND idempotency_key=$2', [userId, input.idempotency_key]);
      if (existing.rowCount) return { orderId: existing.rows[0].id as string, replay: true };

      await ensureWallet(tx, userId);
      const settings = await loadSettings(tx);

      let addr: Awaited<ReturnType<typeof loadAddressInput>> | null = null;
      if (input.fulfilment === 'delivery') {
        if (!input.address_id) throw new AppError(422, 'ADDRESS_REQUIRED', 'Please select a delivery address');
        addr = await loadAddressInput(tx, userId, input.address_id, input.zone_id);
      }

      const { quote, internal } = await buildQuote({
        items: input.items, fulfilment: input.fulfilment, address: addr?.input ?? null, coupon_code: input.coupon_code, use_coins: input.use_coins, payment_method: input.payment_method,
      }, { q: tx, userId, settings, routing: ctx.routing, lock: true });

      if (!quote.can_checkout || internal.totalPaise === null) {
        const first = quote.blockers[0] ?? { code: 'CHECKOUT_BLOCKED', message: 'Unable to place this order' };
        const status = first.code.startsWith('STOCK') || first.code === 'OUT_OF_STOCK' || first.code === 'INSUFFICIENT_STOCK' ? 409 : 422;
        throw new AppError(status, first.code, first.message, { blockers: quote.blockers, quote });
      }
      if (input.expected_total != null && toPaise(input.expected_total) !== internal.totalPaise) {
        throw conflict('PRICE_CHANGED', 'Prices or charges changed. Please review the updated total.', { quote });
      }

      const orderId = randomUUID();
      const seq = (await tx.query("SELECT nextval('order_no_seq') AS n")).rows[0].n;
      const orderNo = `ASM${istDateStamp()}-${String(seq).padStart(5, '0')}`;
      const online = input.payment_method !== 'cod'; // gateway or UPI: paid before the store accepts the order
      const status: OrderStatus = online ? 'pending_payment' : 'placed';
      const d = internal.deliveryQuote!;
      const snapshot = addr ? {
        label: addr.row.label, full_name: addr.row.full_name, phone: addr.row.phone, line1: addr.row.line1, line2: addr.row.line2,
        landmark: addr.row.landmark, city: addr.row.city, state: addr.row.state, pincode: addr.row.pincode,
        latitude: addr.row.latitude === null ? null : Number(addr.row.latitude), longitude: addr.row.longitude === null ? null : Number(addr.row.longitude),
      } : null;
      const total = fromPaise(internal.totalPaise);
      const windowMin = settings.order.payment_window_minutes;

      try {
        await tx.query(
          `INSERT INTO orders (id, order_no, user_id, idempotency_key, status, fulfilment_type, payment_method, payment_status,
             address_id, address_snapshot, customer_name, customer_phone, distance_km, distance_method, zone_id, zone_name, delivery_fee_rule,
             mrp_total, subtotal, coupon_id, coupon_code, coupon_discount, first_order_discount, coins_redeemed, coin_discount,
             delivery_fee, tax_included, total, coins_to_earn, min_order_value, pricing_snapshot, customer_note, payment_expires_at)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21,$22,$23,$24,$25,$26,$27,$28,$29,$30,$31,$32,
                   CASE WHEN $5 = 'pending_payment' THEN now() + make_interval(mins => $33) ELSE NULL END)`,
          [orderId, orderNo, userId, input.idempotency_key, status, input.fulfilment, input.payment_method, online ? 'pending' : 'cod_pending',
            addr?.row.id ?? null, snapshot ? JSON.stringify(snapshot) : null, snapshot?.full_name ?? user.name, snapshot?.phone ?? user.phone,
            d.distance_km, d.distance_method === 'none' ? null : d.distance_method, d.zone?.id ?? null, d.zone?.name ?? null, d.rule,
            fromPaise(internal.mrpTotalPaise), fromPaise(internal.subtotalPaise), internal.couponRow?.id ?? null, internal.couponRow?.code ?? null,
            fromPaise(internal.couponPaise), fromPaise(internal.firstOrderPaise), internal.coinsApplied, fromPaise(internal.coinPaise),
            fromPaise(d.fee_paise), fromPaise(internal.taxPaise), total, internal.coinsToEarn, fromPaise(internal.minOrderPaise),
            JSON.stringify({ ...quote, lines: undefined }), input.note ?? null, windowMin]);
      } catch (e: any) {
        if (e?.code === '23505' && String(e.constraint).includes('first_order')) throw conflict('FIRST_ORDER_DISCOUNT_USED', 'The first-order discount has already been used on this account.');
        throw e;
      }

      for (const l of internal.lines) {
        await tx.query(
          `INSERT INTO order_items (order_id, product_id, category_id, sku, name, brand, unit, pack_size, image_url, mrp, unit_price, qty, line_total, discount_alloc, net_total, tax_rate, tax_amount, coins_eligible)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18)`,
          [orderId, l.product.id, l.product.category_id, l.product.sku, l.product.name, l.product.brand, l.product.unit, l.product.pack_size, l.product.image_url,
            l.product.mrp, l.product.price, l.qty, fromPaise(l.linePaise), fromPaise(l.promoAlloc + l.coinAlloc), fromPaise(l.netPaise), l.product.tax_rate, fromPaise(l.taxPaise), l.coinsEligible]);
      }

      await reserveStock(tx, internal.lines.map((l) => ({ productId: l.product.id, qty: l.qty })), orderId);

      if (input.payment_method === 'upi') {
        // One payment record per UPI order; staff confirmation settles it through applyPaymentCaptured like a gateway capture.
        await tx.query(`INSERT INTO payments (order_id, provider, provider_order_id, amount, status, method, mode) VALUES ($1,'upi_manual',$2,$3,'created','upi','live')`,
          [orderId, `upi_${orderNo}`, total]);
      }

      if (internal.couponRow) {
        await tx.query('INSERT INTO coupon_redemptions (coupon_id, user_id, order_id, amount) VALUES ($1,$2,$3,$4)', [internal.couponRow.id, userId, orderId, fromPaise(internal.couponPaise)]);
        await tx.query('UPDATE coupons SET used_count = used_count + 1 WHERE id=$1', [internal.couponRow.id]);
      }
      if (internal.coinsApplied > 0) {
        await postLedger(tx, { userId, type: 'redeem', coins: -internal.coinsApplied, ref: `order:${orderId}:redeem`, orderId, note: `Used on order ${orderNo}` });
      }

      await tx.query(`INSERT INTO order_status_history (order_id, from_status, to_status, note, actor_type, actor_id) VALUES ($1,NULL,$2,$3,'customer',$4)`,
        [orderId, status, input.payment_method === 'upi' ? 'Waiting for UPI payment' : online ? 'Waiting for online payment' : 'Cash on Delivery order placed', userId]);
      if (!online) {
        await notifyUser(tx, userId, 'order_update', 'Order placed', `Your order ${orderNo} has been placed. Total ₹${total}.`, { order_id: orderId });
      }
      return { orderId, replay: false };
    });
  } catch (e: any) {
    // Two requests with the same key racing past the user lock is impossible, but keep the unique index as a backstop.
    if (e?.code === '23505' && String(e.constraint).includes('idempotency') || (e?.code === '23505' && String(e.detail ?? '').includes('idempotency_key'))) {
      const r = await ctx.db.query('SELECT id FROM orders WHERE user_id=$1 AND idempotency_key=$2', [userId, input.idempotency_key]);
      if (r.rowCount) return { orderId: r.rows[0].id, replay: true };
    }
    throw e;
  }
}

// ------------------------------------------------------------------ reading
export async function getOrderDetail(q: Queryable, orderId: string, userId?: string) {
  const o = await q.query('SELECT * FROM orders WHERE id=$1' + (userId ? ' AND user_id=$2' : ''), userId ? [orderId, userId] : [orderId]);
  if (!o.rowCount) throw notFound('Order not found');
  const order = o.rows[0];
  const [items, hist, pay, refunds] = await Promise.all([
    q.query('SELECT * FROM order_items WHERE order_id=$1 ORDER BY name', [orderId]),
    q.query('SELECT from_status, to_status, note, actor_type, created_at FROM order_status_history WHERE order_id=$1 ORDER BY id', [orderId]),
    q.query('SELECT id, provider, provider_order_id, provider_payment_id, amount, status, method, mode, claimed_utr, claimed_at, verified_at, created_at FROM payments WHERE order_id=$1 ORDER BY created_at', [orderId]),
    q.query('SELECT id, amount, status, reason, created_at FROM refunds WHERE order_id=$1 ORDER BY created_at', [orderId]),
  ]);
  const flow = order.fulfilment_type === 'delivery' ? DELIVERY_FLOW : PICKUP_FLOW;
  const reached = new Set<string>(hist.rows.map((h) => h.to_status));
  const terminalBad = ['cancelled', 'rejected', 'refund_pending', 'refunded'].includes(order.status);
  const timeline = flow.map((s) => ({ status: s, label: STATUS_LABELS[s], done: reached.has(s), current: order.status === s }));
  return {
    id: order.id, order_no: order.order_no, status: order.status, status_label: STATUS_LABELS[order.status as OrderStatus],
    fulfilment_type: order.fulfilment_type, payment_method: order.payment_method, payment_status: order.payment_status,
    placed_at: order.placed_at, updated_at: order.updated_at, customer_name: order.customer_name, customer_phone: order.customer_phone,
    address: order.address_snapshot, customer_note: order.customer_note, cancel_reason: order.cancel_reason, payment_expires_at: order.payment_expires_at,
    items: items.rows.map((i) => ({ id: i.id, product_id: i.product_id, sku: i.sku, name: i.name, brand: i.brand, unit: i.unit, pack_size: i.pack_size, image_url: i.image_url, mrp: i.mrp, unit_price: i.unit_price, qty: i.qty, line_total: i.line_total, net_total: i.net_total, tax_rate: i.tax_rate })),
    totals: {
      mrp_total: order.mrp_total, subtotal: order.subtotal, coupon_code: order.coupon_code, coupon_discount: order.coupon_discount, first_order_discount: order.first_order_discount,
      coins_redeemed: order.coins_redeemed, coin_discount: order.coin_discount, delivery_fee: order.delivery_fee, tax_included: order.tax_included, total: order.total,
    },
    delivery: { distance_km: order.distance_km, method: order.distance_method, zone: order.zone_name, rule: order.delivery_fee_rule },
    coins: { redeemed: order.coins_redeemed, to_earn: order.coins_to_earn, credited: order.coins_credited_at !== null },
    history: hist.rows.map((h) => ({ ...h, label: STATUS_LABELS[h.to_status as OrderStatus] })),
    timeline: terminalBad ? timeline.filter((t) => t.done) : timeline,
    payments: pay.rows, refunds: refunds.rows,
    can_cancel: customerCanCancel(order.status, order.payment_status),
    admin_next: adminNextStatuses(order.status, order.fulfilment_type),
  };
}

export async function listUserOrders(q: Queryable, userId: string, limit: number) {
  const { rows } = await q.query(
    `SELECT o.id, o.order_no, o.status, o.fulfilment_type, o.payment_method, o.payment_status, o.total, o.placed_at,
            (SELECT count(*)::int FROM order_items i WHERE i.order_id=o.id) AS item_count,
            (SELECT string_agg(name, ', ' ORDER BY name) FROM (SELECT name FROM order_items WHERE order_id=o.id ORDER BY name LIMIT 3) t) AS preview
       FROM orders o WHERE o.user_id=$1 AND (o.status <> 'pending_payment' OR o.payment_expires_at > now() OR o.payment_status = 'verifying')
       ORDER BY o.placed_at DESC LIMIT $2`, [userId, limit]);
  return rows.map((r) => ({ ...r, status_label: STATUS_LABELS[r.status as OrderStatus] }));
}

// ------------------------------------------------------------------ state transitions
type Actor = { type: 'admin' | 'customer' | 'system' | 'payment'; id?: string | null };

async function history(tx: Tx, orderId: string, from: string | null, to: string, actor: Actor, note?: string | null) {
  await tx.query('INSERT INTO order_status_history (order_id, from_status, to_status, note, actor_type, actor_id) VALUES ($1,$2,$3,$4,$5,$6)', [orderId, from, to, note ?? null, actor.type, actor.id ?? null]);
}

/** Undo everything an unfulfilled order holds: stock, coins, coupon, and (if paid) queue a refund. */
export async function unwindOrder(tx: Tx, order: any, finalStatus: 'cancelled' | 'rejected', reason: string, actor: Actor, coinExpiryDays: number): Promise<{ refundId: string | null }> {
  await releaseStock(tx, order.id, `Order ${finalStatus}`);
  if (order.coins_redeemed > 0) {
    await postLedger(tx, { userId: order.user_id, type: 'redeem_refund', coins: order.coins_redeemed, ref: `order:${order.id}:redeem_refund`, orderId: order.id, note: `Returned from ${finalStatus} order ${order.order_no}`, expiryDays: coinExpiryDays });
  }
  const rel = await tx.query(`UPDATE coupon_redemptions SET status='released' WHERE order_id=$1 AND status='active' RETURNING coupon_id`, [order.id]);
  for (const r of rel.rows) await tx.query('UPDATE coupons SET used_count = GREATEST(used_count - 1, 0) WHERE id=$1', [r.coupon_id]);

  let refundId: string | null = null;
  await tx.query(`UPDATE orders SET cancel_reason=$2, cancelled_by=$3 WHERE id=$1`, [order.id, reason, actor.type]);
  await history(tx, order.id, order.status, finalStatus, actor, reason);
  if (order.payment_status === 'paid') {
    const p = await tx.query(`SELECT id FROM payments WHERE order_id=$1 AND is_primary AND status='paid' LIMIT 1`, [order.id]);
    if (p.rowCount) {
      const r = await tx.query(`INSERT INTO refunds (payment_id, order_id, amount, reason) VALUES ($1,$2,$3,$4) RETURNING id`, [p.rows[0].id, order.id, order.total, `Order ${finalStatus}: ${reason}`]);
      refundId = r.rows[0].id;
    }
    await tx.query(`UPDATE orders SET status='refund_pending', payment_status='refund_pending' WHERE id=$1`, [order.id]);
    await history(tx, order.id, finalStatus, 'refund_pending', { type: 'system' }, 'Refund to original payment method initiated');
  } else {
    await tx.query(`UPDATE orders SET status=$2, payment_status=CASE WHEN payment_method<>'cod' THEN 'failed' ELSE payment_status END WHERE id=$1`, [order.id, finalStatus]);
    await tx.query(`UPDATE payments SET status='failed', failure_reason=COALESCE(failure_reason,'Order cancelled before payment') WHERE order_id=$1 AND status IN ('created','pending')`, [order.id]);
  }
  const verb = finalStatus === 'rejected' ? 'could not be accepted' : 'has been cancelled';
  await notifyUser(tx, order.user_id, 'order_update', finalStatus === 'rejected' ? 'Order rejected' : 'Order cancelled',
    `Your order ${order.order_no} ${verb}. ${reason}${refundId ? ' Your payment will be refunded.' : ''}`, { order_id: order.id });
  return { refundId };
}

export async function transitionOrder(ctx: AppCtx, orderId: string, to: OrderStatus, actor: Actor, opts: { note?: string; reason?: string; ip?: string | null } = {}): Promise<{ refundId: string | null }> {
  return withTx(ctx.db, async (tx) => {
    const r = await tx.query('SELECT * FROM orders WHERE id=$1 FOR UPDATE', [orderId]);
    if (!r.rowCount) throw notFound('Order not found');
    const order = r.rows[0];
    const from = order.status as OrderStatus;
    const settings = await loadSettings(tx);

    let allowed: OrderStatus[];
    if (actor.type === 'customer') {
      if (order.user_id !== actor.id) throw notFound('Order not found');
      allowed = customerCanCancel(from, order.payment_status) ? ['cancelled'] : [];
    } else if (actor.type === 'system' || actor.type === 'payment') {
      allowed = from === 'pending_payment' ? ['cancelled'] : [];
    } else {
      allowed = adminNextStatuses(from, order.fulfilment_type);
    }
    if (!allowed.includes(to)) throw conflict('INVALID_TRANSITION', `Cannot change order from "${STATUS_LABELS[from]?.en ?? from}" to "${STATUS_LABELS[to].en}"`, { from, to, allowed });

    if (to === 'cancelled' || to === 'rejected') {
      const reason = (opts.reason ?? '').trim();
      if (reason.length < 3) throw new AppError(400, 'REASON_REQUIRED', 'Please give a reason for cancelling / rejecting this order');
      const res = await unwindOrder(tx, order, to, reason, actor, settings.coins.expiry_days);
      if (actor.type === 'admin') await audit(tx, { actorType: 'admin', actorId: actor.id, action: `order.${to}`, entity: 'order', entityId: orderId, before: { status: from }, after: { status: to, reason }, ip: opts.ip });
      return res;
    }

    await tx.query('UPDATE orders SET status=$2 WHERE id=$1', [orderId, to]);
    await history(tx, orderId, from, to, actor, opts.note);

    if (to === 'delivered' || to === 'collected') {
      await fulfilStock(tx, orderId);
      if (order.payment_method === 'cod') await tx.query(`UPDATE orders SET payment_status='cod_collected' WHERE id=$1`, [orderId]);
      if (order.coins_to_earn > 0 && !order.coins_credited_at) {
        await postLedger(tx, { userId: order.user_id, type: 'earn', coins: order.coins_to_earn, ref: `order:${orderId}:earn`, orderId, note: `Earned on order ${order.order_no}`, expiryDays: settings.coins.expiry_days });
        await tx.query('UPDATE orders SET coins_credited_at = now() WHERE id=$1', [orderId]);
      }
    }
    const msgs: Partial<Record<OrderStatus, [string, string]>> = {
      accepted: ['Order accepted', `Your order ${order.order_no} has been accepted.`],
      packing: ['Packing your order', `We are packing order ${order.order_no}.`],
      ready_for_dispatch: ['Ready for dispatch', `Order ${order.order_no} is packed and ready to be dispatched.`],
      out_for_delivery: ['Out for delivery', `Order ${order.order_no} is on its way to you.`],
      delivered: ['Order delivered', `Order ${order.order_no} has been delivered.${order.coins_to_earn ? ` You earned ${order.coins_to_earn} coins.` : ''}`],
      ready_for_pickup: ['Ready for pickup', `Order ${order.order_no} is ready. Show the order number at the counter.`],
      collected: ['Order collected', `Thank you! Order ${order.order_no} was collected.${order.coins_to_earn ? ` You earned ${order.coins_to_earn} coins.` : ''}`],
    };
    const m = msgs[to];
    if (m && settings.notifications.order_updates) await notifyUser(tx, order.user_id, 'order_update', m[0], m[1], { order_id: orderId });
    if (actor.type === 'admin') await audit(tx, { actorType: 'admin', actorId: actor.id, action: `order.status`, entity: 'order', entityId: orderId, before: { status: from }, after: { status: to }, ip: opts.ip });
    return { refundId: null };
  });
}

/** Cancel orders whose online payment window ended. Returns how many were cancelled. */
export async function expireUnpaidOrders(ctx: AppCtx): Promise<number> {
  const due = await ctx.db.query(`SELECT id FROM orders WHERE status='pending_payment' AND payment_expires_at <= now() ORDER BY payment_expires_at LIMIT 100`);
  let n = 0;
  for (const row of due.rows) {
    try {
      await transitionOrder(ctx, row.id, 'cancelled', { type: 'system' }, { reason: 'Online payment was not completed in time' });
      n++;
    } catch (e) {
      if (!(e instanceof AppError && e.code === 'INVALID_TRANSITION')) throw e; // already moved on (paid at the last second)
    }
  }
  return n;
}

export { OPEN_STATUSES };
