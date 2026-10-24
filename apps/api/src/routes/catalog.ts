import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { RouteDeps } from '../app.js';
import { loadSettings, storeOpenState } from '../services/settings.js';
import { parse, pageParams, uuid } from '../lib/validate.js';
import { buildQuote } from '../services/pricing.js';
import { loadAddressInput } from '../services/orders.js';
import { notFound } from '../lib/errors.js';
import { toPaise } from '../lib/money.js';

const PRODUCT_COLS = `p.id, p.sku, p.name, p.name_hi, p.brand, p.category_id, p.subcategory_id, p.unit, p.pack_size, p.mrp, p.price, p.is_featured,
  GREATEST(p.stock_qty - p.reserved_qty, 0) AS available, p.low_stock_threshold, p.max_per_order,
  (SELECT url FROM product_images i WHERE i.product_id=p.id ORDER BY i.sort_order, i.created_at LIMIT 1) AS image_url,
  (SELECT thumb_url FROM product_images i WHERE i.product_id=p.id ORDER BY i.sort_order, i.created_at LIMIT 1) AS thumb_url`;

// A product is visible to customers only if it and its category chain are active.
const VISIBLE = `p.is_active AND EXISTS (SELECT 1 FROM categories c WHERE c.id=p.category_id AND c.is_active AND (c.parent_id IS NULL OR EXISTS (SELECT 1 FROM categories pc WHERE pc.id=c.parent_id AND pc.is_active)))
  AND (p.subcategory_id IS NULL OR EXISTS (SELECT 1 FROM categories sc WHERE sc.id=p.subcategory_id AND sc.is_active))`;

export function productDto(r: any) {
  const mrp = toPaise(r.mrp), price = toPaise(r.price);
  const available = Number(r.available);
  return {
    id: r.id, sku: r.sku, name: r.name, name_hi: r.name_hi, brand: r.brand, category_id: r.category_id, subcategory_id: r.subcategory_id,
    unit: r.unit, pack_size: r.pack_size, mrp: r.mrp, price: r.price,
    // A discount is shown ONLY when the real MRP is higher than the selling price.
    discount_percent: mrp > price && mrp > 0 ? Math.round(((mrp - price) / mrp) * 100) : 0,
    stock_status: available <= 0 ? 'out_of_stock' : available <= r.low_stock_threshold ? 'low_stock' : 'in_stock',
    available, max_per_order: r.max_per_order, image_url: r.image_url ?? null, thumb_url: r.thumb_url ?? r.image_url ?? null, is_featured: r.is_featured,
  };
}

const esc = (s: string) => s.replace(/[\\%_]/g, (m) => '\\' + m);

export async function catalogRoutes(app: FastifyInstance, { ctx, optionalUser }: RouteDeps) {
  const db = ctx.db;

  app.get('/config', async () => {
    const s = await loadSettings(db);
    const open = storeOpenState(s.store);
    return {
      store: { ...s.store, open_now: open.open, closed_reason: open.reason ?? null },
      delivery: { base_fee: s.delivery.base_fee.toFixed(2), far_fee: s.delivery.far_fee.toFixed(2), near_radius_km: s.delivery.near_radius_km, max_radius_km: s.delivery.max_radius_km, zone_mode: s.delivery.zone_mode, fallback_mode: s.delivery.fallback_mode },
      order: { min_order: s.order.min_order.toFixed(2), min_applies_to_pickup: s.order.min_applies_to_pickup, cod_enabled: s.order.cod_enabled, online_enabled: s.order.online_enabled && ctx.payments.name !== 'none', payment_window_minutes: s.order.payment_window_minutes },
      upi: { enabled: s.upi.enabled && !!s.upi.vpa },
      coins: s.coins, first_order: s.first_order.enabled ? s.first_order : { enabled: false },
      payments: { provider: ctx.payments.name, mode: ctx.payments.mode, live: ctx.payments.mode === 'live' },
      policies: s.policies, server_time: new Date().toISOString(),
    };
  });

  app.get('/categories', async () => {
    const { rows } = await db.query(`SELECT id, parent_id, name, name_hi, slug, description, image_url, sort_order FROM categories WHERE is_active ORDER BY sort_order, name`);
    const top = rows.filter((r) => !r.parent_id).map((r) => ({ ...r, children: [] as any[] }));
    const byId = new Map(top.map((t) => [t.id, t]));
    for (const r of rows.filter((x) => x.parent_id)) byId.get(r.parent_id)?.children.push(r);
    return { categories: top };
  });

  app.get('/banners', async () => {
    const { rows } = await db.query(`SELECT id, title, subtitle, image_url, festival, terms, link_type, link_ref, starts_at, ends_at FROM banners
      WHERE is_active AND (starts_at IS NULL OR starts_at <= now()) AND (ends_at IS NULL OR ends_at > now()) ORDER BY sort_order, created_at DESC`);
    return { banners: rows };
  });

  app.get('/delivery/zones', async () => {
    const { rows } = await db.query('SELECT id, name, name_hi, pincodes FROM delivery_zones WHERE is_active ORDER BY sort_order, name');
    return { zones: rows };
  });

  app.get('/coupons', async () => {
    const { rows } = await db.query(`SELECT code, title, description, discount_type, discount_value, min_spend, max_discount, starts_at, ends_at, first_order_only, festival FROM coupons
      WHERE is_active AND is_public AND starts_at <= now() AND ends_at > now() AND (usage_limit IS NULL OR used_count < usage_limit) ORDER BY ends_at`);
    return { coupons: rows };
  });

  const listQuery = pageParams.extend({
    q: z.string().trim().max(80).optional(), category: z.string().optional(), sort: z.enum(['relevance', 'price_asc', 'price_desc', 'name', 'newest', 'discount']).default('relevance'),
    in_stock: z.coerce.boolean().optional(), featured: z.coerce.boolean().optional(), ids: z.string().optional(), brand: z.string().optional(),
  });

  app.get('/products', async (req) => {
    const q = parse(listQuery, req.query);
    const where: string[] = [VISIBLE]; const args: unknown[] = [];
    const arg = (v: unknown) => { args.push(v); return `$${args.length}`; };
    if (q.q) {
      const tokens = q.q.toLowerCase().split(/\s+/).filter(Boolean).slice(0, 6);
      where.push(`p.search_text LIKE ALL(${arg(tokens.map((t) => `%${esc(t)}%`))}::text[])`);
    }
    if (q.category) {
      const cat = (await db.query('SELECT id FROM categories WHERE is_active AND (id::text=$1 OR slug=$1)', [q.category])).rows[0];
      if (!cat) return { items: [], page: q.page, limit: q.limit, total: 0, has_more: false };
      const ids = (await db.query('SELECT id FROM categories WHERE id=$1 OR parent_id=$1', [cat.id])).rows.map((r) => r.id);
      where.push(`(p.category_id = ANY(${arg(ids)}::uuid[]) OR p.subcategory_id = ANY(${arg(ids)}::uuid[]))`);
    }
    if (q.in_stock) where.push('p.stock_qty - p.reserved_qty > 0');
    if (q.featured) where.push('p.is_featured');
    if (q.brand) where.push(`lower(p.brand) = lower(${arg(q.brand)})`);
    if (q.ids) {
      const ids = q.ids.split(',').filter((x) => uuid.safeParse(x).success).slice(0, 50);
      where.push(`p.id = ANY(${arg(ids)}::uuid[])`);
    }
    const order = ({
      relevance: q.q ? `(p.stock_qty - p.reserved_qty > 0) DESC, p.is_featured DESC, p.name` : `(p.stock_qty - p.reserved_qty > 0) DESC, p.is_featured DESC, p.name`,
      price_asc: 'p.price ASC, p.name', price_desc: 'p.price DESC, p.name', name: 'p.name', newest: 'p.created_at DESC',
      discount: '(CASE WHEN p.mrp > 0 THEN (p.mrp - p.price) / p.mrp ELSE 0 END) DESC, p.name',
    })[q.sort];
    const whereSql = where.join(' AND ');
    const total = (await db.query(`SELECT count(*)::int n FROM products p WHERE ${whereSql}`, args)).rows[0].n as number;
    const rows = (await db.query(`SELECT ${PRODUCT_COLS} FROM products p WHERE ${whereSql} ORDER BY ${order} LIMIT ${q.limit} OFFSET ${(q.page - 1) * q.limit}`, args)).rows;
    return { items: rows.map(productDto), page: q.page, limit: q.limit, total, has_more: q.page * q.limit < total };
  });

  app.get('/products/:id', async (req) => {
    const { id } = parse(z.object({ id: uuid }), req.params);
    const r = (await db.query(`SELECT ${PRODUCT_COLS}, p.description, p.barcode, p.tax_rate FROM products p WHERE p.id=$1 AND ${VISIBLE}`, [id])).rows[0];
    if (!r) throw notFound('Product not found');
    const images = (await db.query('SELECT id, url, thumb_url, alt FROM product_images WHERE product_id=$1 ORDER BY sort_order, created_at', [id])).rows;
    const cat = (await db.query('SELECT id, name, name_hi, slug FROM categories WHERE id=$1', [r.category_id])).rows[0];
    return { product: { ...productDto(r), description: r.description, barcode: r.barcode, tax_rate: r.tax_rate, images, category: cat } };
  });

  app.get('/products/:id/similar', async (req) => {
    const { id } = parse(z.object({ id: uuid }), req.params);
    const base = (await db.query('SELECT category_id, subcategory_id FROM products WHERE id=$1', [id])).rows[0];
    if (!base) throw notFound('Product not found');
    const rows = (await db.query(`SELECT ${PRODUCT_COLS} FROM products p WHERE p.id <> $1 AND ${VISIBLE} AND p.stock_qty - p.reserved_qty > 0
      AND (p.category_id=$2 OR ($3::uuid IS NOT NULL AND p.subcategory_id=$3)) ORDER BY (p.subcategory_id IS NOT DISTINCT FROM $3) DESC, p.is_featured DESC, p.name LIMIT 12`, [id, base.category_id, base.subcategory_id])).rows;
    return { items: rows.map(productDto) };
  });

  app.get('/brands', async () => {
    const { rows } = await db.query(`SELECT DISTINCT brand FROM products p WHERE brand IS NOT NULL AND brand <> '' AND ${VISIBLE} ORDER BY brand LIMIT 200`);
    return { brands: rows.map((r) => r.brand) };
  });

  app.get('/home', async () => {
    const [banners, cats, featured, best] = await Promise.all([
      db.query(`SELECT id, title, subtitle, image_url, festival, terms, link_type, link_ref, starts_at, ends_at FROM banners WHERE is_active AND (starts_at IS NULL OR starts_at <= now()) AND (ends_at IS NULL OR ends_at > now()) ORDER BY sort_order, created_at DESC LIMIT 10`),
      db.query(`SELECT id, name, name_hi, slug, image_url FROM categories WHERE is_active AND parent_id IS NULL ORDER BY sort_order, name`),
      db.query(`SELECT ${PRODUCT_COLS} FROM products p WHERE p.is_featured AND ${VISIBLE} AND p.stock_qty - p.reserved_qty > 0 ORDER BY p.updated_at DESC LIMIT 12`),
      // Best sellers come from REAL completed orders in the last 90 days; empty until the store has sales.
      db.query(`SELECT ${PRODUCT_COLS}, s.sold FROM (SELECT oi.product_id, SUM(oi.qty)::int AS sold FROM order_items oi JOIN orders o ON o.id=oi.order_id
                  WHERE o.status IN ('delivered','collected') AND o.placed_at > now() - interval '90 days' AND oi.product_id IS NOT NULL GROUP BY oi.product_id ORDER BY sold DESC LIMIT 12) s
                JOIN products p ON p.id = s.product_id WHERE ${VISIBLE} AND p.stock_qty - p.reserved_qty > 0 ORDER BY s.sold DESC`),
    ]);
    return { banners: banners.rows, categories: cats.rows, featured: featured.rows.map(productDto), best_sellers: best.rows.map(productDto) };
  });

  // ---- cart quote: the single source of truth for what the customer will pay
  const quoteBody = z.object({
    items: z.array(z.object({ product_id: uuid, qty: z.number().int().min(1).max(999) })).max(200),
    fulfilment: z.enum(['delivery', 'pickup']).default('delivery'),
    address_id: uuid.nullish(), zone_id: uuid.nullish(),
    address: z.object({ latitude: z.number().min(-90).max(90).nullish(), longitude: z.number().min(-180).max(180).nullish(), pincode: z.string().regex(/^\d{6}$/).nullish(), zone_id: uuid.nullish() }).nullish(),
    coupon_code: z.string().trim().max(24).nullish(), use_coins: z.number().int().min(0).max(100000).default(0),
    payment_method: z.enum(['cod', 'online', 'upi']).nullish(),
  });
  app.post('/cart/quote', { preHandler: optionalUser }, async (req) => {
    const b = parse(quoteBody, req.body);
    const settings = await loadSettings(db);
    let address = null;
    if (b.fulfilment === 'delivery') {
      if (b.address_id && req.userId) address = (await loadAddressInput(db, req.userId, b.address_id, b.zone_id)).input;
      else if (b.address) address = { id: null, latitude: b.address.latitude ?? null, longitude: b.address.longitude ?? null, zone_id: b.zone_id ?? b.address.zone_id ?? null, pincode: b.address.pincode ?? null };
    }
    const { quote } = await buildQuote({ items: b.items, fulfilment: b.fulfilment, address, coupon_code: b.coupon_code, use_coins: b.use_coins, payment_method: b.payment_method ?? undefined },
      { q: db, userId: req.userId ?? null, settings, routing: ctx.routing });
    return { quote };
  });
}
