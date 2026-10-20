import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { RouteDeps } from '../../app.js';
import { parse, uuid, rupees, pageParams } from '../../lib/validate.js';
import { notFound } from '../../lib/errors.js';
import { getOrderDetail, transitionOrder, STATUS_LABELS, type OrderStatus } from '../../services/orders.js';
import { adminRefund } from '../../services/payments.js';
import { loadSettings } from '../../services/settings.js';

const STATUSES = Object.keys(STATUS_LABELS) as [OrderStatus, ...OrderStatus[]];
const esc = (v: unknown) => String(v ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]!));
const inr = (v: unknown) => '₹' + Number(v).toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

export async function adminOrderRoutes(app: FastifyInstance, { ctx, requireAdmin }: RouteDeps) {
  const db = ctx.db;
  const read = { preHandler: requireAdmin('orders:read') };
  const write = { preHandler: requireAdmin('orders:write') };

  app.get('/orders', read, async (req) => {
    const q = parse(pageParams.extend({
      status: z.enum(STATUSES).optional(), fulfilment: z.enum(['delivery', 'pickup']).optional(), payment_method: z.enum(['cod', 'online']).optional(),
      q: z.string().trim().max(40).optional(), from: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(), to: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(), include_unpaid: z.coerce.boolean().optional(),
    }), req.query);
    const args: unknown[] = []; const w: string[] = [];
    const add = (sql: string, v: unknown) => { args.push(v); w.push(sql.replace('?', `$${args.length}`)); };
    if (q.status) add('o.status = ?', q.status); else if (!q.include_unpaid) w.push(`o.status <> 'pending_payment'`);
    if (q.fulfilment) add('o.fulfilment_type = ?', q.fulfilment);
    if (q.payment_method) add('o.payment_method = ?', q.payment_method);
    if (q.q) { args.push(`%${q.q.replace(/[\\%_]/g, (m) => '\\' + m)}%`); w.push(`(o.order_no ILIKE $${args.length} OR o.customer_phone ILIKE $${args.length} OR o.customer_name ILIKE $${args.length})`); }
    if (q.from) add(`(o.placed_at AT TIME ZONE 'Asia/Kolkata')::date >= ?::date`, q.from);
    if (q.to) add(`(o.placed_at AT TIME ZONE 'Asia/Kolkata')::date <= ?::date`, q.to);
    const where = w.length ? w.join(' AND ') : 'TRUE';
    const total = (await db.query(`SELECT count(*)::int n FROM orders o WHERE ${where}`, args)).rows[0].n;
    const rows = (await db.query(`SELECT o.id, o.order_no, o.status, o.fulfilment_type, o.payment_method, o.payment_status, o.customer_name, o.customer_phone, o.total, o.delivery_fee, o.placed_at,
        (SELECT COALESCE(SUM(qty),0)::int FROM order_items i WHERE i.order_id=o.id) AS item_count FROM orders o WHERE ${where} ORDER BY o.placed_at DESC LIMIT ${q.limit} OFFSET ${(q.page - 1) * q.limit}`, args)).rows;
    return { items: rows.map((r) => ({ ...r, status_label: STATUS_LABELS[r.status as OrderStatus] })), total, page: q.page, limit: q.limit };
  });

  app.get('/orders/:id', read, async (req) => {
    const { id } = parse(z.object({ id: uuid }), req.params);
    return { order: await getOrderDetail(db, id) };
  });

  app.post('/orders/:id/status', write, async (req) => {
    const { id } = parse(z.object({ id: uuid }), req.params);
    const b = parse(z.object({ status: z.enum(STATUSES), note: z.string().trim().max(300).optional(), reason: z.string().trim().max(300).optional() }), req.body);
    await transitionOrder(ctx, id, b.status, { type: 'admin', id: req.admin!.id }, { note: b.note, reason: b.reason, ip: req.ip });
    return { order: await getOrderDetail(db, id) };
  });

  app.post('/orders/:id/refund', { preHandler: requireAdmin('refunds:write') }, async (req) => {
    const { id } = parse(z.object({ id: uuid }), req.params);
    const b = parse(z.object({ amount: rupees.optional(), reason: z.string().trim().min(3).max(300) }), req.body);
    await adminRefund(ctx, id, req.admin!.id, b.amount, b.reason, req.ip);
    return { order: await getOrderDetail(db, id) };
  });

  /** Mark cash collected for a COD order (only meaningful once delivered/collected). */
  app.post('/orders/:id/cod-collected', write, async (req) => {
    const { id } = parse(z.object({ id: uuid }), req.params);
    const r = await db.query(`UPDATE orders SET payment_status='cod_collected' WHERE id=$1 AND payment_method='cod' AND payment_status='cod_pending' AND status IN ('delivered','collected') RETURNING id`, [id]);
    if (!r.rowCount) throw notFound('No COD order awaiting cash collection with that id (it must be delivered / collected first)');
    return { order: await getOrderDetail(db, id) };
  });

  /** Printable invoice (A4 / thermal-friendly). Uses the totals and delivery data frozen on the order. */
  app.get('/orders/:id/invoice', read, async (req, reply) => {
    const { id } = parse(z.object({ id: uuid }), req.params);
    const o = await getOrderDetail(db, id); const s = (await loadSettings(db)).store;
    const addr: any = o.address ?? {};
    const rows = o.items.map((i: any, n: number) => `<tr><td>${n + 1}</td><td>${esc(i.name)}${i.pack_size ? ` <small>(${esc(i.pack_size)})</small>` : ''}<br><small>SKU ${esc(i.sku)}</small></td><td class=r>${inr(i.unit_price)}</td><td class=r>${i.qty}</td><td class=r>${inr(i.line_total)}</td></tr>`).join('');
    const t: any = o.totals;
    const line = (label: string, v: unknown, neg = false) => Number(v) ? `<tr><td colspan=4 class=r>${label}</td><td class=r>${neg ? '−' : ''}${inr(v)}</td></tr>` : '';
    const html = `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Invoice ${esc(o.order_no)}</title>
<style>body{font:14px/1.45 system-ui,sans-serif;color:#111;max-width:760px;margin:24px auto;padding:0 16px}h1{font-size:20px;margin:0}table{width:100%;border-collapse:collapse;margin-top:12px}th,td{padding:6px 8px;border-bottom:1px solid #ddd;text-align:left;vertical-align:top}.r{text-align:right}small{color:#555}.tot td{font-weight:700;border-top:2px solid #111}.hdr{display:flex;justify-content:space-between;gap:16px;flex-wrap:wrap}.btn{margin:16px 0;padding:8px 14px}@media print{.btn{display:none}body{margin:0}}</style></head><body>
<button class="btn" onclick="window.print()">Print</button>
<div class="hdr"><div><h1>${esc(s.name_en)}</h1><div>${esc(s.name_hi)}</div><div>${esc(s.address_en)}</div><div>Phone: ${esc(s.phone)}</div></div>
<div><strong>Invoice / Order ${esc(o.order_no)}</strong><br>Date: ${esc(new Date(o.placed_at as any).toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' }))}<br>Status: ${esc(o.status_label.en)}<br>Payment: ${o.payment_method === 'cod' ? 'Cash on delivery' : 'Online'} (${esc(o.payment_status)})<br>${o.fulfilment_type === 'pickup' ? 'Store pickup' : 'Home delivery'}</div></div>
<p><strong>Customer:</strong> ${esc(o.customer_name ?? '')} ${esc(o.customer_phone)}<br>${o.fulfilment_type === 'delivery' ? `<strong>Deliver to:</strong> ${esc([addr.line1, addr.line2, addr.landmark, addr.city, addr.pincode].filter(Boolean).join(', '))}` : ''}</p>
<table><thead><tr><th>#</th><th>Item</th><th class=r>Rate</th><th class=r>Qty</th><th class=r>Amount</th></tr></thead><tbody>${rows}
${line('Items total', t.subtotal)}${line(`Coupon ${esc(t.coupon_code ?? '')}`, t.coupon_discount, true)}${line('First-order discount', t.first_order_discount, true)}${line(`Coins used (${t.coins_redeemed})`, t.coin_discount, true)}
${o.fulfilment_type === 'delivery' ? `<tr><td colspan=4 class=r>Delivery fee${o.delivery.distance_km != null ? ` <small>(${esc(o.delivery.distance_km)} km${o.delivery.rule ? ', ' + esc(o.delivery.rule) : ''})</small>` : ''}</td><td class=r>${inr(t.delivery_fee)}</td></tr>` : ''}
<tr class=tot><td colspan=4 class=r>Total payable</td><td class=r>${inr(t.total)}</td></tr>${Number(t.tax_included) ? `<tr><td colspan=4 class=r><small>Includes tax</small></td><td class=r><small>${inr(t.tax_included)}</small></td></tr>` : ''}</tbody></table>
<p><small>Prices are inclusive of applicable taxes. Thank you for shopping with us.</small></p></body></html>`;
    reply.header('Content-Type', 'text/html; charset=utf-8').header('Cache-Control', 'no-store').header('Content-Security-Policy', "default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; img-src data:");
    return reply.send(html);
  });
}
