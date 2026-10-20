import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { RouteDeps } from '../../app.js';
import { parse, uuid, rupees, pageParams } from '../../lib/validate.js';
import { AppError, conflict, notFound } from '../../lib/errors.js';
import { audit } from '../../lib/audit.js';
import { withTx } from '../../db/pool.js';
import { postLedger, walletSummary, listTransactions } from '../../services/coins.js';
import { loadSettings } from '../../services/settings.js';
import { Storage } from '../../services/storage.js';
import { randomUUID } from 'node:crypto';

export async function adminOfferRoutes(app: FastifyInstance, { ctx, requireAdmin }: RouteDeps) {
  const db = ctx.db; const storage = new Storage(ctx.config);
  const offers = { preHandler: requireAdmin('offers:write') };

  // ---------------------------------------------------------------- coupons
  const couponBody = z.object({
    code: z.string().trim().toUpperCase().regex(/^[A-Z0-9_-]{3,20}$/, 'Use 3–20 letters, numbers, - or _'), title: z.string().trim().min(2).max(80), description: z.string().trim().max(300).nullish(),
    discount_type: z.enum(['percent', 'fixed']), discount_value: rupees, min_spend: rupees.default('0'), max_discount: rupees.nullish(),
    starts_at: z.coerce.date(), ends_at: z.coerce.date(), usage_limit: z.number().int().min(1).nullish(), per_user_limit: z.number().int().min(1).max(100).default(1),
    category_ids: z.array(uuid).default([]), product_ids: z.array(uuid).default([]), first_order_only: z.boolean().default(false), festival: z.string().trim().max(40).nullish(),
    is_public: z.boolean().default(false), is_active: z.boolean().default(true),
  }).refine((c) => c.ends_at > c.starts_at, { message: 'End must be after start', path: ['ends_at'] })
    .refine((c) => Number(c.discount_value) > 0, { message: 'Discount must be more than 0', path: ['discount_value'] })
    .refine((c) => c.discount_type !== 'percent' || Number(c.discount_value) <= 100, { message: 'Percent cannot exceed 100', path: ['discount_value'] });
  const cArgs = (b: z.infer<typeof couponBody>) => [b.code, b.title, b.description ?? null, b.discount_type, b.discount_value, b.min_spend, b.max_discount ?? null, b.starts_at, b.ends_at, b.usage_limit ?? null, b.per_user_limit, b.category_ids, b.product_ids, b.first_order_only, b.festival ?? null, b.is_public, b.is_active];

  app.get('/coupons', { preHandler: requireAdmin('catalog:read') }, async (req) => {
    const q = parse(pageParams, req.query);
    const total = (await db.query('SELECT count(*)::int n FROM coupons')).rows[0].n;
    const rows = (await db.query(`SELECT *, (is_active AND now() BETWEEN starts_at AND ends_at AND (usage_limit IS NULL OR used_count < usage_limit)) AS live FROM coupons ORDER BY created_at DESC LIMIT ${q.limit} OFFSET ${(q.page - 1) * q.limit}`)).rows;
    return { items: rows, total, page: q.page, limit: q.limit };
  });
  app.post('/coupons', offers, async (req) => {
    const b = parse(couponBody, req.body);
    try {
      const r = await db.query(`INSERT INTO coupons (code,title,description,discount_type,discount_value,min_spend,max_discount,starts_at,ends_at,usage_limit,per_user_limit,category_ids,product_ids,first_order_only,festival,is_public,is_active) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17) RETURNING *`, cArgs(b));
      await audit(db, { actorType: 'admin', actorId: req.admin!.id, action: 'coupon.create', entity: 'coupon', entityId: r.rows[0].id, after: r.rows[0], ip: req.ip });
      return { coupon: r.rows[0] };
    } catch (e: any) { if (e.code === '23505') throw conflict('DUPLICATE_CODE', `Coupon code ${b.code} already exists`); throw e; }
  });
  app.put('/coupons/:id', offers, async (req) => {
    const { id } = parse(z.object({ id: uuid }), req.params); const b = parse(couponBody, req.body);
    const before = (await db.query('SELECT * FROM coupons WHERE id=$1', [id])).rows[0]; if (!before) throw notFound('Coupon not found');
    if (b.usage_limit != null && b.usage_limit < before.used_count) throw new AppError(400, 'VALIDATION_ERROR', `usage_limit: Already used ${before.used_count} times`);
    try {
      const r = await db.query(`UPDATE coupons SET code=$2,title=$3,description=$4,discount_type=$5,discount_value=$6,min_spend=$7,max_discount=$8,starts_at=$9,ends_at=$10,usage_limit=$11,per_user_limit=$12,category_ids=$13,product_ids=$14,first_order_only=$15,festival=$16,is_public=$17,is_active=$18 WHERE id=$1 RETURNING *`, [id, ...cArgs(b)]);
      await audit(db, { actorType: 'admin', actorId: req.admin!.id, action: 'coupon.update', entity: 'coupon', entityId: id, before, after: r.rows[0], ip: req.ip });
      return { coupon: r.rows[0] };
    } catch (e: any) { if (e.code === '23505') throw conflict('DUPLICATE_CODE', `Coupon code ${b.code} already exists`); throw e; }
  });
  app.patch('/coupons/:id/active', offers, async (req) => {
    const { id } = parse(z.object({ id: uuid }), req.params); const b = parse(z.object({ is_active: z.boolean() }), req.body);
    const r = await db.query('UPDATE coupons SET is_active=$2 WHERE id=$1 RETURNING id,is_active', [id, b.is_active]); if (!r.rowCount) throw notFound('Coupon not found');
    await audit(db, { actorType: 'admin', actorId: req.admin!.id, action: b.is_active ? 'coupon.enable' : 'coupon.disable', entity: 'coupon', entityId: id, ip: req.ip });
    return { coupon: r.rows[0] };
  });
  app.delete('/coupons/:id', offers, async (req) => {
    const { id } = parse(z.object({ id: uuid }), req.params);
    if ((await db.query('SELECT 1 FROM coupon_redemptions WHERE coupon_id=$1 LIMIT 1', [id])).rowCount) throw conflict('HAS_REDEMPTIONS', 'This coupon has been used, so it cannot be deleted. Disable it instead.');
    const r = await db.query('DELETE FROM coupons WHERE id=$1 RETURNING *', [id]); if (!r.rowCount) throw notFound('Coupon not found');
    await audit(db, { actorType: 'admin', actorId: req.admin!.id, action: 'coupon.delete', entity: 'coupon', entityId: id, before: r.rows[0], ip: req.ip });
    return { ok: true };
  });

  // ---------------------------------------------------------------- banners
  const bannerBody = z.object({
    title: z.string().trim().min(2).max(80), subtitle: z.string().trim().max(160).nullish(), festival: z.string().trim().max(40).nullish(), terms: z.string().trim().max(500).nullish(),
    link_type: z.enum(['none', 'category', 'product', 'coupon']).default('none'), link_ref: z.string().trim().max(80).nullish(),
    starts_at: z.coerce.date().nullish(), ends_at: z.coerce.date().nullish(), sort_order: z.number().int().min(0).max(9999).default(0), is_active: z.boolean().default(true),
  }).refine((b) => !b.starts_at || !b.ends_at || b.ends_at > b.starts_at, { message: 'End must be after start', path: ['ends_at'] })
    .refine((b) => b.link_type === 'none' || !!b.link_ref, { message: 'Choose what the banner opens', path: ['link_ref'] });
  const bArgs = (b: z.infer<typeof bannerBody>) => [b.title, b.subtitle ?? null, b.festival ?? null, b.terms ?? null, b.link_type, b.link_type === 'none' ? null : b.link_ref, b.starts_at ?? null, b.ends_at ?? null, b.sort_order, b.is_active];
  app.get('/banners', { preHandler: requireAdmin('catalog:read') }, async () => ({ banners: (await db.query('SELECT * FROM banners ORDER BY sort_order, created_at DESC')).rows }));
  app.post('/banners', offers, async (req) => {
    const b = parse(bannerBody, req.body);
    const r = await db.query(`INSERT INTO banners (title,subtitle,festival,terms,link_type,link_ref,starts_at,ends_at,sort_order,is_active) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) RETURNING *`, bArgs(b));
    await audit(db, { actorType: 'admin', actorId: req.admin!.id, action: 'banner.create', entity: 'banner', entityId: r.rows[0].id, after: r.rows[0], ip: req.ip });
    return { banner: r.rows[0] };
  });
  app.put('/banners/:id', offers, async (req) => {
    const { id } = parse(z.object({ id: uuid }), req.params); const b = parse(bannerBody, req.body);
    const before = (await db.query('SELECT * FROM banners WHERE id=$1', [id])).rows[0]; if (!before) throw notFound('Banner not found');
    const r = await db.query(`UPDATE banners SET title=$2,subtitle=$3,festival=$4,terms=$5,link_type=$6,link_ref=$7,starts_at=$8,ends_at=$9,sort_order=$10,is_active=$11 WHERE id=$1 RETURNING *`, [id, ...bArgs(b)]);
    await audit(db, { actorType: 'admin', actorId: req.admin!.id, action: 'banner.update', entity: 'banner', entityId: id, before, after: r.rows[0], ip: req.ip });
    return { banner: r.rows[0] };
  });
  app.post('/banners/:id/image', offers, async (req) => {
    const { id } = parse(z.object({ id: uuid }), req.params);
    const before = (await db.query('SELECT image_url FROM banners WHERE id=$1', [id])).rows[0]; if (!before) throw notFound('Banner not found');
    const f = await (req as any).file(); if (!f) throw new AppError(400, 'NO_FILE', 'Choose an image to upload');
    const img = await storage.saveImage(await f.toBuffer(), 'banners');
    const r = await db.query('UPDATE banners SET image_url=$2 WHERE id=$1 RETURNING *', [id, img.url]);
    await storage.remove(before.image_url);
    return { banner: r.rows[0] };
  });
  app.delete('/banners/:id', offers, async (req) => {
    const { id } = parse(z.object({ id: uuid }), req.params);
    const r = await db.query('DELETE FROM banners WHERE id=$1 RETURNING *', [id]); if (!r.rowCount) throw notFound('Banner not found');
    await storage.remove(r.rows[0].image_url);
    await audit(db, { actorType: 'admin', actorId: req.admin!.id, action: 'banner.delete', entity: 'banner', entityId: id, before: r.rows[0], ip: req.ip });
    return { ok: true };
  });

  // ---------------------------------------------------------------- coins (wallet lookup + manual adjustment)
  app.get('/coins/overview', { preHandler: requireAdmin('customers:read') }, async () => {
    const r = (await db.query(`SELECT COALESCE(SUM(coins) FILTER (WHERE type='earn'),0)::int AS earned, COALESCE(-SUM(coins) FILTER (WHERE type='redeem'),0)::int AS redeemed,
      COALESCE(-SUM(coins) FILTER (WHERE type='expire'),0)::int AS expired, (SELECT COALESCE(SUM(balance),0)::int FROM wallets) AS outstanding FROM wallet_transactions`)).rows[0];
    return r;
  });
  app.get('/customers/:id/wallet', { preHandler: requireAdmin('customers:read') }, async (req) => {
    const { id } = parse(z.object({ id: uuid }), req.params);
    if (!(await db.query('SELECT 1 FROM users WHERE id=$1', [id])).rowCount) throw notFound('Customer not found');
    const s = await loadSettings(db);
    return { wallet: await walletSummary(db, id, s.coins), transactions: await listTransactions(db, id, 50) };
  });
  app.post('/customers/:id/coins', { preHandler: requireAdmin('coins:write') }, async (req) => {
    const { id } = parse(z.object({ id: uuid }), req.params);
    const b = parse(z.object({ coins: z.number().int().refine((n) => n !== 0, 'Enter a non-zero number').refine((n) => Math.abs(n) <= 100000, 'Too large'), reason: z.string().trim().min(3).max(200) }), req.body);
    const s = await loadSettings(db);
    return withTx(db, async (tx) => {
      if (!(await tx.query('SELECT 1 FROM users WHERE id=$1 AND status<>$2', [id, 'deleted'])).rowCount) throw notFound('Customer not found');
      const res = await postLedger(tx, { userId: id, type: 'adjust', coins: b.coins, ref: `adjust:${randomUUID()}`, note: b.reason, adminId: req.admin!.id, expiryDays: b.coins > 0 ? s.coins.expiry_days : undefined });
      await audit(tx, { actorType: 'admin', actorId: req.admin!.id, action: 'coins.adjust', entity: 'user', entityId: id, after: { coins: b.coins, reason: b.reason, balance_after: res.balanceAfter }, ip: req.ip });
      return { balance: res.balanceAfter };
    });
  });
}
