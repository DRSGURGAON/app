import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { RouteDeps } from '../app.js';
import { parse, uuid } from '../lib/validate.js';
import { AppError, conflict, notFound } from '../lib/errors.js';
import { withTx } from '../db/pool.js';
import { loadSettings } from '../services/settings.js';
import { listTransactions, walletSummary } from '../services/coins.js';
import { publicUser } from '../services/auth.js';
import { audit } from '../lib/audit.js';

const addressBody = z.object({
  label: z.string().trim().min(1).max(30).default('Home'),
  full_name: z.string().trim().min(2).max(80), phone: z.string().regex(/^[6-9]\d{9}$/, 'Enter a valid 10-digit mobile number'),
  line1: z.string().trim().min(3).max(200), line2: z.string().trim().max(200).nullish(), landmark: z.string().trim().max(120).nullish(),
  city: z.string().trim().min(2).max(60).default('Loharu'), state: z.string().trim().min(2).max(60).default('Haryana'),
  pincode: z.string().regex(/^[1-9]\d{5}$/, 'Enter a valid 6-digit PIN code'),
  latitude: z.number().min(-90).max(90).nullish(), longitude: z.number().min(-180).max(180).nullish(),
  zone_id: uuid.nullish(), is_default: z.boolean().default(false),
}).refine((a) => (a.latitude == null) === (a.longitude == null), { message: 'Latitude and longitude must be given together', path: ['latitude'] });

export async function customerRoutes(app: FastifyInstance, { ctx, requireUser }: RouteDeps) {
  const db = ctx.db;
  const auth = { preHandler: requireUser };

  app.get('/me', auth, async (req) => {
    const u = (await db.query('SELECT * FROM users WHERE id=$1', [req.userId])).rows[0];
    return { user: { ...publicUser(u), deletion_requested_at: u.deletion_requested_at } };
  });
  app.patch('/me', auth, async (req) => {
    const b = parse(z.object({ name: z.string().trim().min(2).max(80).optional(), email: z.string().email().max(120).nullish(), language: z.enum(['en', 'hi']).optional() }), req.body);
    const u = (await db.query(`UPDATE users SET name=COALESCE($2,name), email=CASE WHEN $3::boolean THEN $4 ELSE email END, language=COALESCE($5,language) WHERE id=$1 RETURNING *`,
      [req.userId, b.name ?? null, b.email !== undefined, b.email ?? null, b.language ?? null])).rows[0];
    return { user: publicUser(u) };
  });

  // ---- addresses
  const addrCols = 'id, label, full_name, phone, line1, line2, landmark, city, state, pincode, latitude, longitude, zone_id, is_default';
  app.get('/addresses', auth, async (req) => ({ addresses: (await db.query(`SELECT ${addrCols} FROM addresses WHERE user_id=$1 AND deleted_at IS NULL ORDER BY is_default DESC, created_at DESC`, [req.userId])).rows }) );
  app.post('/addresses', auth, async (req) => {
    const b = parse(addressBody, req.body);
    return withTx(db, async (tx) => {
      const count = (await tx.query('SELECT count(*)::int n FROM addresses WHERE user_id=$1 AND deleted_at IS NULL', [req.userId])).rows[0].n;
      if (count >= 10) throw conflict('ADDRESS_LIMIT', 'You can save up to 10 addresses');
      const makeDefault = b.is_default || count === 0;
      if (makeDefault) await tx.query('UPDATE addresses SET is_default=false WHERE user_id=$1 AND is_default', [req.userId]);
      const r = await tx.query(`INSERT INTO addresses (user_id, label, full_name, phone, line1, line2, landmark, city, state, pincode, latitude, longitude, zone_id, is_default)
        VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14) RETURNING ${addrCols}`,
        [req.userId, b.label, b.full_name, b.phone, b.line1, b.line2 ?? null, b.landmark ?? null, b.city, b.state, b.pincode, b.latitude ?? null, b.longitude ?? null, b.zone_id ?? null, makeDefault]);
      return { address: r.rows[0] };
    });
  });
  app.put('/addresses/:id', auth, async (req) => {
    const { id } = parse(z.object({ id: uuid }), req.params); const b = parse(addressBody, req.body);
    return withTx(db, async (tx) => {
      if (b.is_default) await tx.query('UPDATE addresses SET is_default=false WHERE user_id=$1 AND is_default AND id<>$2', [req.userId, id]);
      const r = await tx.query(`UPDATE addresses SET label=$3, full_name=$4, phone=$5, line1=$6, line2=$7, landmark=$8, city=$9, state=$10, pincode=$11, latitude=$12, longitude=$13, zone_id=$14, is_default=$15
        WHERE id=$1 AND user_id=$2 AND deleted_at IS NULL RETURNING ${addrCols}`,
        [id, req.userId, b.label, b.full_name, b.phone, b.line1, b.line2 ?? null, b.landmark ?? null, b.city, b.state, b.pincode, b.latitude ?? null, b.longitude ?? null, b.zone_id ?? null, b.is_default]);
      if (!r.rowCount) throw notFound('Address not found');
      return { address: r.rows[0] };
    });
  });
  app.delete('/addresses/:id', auth, async (req) => {
    const { id } = parse(z.object({ id: uuid }), req.params);
    const r = await db.query(`UPDATE addresses SET deleted_at=now(), is_default=false WHERE id=$1 AND user_id=$2 AND deleted_at IS NULL RETURNING id`, [id, req.userId]);
    if (!r.rowCount) throw notFound('Address not found');
    return { ok: true };
  });

  // ---- wallet
  app.get('/wallet', auth, async (req) => {
    const s = await loadSettings(db);
    return { wallet: await walletSummary(db, req.userId!, s.coins), rules: { earn_coins_per_unit: s.coins.earn_coins_per_unit, earn_spend_unit: s.coins.earn_spend_unit, coin_value: s.coins.coin_value, max_redeem_coins_per_order: s.coins.max_redeem_coins_per_order, min_order_to_earn: s.coins.min_order_to_earn, min_order_to_redeem: s.coins.min_order_to_redeem, expiry_days: s.coins.expiry_days, earn_on_discounted_orders: s.coins.earn_on_discounted_orders } };
  });
  app.get('/wallet/transactions', auth, async (req) => {
    const q = parse(z.object({ limit: z.coerce.number().int().min(1).max(100).default(30), before: z.coerce.number().int().optional() }), req.query);
    return { transactions: await listTransactions(db, req.userId!, q.limit, q.before) };
  });

  // ---- notifications & push tokens
  app.get('/notifications', auth, async (req) => {
    const rows = (await db.query(`SELECT id, type, title, body, data, read_at, created_at FROM notifications WHERE user_id=$1 ORDER BY created_at DESC LIMIT 60`, [req.userId])).rows;
    const unread = (await db.query('SELECT count(*)::int n FROM notifications WHERE user_id=$1 AND read_at IS NULL', [req.userId])).rows[0].n;
    return { notifications: rows, unread };
  });
  app.post('/notifications/read-all', auth, async (req) => { await db.query('UPDATE notifications SET read_at=now() WHERE user_id=$1 AND read_at IS NULL', [req.userId]); return { ok: true }; });
  app.post('/notifications/:id/read', auth, async (req) => {
    const { id } = parse(z.object({ id: uuid }), req.params);
    await db.query('UPDATE notifications SET read_at=COALESCE(read_at, now()) WHERE id=$1 AND user_id=$2', [id, req.userId]); return { ok: true };
  });
  app.post('/devices', auth, async (req) => {
    const b = parse(z.object({ token: z.string().min(20).max(400), platform: z.string().max(20).default('android') }), req.body);
    await db.query(`INSERT INTO device_tokens (user_id, token, platform) VALUES ($1,$2,$3) ON CONFLICT (token) DO UPDATE SET user_id=EXCLUDED.user_id`, [req.userId, b.token, b.platform]);
    return { ok: true };
  });
  app.delete('/devices', auth, async (req) => {
    const b = parse(z.object({ token: z.string().min(20).max(400) }), req.body);
    await db.query('DELETE FROM device_tokens WHERE token=$1 AND user_id=$2', [b.token, req.userId]); return { ok: true };
  });

  // ---- account deletion request (store processes it from the admin panel; logging in again cancels it)
  app.post('/me/delete-request', auth, async (req) => {
    const open = (await db.query(`SELECT count(*)::int n FROM orders WHERE user_id=$1 AND status IN ('pending_payment','placed','accepted','packing','ready_for_dispatch','out_for_delivery','ready_for_pickup','refund_pending')`, [req.userId])).rows[0].n;
    if (open > 0) throw new AppError(409, 'OPEN_ORDERS', 'You have an order in progress. Please request deletion after it is completed.');
    await db.query('UPDATE users SET deletion_requested_at=COALESCE(deletion_requested_at, now()) WHERE id=$1', [req.userId]);
    await audit(db, { actorType: 'customer', actorId: req.userId, action: 'account.delete_requested', entity: 'user', entityId: req.userId });
    return { ok: true, message: 'Your deletion request has been received. The store will delete your account and personal data within 7 days. Logging in again cancels the request.' };
  });
  app.delete('/me/delete-request', auth, async (req) => { await db.query('UPDATE users SET deletion_requested_at=NULL WHERE id=$1', [req.userId]); return { ok: true }; });
}
