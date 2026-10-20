import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { RouteDeps } from '../../app.js';
import { parse, uuid, rupees, pageParams } from '../../lib/validate.js';
import { AppError, conflict, notFound } from '../../lib/errors.js';
import { hashPassword } from '../../lib/crypto.js';
import { audit } from '../../lib/audit.js';
import { withTx } from '../../db/pool.js';
import { adminLogin, publicAdmin, PERMISSIONS, type Permission } from '../../services/auth.js';
import { loadSettings, saveSetting, settingsSchemas, SETTING_KEYS, storeOpenState, type SettingKey } from '../../services/settings.js';
import { calculateDeliveryFee, resolveDistance } from '../../services/delivery.js';
import { resolveZone } from '../../services/pricing.js';
import { toPaise, fromPaise } from '../../lib/money.js';

const SETTING_PERMISSION: Record<SettingKey, Permission> = {
  store: 'settings:write', policies: 'settings:write', notifications: 'settings:write', delivery: 'delivery:write', order: 'delivery:write', coins: 'coins:write', first_order: 'coins:write',
};
const ISTART = `(date_trunc('day', now() AT TIME ZONE 'Asia/Kolkata') AT TIME ZONE 'Asia/Kolkata')`;
const LIVE = `('placed','accepted','packing','ready_for_dispatch','out_for_delivery','delivered','ready_for_pickup','collected')`;

export async function adminCoreRoutes(app: FastifyInstance, { ctx, requireAdmin }: RouteDeps) {
  const db = ctx.db;
  const any = { preHandler: requireAdmin() };
  const need = (p: Permission) => ({ preHandler: requireAdmin(p) });

  app.post('/login', { config: { rateLimit: { max: ctx.config.NODE_ENV === 'test' ? 100000 : 10, timeWindow: '1 minute' } } }, async (req) => {
    const b = parse(z.object({ email: z.string().email().max(120), password: z.string().min(1).max(200) }), req.body);
    return adminLogin(db, ctx.config, b.email, b.password, req.ip);
  });
  app.get('/me', any, async (req) => ({ admin: publicAdmin(req.admin) }));
  app.post('/me/password', any, async (req) => {
    const b = parse(z.object({ current: z.string().min(1), next: z.string().min(10, 'Use at least 10 characters').max(100) }), req.body);
    const { verifyPassword } = await import('../../lib/crypto.js');
    const row = (await db.query('SELECT password_hash FROM admin_users WHERE id=$1', [req.admin!.id])).rows[0];
    if (!(await verifyPassword(b.current, row.password_hash))) throw new AppError(400, 'WRONG_PASSWORD', 'Current password is incorrect');
    await db.query('UPDATE admin_users SET password_hash=$2 WHERE id=$1', [req.admin!.id, await hashPassword(b.next)]);
    await audit(db, { actorType: 'admin', actorId: req.admin!.id, action: 'admin.password_changed', entity: 'admin', entityId: req.admin!.id, ip: req.ip });
    return { ok: true };
  });

  // ---------------------------------------------------------------- dashboard
  app.get('/dashboard', need('orders:read'), async () => {
    const [today, status, payments, low, top, series, newCustomers] = await Promise.all([
      db.query(`SELECT count(*)::int AS orders,
          COALESCE(SUM(subtotal + delivery_fee) FILTER (WHERE status IN ${LIVE}),0) AS gross_sales,
          COALESCE(SUM(coupon_discount + first_order_discount + coin_discount) FILTER (WHERE status IN ${LIVE}),0) AS discounts,
          COALESCE(SUM(total) FILTER (WHERE status IN ${LIVE}),0) AS billed,
          COUNT(*) FILTER (WHERE status IN ${LIVE})::int AS live_orders
        FROM orders WHERE placed_at >= ${ISTART} AND status <> 'pending_payment'`),
      db.query(`SELECT status, count(*)::int n FROM orders WHERE status <> 'pending_payment' AND (placed_at >= ${ISTART} OR status IN ('placed','accepted','packing','ready_for_dispatch','out_for_delivery','ready_for_pickup','refund_pending')) GROUP BY status`),
      db.query(`SELECT payment_method, payment_status, count(*)::int n, COALESCE(SUM(total),0) AS amount FROM orders WHERE placed_at >= ${ISTART} AND status IN ${LIVE} GROUP BY 1,2 ORDER BY 1,2`),
      db.query(`SELECT id, sku, name, stock_qty, reserved_qty, low_stock_threshold, (stock_qty - reserved_qty) AS available FROM products WHERE is_active AND stock_qty - reserved_qty <= low_stock_threshold ORDER BY (stock_qty - reserved_qty), name LIMIT 15`),
      db.query(`SELECT oi.product_id, oi.name, oi.sku, SUM(oi.qty)::int AS qty, SUM(oi.net_total) AS revenue FROM order_items oi JOIN orders o ON o.id=oi.order_id
                WHERE o.status IN ('delivered','collected') AND o.placed_at > now() - interval '30 days' GROUP BY oi.product_id, oi.name, oi.sku ORDER BY qty DESC LIMIT 10`),
      db.query(`SELECT to_char(d.day, 'YYYY-MM-DD') AS day, COALESCE(SUM(o.total) FILTER (WHERE o.status IN ${LIVE}),0) AS sales, COUNT(o.id) FILTER (WHERE o.status IN ${LIVE})::int AS orders
                FROM generate_series((now() AT TIME ZONE 'Asia/Kolkata')::date - 6, (now() AT TIME ZONE 'Asia/Kolkata')::date, interval '1 day') AS d(day)
                LEFT JOIN orders o ON (o.placed_at AT TIME ZONE 'Asia/Kolkata')::date = d.day::date GROUP BY d.day ORDER BY d.day`),
      db.query(`SELECT count(*)::int n FROM users WHERE created_at >= ${ISTART}`),
    ]);
    const st: Record<string, number> = Object.fromEntries(status.rows.map((r) => [r.status, r.n]));
    const t = today.rows[0];
    const refunds = (await db.query(`SELECT COALESCE(SUM(amount),0) AS s FROM refunds WHERE status='processed' AND created_at >= ${ISTART}`)).rows[0].s;
    const net = toPaise(t.billed) - toPaise(refunds);
    return {
      today: {
        orders: t.orders, live_orders: t.live_orders, new_customers: newCustomers.rows[0].n,
        gross_sales: t.gross_sales, discounts: t.discounts, net_sales: fromPaise(Math.max(net, 0)), refunds_today: refunds,
        definitions: { gross_sales: 'Item value at selling price + delivery fees, before any coupon / coin discounts, for today’s orders that were not cancelled or rejected.', net_sales: 'What customers are billed after discounts and coins, minus refunds paid out today.' },
      },
      counts: { new: st.placed ?? 0, in_progress: (st.accepted ?? 0) + (st.packing ?? 0) + (st.ready_for_dispatch ?? 0) + (st.out_for_delivery ?? 0) + (st.ready_for_pickup ?? 0), completed_today: (st.delivered ?? 0) + (st.collected ?? 0), cancelled_today: (st.cancelled ?? 0) + (st.rejected ?? 0), refund_pending: st.refund_pending ?? 0, refunded_today: st.refunded ?? 0 },
      payment_breakdown: payments.rows, low_stock: low.rows, top_products: top.rows, last_7_days: series.rows,
    };
  });

  // ---------------------------------------------------------------- settings
  app.get('/settings', any, async () => ({ settings: await loadSettings(db) }));
  app.put('/settings/:key', { preHandler: requireAdmin() }, async (req) => {
    const { key } = parse(z.object({ key: z.enum(SETTING_KEYS as [SettingKey, ...SettingKey[]]) }), req.params);
    const { hasPermission } = await import('../../services/auth.js');
    if (!hasPermission(req.admin!, SETTING_PERMISSION[key])) throw new AppError(403, 'FORBIDDEN', `Your role does not allow changing "${key}" settings`);
    const before = (await loadSettings(db))[key];
    const body = parse(settingsSchemas[key] as any, req.body);
    if (key === 'coins' || key === 'first_order' || key === 'delivery' || key === 'order') { /* shape validated by schema */ }
    const saved = await saveSetting(db, key, body, req.admin!.id);
    await audit(db, { actorType: 'admin', actorId: req.admin!.id, action: `settings.${key}`, entity: 'settings', entityId: key, before, after: saved, ip: req.ip });
    return { settings: await loadSettings(db) };
  });
  app.get('/system', need('settings:write'), async () => ({
    payments: { provider: ctx.payments.name, mode: ctx.payments.mode, live: ctx.payments.mode === 'live', keys_configured: ctx.config.PAYMENT_PROVIDER === 'razorpay' ? !!(ctx.config.RAZORPAY_KEY_ID && ctx.config.RAZORPAY_KEY_SECRET) : false, webhook_secret_configured: !!ctx.config.RAZORPAY_WEBHOOK_SECRET, webhook_url_path: '/v1/webhooks/payments',
      note: ctx.config.PAYMENT_PROVIDER === 'mock' ? 'MOCK payments (development only). Real Razorpay keys are not configured.' : ctx.payments.mode === 'sandbox' ? 'Razorpay TEST mode. No real money moves.' : 'LIVE payments enabled.' },
    otp: { provider: ctx.otp.name, dev_echo: ctx.otp.devEcho, note: ctx.otp.name === 'mock' ? 'MOCK OTP (development only). Customers cannot receive real SMS.' : 'MSG91 configured.' },
    routing: { provider: ctx.config.ROUTING_PROVIDER, configured: !!ctx.routing },
    push: { configured: ctx.push.configured }, storage: { driver: ctx.config.STORAGE_DRIVER }, environment: ctx.config.NODE_ENV,
    note: 'Secrets are set in the server environment and are never shown here or sent to the apps.',
  }));

  // ---------------------------------------------------------------- delivery zones + preview
  const zoneBody = z.object({
    name: z.string().trim().min(2).max(60), name_hi: z.string().trim().max(60).nullish(), pincodes: z.array(z.string().regex(/^\d{6}$/)).max(50).default([]),
    fee_mode: z.enum(['base', 'far', 'custom']).default('base'), custom_fee: rupees.nullish(), min_order: rupees.nullish(), sort_order: z.number().int().default(0), is_active: z.boolean().default(true),
  }).refine((z) => z.fee_mode !== 'custom' || z.custom_fee != null, { message: 'Enter the custom delivery fee', path: ['custom_fee'] });
  app.get('/zones', need('delivery:write'), async () => ({ zones: (await db.query('SELECT * FROM delivery_zones ORDER BY sort_order, name')).rows }));
  app.post('/zones', need('delivery:write'), async (req) => {
    const b = parse(zoneBody, req.body);
    const r = await db.query(`INSERT INTO delivery_zones (name, name_hi, pincodes, fee_mode, custom_fee, min_order, sort_order, is_active) VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING *`,
      [b.name, b.name_hi ?? null, b.pincodes, b.fee_mode, b.fee_mode === 'custom' ? b.custom_fee : null, b.min_order ?? null, b.sort_order, b.is_active]);
    await audit(db, { actorType: 'admin', actorId: req.admin!.id, action: 'zone.create', entity: 'zone', entityId: r.rows[0].id, after: r.rows[0], ip: req.ip });
    return { zone: r.rows[0] };
  });
  app.put('/zones/:id', need('delivery:write'), async (req) => {
    const { id } = parse(z.object({ id: uuid }), req.params); const b = parse(zoneBody, req.body);
    const before = (await db.query('SELECT * FROM delivery_zones WHERE id=$1', [id])).rows[0]; if (!before) throw notFound('Zone not found');
    const r = await db.query(`UPDATE delivery_zones SET name=$2, name_hi=$3, pincodes=$4, fee_mode=$5, custom_fee=$6, min_order=$7, sort_order=$8, is_active=$9 WHERE id=$1 RETURNING *`,
      [id, b.name, b.name_hi ?? null, b.pincodes, b.fee_mode, b.fee_mode === 'custom' ? b.custom_fee : null, b.min_order ?? null, b.sort_order, b.is_active]);
    await audit(db, { actorType: 'admin', actorId: req.admin!.id, action: 'zone.update', entity: 'zone', entityId: id, before, after: r.rows[0], ip: req.ip });
    return { zone: r.rows[0] };
  });
  app.delete('/zones/:id', need('delivery:write'), async (req) => {
    const { id } = parse(z.object({ id: uuid }), req.params);
    const r = await db.query('DELETE FROM delivery_zones WHERE id=$1 RETURNING *', [id]); if (!r.rowCount) throw notFound('Zone not found');
    await audit(db, { actorType: 'admin', actorId: req.admin!.id, action: 'zone.delete', entity: 'zone', entityId: id, before: r.rows[0], ip: req.ip });
    return { ok: true };
  });

  /** "What would a customer be charged at this address?" using the live settings, routing provider and zones. */
  app.post('/delivery/preview', need('delivery:write'), async (req) => {
    const b = parse(z.object({ latitude: z.number().min(-90).max(90).nullish(), longitude: z.number().min(-180).max(180).nullish(), distance_km: z.number().min(0).max(500).nullish(), pincode: z.string().regex(/^\d{6}$/).nullish(), zone_id: uuid.nullish(), fulfilment: z.enum(['delivery', 'pickup']).default('delivery') }), req.body);
    const s = await loadSettings(db);
    const zone = await resolveZone(db, { id: null, latitude: b.latitude ?? null, longitude: b.longitude ?? null, zone_id: b.zone_id ?? null, pincode: b.pincode ?? null });
    const store = s.store.latitude !== null && s.store.longitude !== null ? { lat: s.store.latitude, lng: s.store.longitude } : null;
    let dist: Awaited<ReturnType<typeof resolveDistance>>;
    if (b.distance_km != null) dist = { km: b.distance_km, method: 'road_osrm' as const }; // manual "what if the distance is X km"
    else dist = await resolveDistance({ store, address: b.latitude != null && b.longitude != null ? { lat: b.latitude, lng: b.longitude } : null, settings: s.delivery, provider: ctx.routing });
    try {
      const q = calculateDeliveryFee({ fulfilment: b.fulfilment, distanceKm: dist.km, distanceMethod: b.distance_km != null ? 'none' : dist.method, zone, settings: s.delivery });
      return { ok: true, fee: fromPaise(q.fee_paise), rule: q.rule, distance_km: q.distance_km, method: b.distance_km != null ? 'manual_distance' : q.distance_method, zone: q.zone, distance_note: dist.km === null ? dist.reason : null };
    } catch (e) {
      if (e instanceof AppError) return { ok: false, error: { code: e.code, message: e.message }, distance_note: dist.km === null ? dist.reason : null };
      throw e;
    }
  });
  app.get('/store-status', any, async () => { const s = await loadSettings(db); return storeOpenState(s.store); });

  // ---------------------------------------------------------------- staff (owner only)
  const staffBody = z.object({
    email: z.string().email().max(120), name: z.string().trim().min(2).max(80), role: z.enum(['owner', 'manager', 'staff']),
    status: z.enum(['active', 'disabled']).default('active'), extra_permissions: z.array(z.enum(PERMISSIONS)).default([]), password: z.string().min(10, 'Use at least 10 characters').max(100).optional(),
  });
  const pubStaff = 'id, email, name, role, status, extra_permissions, last_login_at, created_at';
  app.get('/staff', need('staff:write'), async () => ({ staff: (await db.query(`SELECT ${pubStaff} FROM admin_users ORDER BY created_at`)).rows }));
  app.post('/staff', need('staff:write'), async (req) => {
    const b = parse(staffBody, req.body); if (!b.password) throw new AppError(400, 'VALIDATION_ERROR', 'password: Set a starting password (at least 10 characters)');
    const r = await db.query(`INSERT INTO admin_users (email, name, password_hash, role, status, extra_permissions) VALUES (lower($1),$2,$3,$4,$5,$6) RETURNING ${pubStaff}`, [b.email, b.name, await hashPassword(b.password), b.role, b.status, b.extra_permissions]);
    await audit(db, { actorType: 'admin', actorId: req.admin!.id, action: 'staff.create', entity: 'admin', entityId: r.rows[0].id, after: r.rows[0], ip: req.ip });
    return { staff: r.rows[0] };
  });
  app.put('/staff/:id', need('staff:write'), async (req) => {
    const { id } = parse(z.object({ id: uuid }), req.params); const b = parse(staffBody, req.body);
    return withTx(db, async (tx) => {
      const before = (await tx.query(`SELECT ${pubStaff} FROM admin_users WHERE id=$1 FOR UPDATE`, [id])).rows[0]; if (!before) throw notFound('Staff member not found');
      if (before.role === 'owner' && (b.role !== 'owner' || b.status !== 'active')) {
        const others = (await tx.query(`SELECT count(*)::int n FROM admin_users WHERE role='owner' AND status='active' AND id<>$1`, [id])).rows[0].n;
        if (others === 0) throw conflict('LAST_OWNER', 'There must always be at least one active owner.');
      }
      const r = await tx.query(`UPDATE admin_users SET email=lower($2), name=$3, role=$4, status=$5, extra_permissions=$6, password_hash=COALESCE($7,password_hash), failed_logins=0, locked_until=NULL WHERE id=$1 RETURNING ${pubStaff}`,
        [id, b.email, b.name, b.role, b.status, b.extra_permissions, b.password ? await hashPassword(b.password) : null]);
      await audit(tx, { actorType: 'admin', actorId: req.admin!.id, action: 'staff.update', entity: 'admin', entityId: id, before, after: r.rows[0], ip: req.ip });
      return { staff: r.rows[0] };
    });
  });

  // ---------------------------------------------------------------- audit log
  app.get('/audit-logs', need('audit:read'), async (req) => {
    const q = parse(z.object({ action: z.string().max(60).optional(), entity: z.string().max(40).optional(), before: z.coerce.number().int().optional(), limit: z.coerce.number().int().min(1).max(200).default(50) }), req.query);
    const { rows } = await db.query(`SELECT l.id, l.actor_type, l.actor_id, a.name AS actor_name, l.action, l.entity, l.entity_id, l.before, l.after, l.ip, l.created_at FROM audit_logs l LEFT JOIN admin_users a ON a.id = l.actor_id
      WHERE ($1::text IS NULL OR l.action ILIKE $1 || '%') AND ($2::text IS NULL OR l.entity=$2) AND ($3::bigint IS NULL OR l.id < $3) ORDER BY l.id DESC LIMIT $4`, [q.action ?? null, q.entity ?? null, q.before ?? null, q.limit]);
    return { logs: rows };
  });

  // ---------------------------------------------------------------- customers
  app.get('/customers', need('customers:read'), async (req) => {
    const q = parse(pageParams.extend({ q: z.string().trim().max(40).optional(), deletion: z.coerce.boolean().optional() }), req.query);
    const args: unknown[] = []; const where = [`u.status <> 'deleted'`];
    if (q.q) { args.push(`%${q.q.replace(/[\\%_]/g, (m) => '\\' + m)}%`); where.push(`(u.phone ILIKE $${args.length} OR u.name ILIKE $${args.length})`); }
    if (q.deletion) where.push('u.deletion_requested_at IS NOT NULL');
    const total = (await db.query(`SELECT count(*)::int n FROM users u WHERE ${where.join(' AND ')}`, args)).rows[0].n;
    const rows = (await db.query(`SELECT u.id, u.phone, u.name, u.status, u.created_at, u.deletion_requested_at, COALESCE(w.balance,0) AS coins,
        (SELECT count(*)::int FROM orders o WHERE o.user_id=u.id AND o.status IN ${LIVE}) AS orders, (SELECT COALESCE(SUM(total),0) FROM orders o WHERE o.user_id=u.id AND o.status IN ('delivered','collected')) AS spent
      FROM users u LEFT JOIN wallets w ON w.user_id=u.id WHERE ${where.join(' AND ')} ORDER BY u.created_at DESC LIMIT ${q.limit} OFFSET ${(q.page - 1) * q.limit}`, args)).rows;
    return { items: rows, total, page: q.page, limit: q.limit };
  });
  app.post('/customers/:id/block', need('customers:write'), async (req) => {
    const { id } = parse(z.object({ id: uuid }), req.params); const b = parse(z.object({ blocked: z.boolean(), reason: z.string().trim().min(3).max(200) }), req.body);
    const r = await db.query(`UPDATE users SET status=$2 WHERE id=$1 AND status <> 'deleted' RETURNING id, status`, [id, b.blocked ? 'blocked' : 'active']); if (!r.rowCount) throw notFound('Customer not found');
    if (b.blocked) await db.query('UPDATE refresh_tokens SET revoked_at=now() WHERE user_id=$1 AND revoked_at IS NULL', [id]);
    await audit(db, { actorType: 'admin', actorId: req.admin!.id, action: b.blocked ? 'customer.block' : 'customer.unblock', entity: 'user', entityId: id, after: { reason: b.reason }, ip: req.ip });
    return { customer: r.rows[0] };
  });
  /** Complete a customer's account-deletion request: personal data is removed; order/invoice records are kept (accounting), without a live account. */
  app.post('/customers/:id/delete', need('customers:write'), async (req) => {
    const { id } = parse(z.object({ id: uuid }), req.params);
    return withTx(db, async (tx) => {
      const u = (await tx.query('SELECT * FROM users WHERE id=$1 FOR UPDATE', [id])).rows[0]; if (!u || u.status === 'deleted') throw notFound('Customer not found');
      if (!u.deletion_requested_at) throw conflict('NOT_REQUESTED', 'The customer has not requested deletion.');
      const open = (await tx.query(`SELECT count(*)::int n FROM orders WHERE user_id=$1 AND status IN ('pending_payment','placed','accepted','packing','ready_for_dispatch','out_for_delivery','ready_for_pickup','refund_pending')`, [id])).rows[0].n;
      if (open) throw conflict('OPEN_ORDERS', 'This customer still has orders in progress.');
      await tx.query('DELETE FROM auth_otps WHERE phone=$1', [u.phone]);
      await tx.query('DELETE FROM refresh_tokens WHERE user_id=$1', [id]); await tx.query('DELETE FROM device_tokens WHERE user_id=$1', [id]); await tx.query('DELETE FROM notifications WHERE user_id=$1', [id]);
      await tx.query(`UPDATE addresses SET deleted_at=COALESCE(deleted_at, now()), is_default=false, full_name='Deleted', phone='9000000000', line1='Deleted', line2=NULL, landmark=NULL, latitude=NULL, longitude=NULL WHERE user_id=$1`, [id]);
      await tx.query(`UPDATE users SET status='deleted', deleted_at=now(), name=NULL, email=NULL, phone='deleted:'||id::text WHERE id=$1`, [id]);
      await audit(tx, { actorType: 'admin', actorId: req.admin!.id, action: 'customer.delete_processed', entity: 'user', entityId: id, ip: req.ip });
      return { ok: true };
    });
  });
}
