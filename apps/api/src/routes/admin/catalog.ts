import type { FastifyInstance, FastifyRequest } from 'fastify';
import { z } from 'zod';
import type { RouteDeps } from '../../app.js';
import { parse, uuid, rupees, pageParams } from '../../lib/validate.js';
import { AppError, conflict, notFound } from '../../lib/errors.js';
import { audit } from '../../lib/audit.js';
import { withTx } from '../../db/pool.js';
import { adjustStock } from '../../services/stock.js';
import { Storage } from '../../services/storage.js';

const slugify = (s: string) => s.toLowerCase().normalize('NFKD').replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 60) || 'item';

async function readImage(req: FastifyRequest): Promise<Buffer> {
  const f = await (req as any).file();
  if (!f) throw new AppError(400, 'NO_FILE', 'Choose an image to upload');
  const buf: Buffer = await f.toBuffer();
  if (f.file.truncated) throw new AppError(413, 'FILE_TOO_LARGE', 'Image is too large (max 6 MB)');
  return buf;
}

export async function adminCatalogRoutes(app: FastifyInstance, { ctx, requireAdmin }: RouteDeps) {
  const db = ctx.db; const storage = new Storage(ctx.config);
  const read = { preHandler: requireAdmin('catalog:read') };
  const write = { preHandler: requireAdmin('catalog:write') };

  // ------------------------------------------------------------ categories
  const catBody = z.object({
    name: z.string().trim().min(2).max(80), name_hi: z.string().trim().max(80).nullish(), parent_id: uuid.nullish(), slug: z.string().trim().max(60).optional(),
    description: z.string().trim().max(300).nullish(), sort_order: z.number().int().min(0).max(9999).default(0), is_active: z.boolean().default(true),
  });
  app.get('/categories', read, async () => ({
    categories: (await db.query(`SELECT c.*, (SELECT count(*)::int FROM products p WHERE p.category_id=c.id OR p.subcategory_id=c.id) AS product_count FROM categories c ORDER BY c.parent_id NULLS FIRST, c.sort_order, c.name`)).rows,
  }));
  app.post('/categories', write, async (req) => {
    const b = parse(catBody, req.body);
    if (b.parent_id) { const p = (await db.query('SELECT parent_id FROM categories WHERE id=$1', [b.parent_id])).rows[0]; if (!p) throw notFound('Parent category not found'); if (p.parent_id) throw new AppError(400, 'TOO_DEEP', 'Only one level of sub-categories is supported'); }
    const slug = b.slug ? slugify(b.slug) : slugify(b.name);
    try {
      const r = await db.query(`INSERT INTO categories (parent_id, name, name_hi, slug, description, sort_order, is_active) VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *`, [b.parent_id ?? null, b.name, b.name_hi ?? null, slug, b.description ?? null, b.sort_order, b.is_active]);
      await audit(db, { actorType: 'admin', actorId: req.admin!.id, action: 'category.create', entity: 'category', entityId: r.rows[0].id, after: r.rows[0], ip: req.ip });
      return { category: r.rows[0] };
    } catch (e: any) { if (e.code === '23505') throw conflict('DUPLICATE', 'A category with this name/slug already exists'); throw e; }
  });
  app.put('/categories/:id', write, async (req) => {
    const { id } = parse(z.object({ id: uuid }), req.params); const b = parse(catBody, req.body);
    const before = (await db.query('SELECT * FROM categories WHERE id=$1', [id])).rows[0]; if (!before) throw notFound('Category not found');
    if (b.parent_id) {
      if (b.parent_id === id) throw new AppError(400, 'BAD_PARENT', 'A category cannot be its own parent');
      const hasKids = (await db.query('SELECT 1 FROM categories WHERE parent_id=$1 LIMIT 1', [id])).rowCount; if (hasKids) throw new AppError(400, 'TOO_DEEP', 'This category has sub-categories, so it cannot become one itself');
      const p = (await db.query('SELECT parent_id FROM categories WHERE id=$1', [b.parent_id])).rows[0]; if (!p || p.parent_id) throw new AppError(400, 'BAD_PARENT', 'Choose a top-level category as the parent');
    }
    try {
      const r = await db.query(`UPDATE categories SET parent_id=$2, name=$3, name_hi=$4, slug=COALESCE($5, slug), description=$6, sort_order=$7, is_active=$8 WHERE id=$1 RETURNING *`,
        [id, b.parent_id ?? null, b.name, b.name_hi ?? null, b.slug ? slugify(b.slug) : null, b.description ?? null, b.sort_order, b.is_active]);
      await audit(db, { actorType: 'admin', actorId: req.admin!.id, action: 'category.update', entity: 'category', entityId: id, before, after: r.rows[0], ip: req.ip });
      return { category: r.rows[0] };
    } catch (e: any) { if (e.code === '23505') throw conflict('DUPLICATE', 'A category with this slug already exists'); throw e; }
  });
  app.post('/categories/:id/image', write, async (req) => {
    const { id } = parse(z.object({ id: uuid }), req.params);
    const before = (await db.query('SELECT image_url FROM categories WHERE id=$1', [id])).rows[0]; if (!before) throw notFound('Category not found');
    const img = await storage.saveImage(await readImage(req), 'categories');
    const r = await db.query('UPDATE categories SET image_url=$2 WHERE id=$1 RETURNING *', [id, img.url]);
    await storage.remove(before.image_url);
    await audit(db, { actorType: 'admin', actorId: req.admin!.id, action: 'category.image', entity: 'category', entityId: id, ip: req.ip });
    return { category: r.rows[0] };
  });
  app.delete('/categories/:id', write, async (req) => {
    const { id } = parse(z.object({ id: uuid }), req.params);
    const used = (await db.query('SELECT (SELECT count(*)::int FROM products WHERE category_id=$1 OR subcategory_id=$1) AS p, (SELECT count(*)::int FROM categories WHERE parent_id=$1) AS c', [id])).rows[0];
    if (used.p || used.c) throw conflict('IN_USE', 'This category still has products or sub-categories. Move them first, or hide the category instead.');
    const r = await db.query('DELETE FROM categories WHERE id=$1 RETURNING *', [id]); if (!r.rowCount) throw notFound('Category not found');
    await audit(db, { actorType: 'admin', actorId: req.admin!.id, action: 'category.delete', entity: 'category', entityId: id, before: r.rows[0], ip: req.ip });
    return { ok: true };
  });

  // ------------------------------------------------------------ products
  const prodBody = z.object({
    sku: z.string().trim().min(1).max(40).regex(/^[A-Za-z0-9._-]+$/, 'Use letters, numbers, - _ . only'), barcode: z.string().trim().max(40).nullish(),
    name: z.string().trim().min(2).max(160), name_hi: z.string().trim().max(160).nullish(), brand: z.string().trim().max(60).nullish(),
    category_id: uuid, subcategory_id: uuid.nullish(), description: z.string().trim().max(2000).nullish(),
    unit: z.string().trim().min(1).max(20).default('pc'), pack_size: z.string().trim().max(40).nullish(),
    mrp: rupees, price: rupees, tax_rate: z.coerce.number().min(0).max(100).default(0), hsn_code: z.string().trim().max(12).nullish(),
    low_stock_threshold: z.number().int().min(0).max(100000).default(5), max_per_order: z.number().int().min(1).max(10000).nullish(),
    is_active: z.boolean().default(true), is_featured: z.boolean().default(false), coins_eligible: z.boolean().default(true), offers_eligible: z.boolean().default(true),
    opening_stock: z.number().int().min(0).max(1000000).optional(),
  }).refine((p) => Number(p.price) <= Number(p.mrp), { message: 'Selling price cannot be higher than MRP', path: ['price'] });

  async function validateCats(q: { query: typeof db.query }, categoryId: string, subId?: string | null) {
    const c = (await q.query('SELECT id, parent_id FROM categories WHERE id=$1', [categoryId])).rows[0];
    if (!c) throw new AppError(400, 'VALIDATION_ERROR', 'category_id: Category not found'); if (c.parent_id) throw new AppError(400, 'VALIDATION_ERROR', 'category_id: Choose a main category here, and pick the sub-category separately');
    if (subId) { const s = (await q.query('SELECT parent_id FROM categories WHERE id=$1', [subId])).rows[0]; if (!s || s.parent_id !== categoryId) throw new AppError(400, 'VALIDATION_ERROR', 'subcategory_id: Sub-category does not belong to the chosen category'); }
  }
  const productRow = `p.*, (p.stock_qty - p.reserved_qty) AS available, c.name AS category_name, s.name AS subcategory_name,
    (SELECT url FROM product_images i WHERE i.product_id=p.id ORDER BY sort_order, created_at LIMIT 1) AS image_url,
    (SELECT thumb_url FROM product_images i WHERE i.product_id=p.id ORDER BY sort_order, created_at LIMIT 1) AS thumb_url`;
  const productFrom = `FROM products p JOIN categories c ON c.id=p.category_id LEFT JOIN categories s ON s.id=p.subcategory_id`;

  app.get('/products', read, async (req) => {
    const q = parse(pageParams.extend({ q: z.string().trim().max(60).optional(), category_id: uuid.optional(), status: z.enum(['active', 'hidden', 'low', 'out']).optional(), missing_image: z.coerce.boolean().optional(), sample: z.coerce.boolean().optional() }), req.query);
    const args: unknown[] = []; const w: string[] = ['TRUE'];
    if (q.q) { args.push(`%${q.q.toLowerCase().replace(/[\\%_]/g, (m) => '\\' + m)}%`); w.push(`p.search_text LIKE $${args.length}`); }
    if (q.category_id) { args.push(q.category_id); w.push(`(p.category_id=$${args.length} OR p.subcategory_id=$${args.length})`); }
    if (q.status === 'active') w.push('p.is_active'); if (q.status === 'hidden') w.push('NOT p.is_active');
    if (q.status === 'low') w.push('p.is_active AND p.stock_qty - p.reserved_qty <= p.low_stock_threshold AND p.stock_qty - p.reserved_qty > 0');
    if (q.status === 'out') w.push('p.stock_qty - p.reserved_qty <= 0');
    if (q.missing_image) w.push('NOT EXISTS (SELECT 1 FROM product_images i WHERE i.product_id=p.id)');
    if (q.sample) w.push('p.is_sample');
    const total = (await db.query(`SELECT count(*)::int n ${productFrom} WHERE ${w.join(' AND ')}`, args)).rows[0].n;
    const rows = (await db.query(`SELECT ${productRow} ${productFrom} WHERE ${w.join(' AND ')} ORDER BY p.updated_at DESC, p.name LIMIT ${q.limit} OFFSET ${(q.page - 1) * q.limit}`, args)).rows;
    return { items: rows, total, page: q.page, limit: q.limit };
  });
  app.get('/products/:id', read, async (req) => {
    const { id } = parse(z.object({ id: uuid }), req.params);
    const p = (await db.query(`SELECT ${productRow} ${productFrom} WHERE p.id=$1`, [id])).rows[0]; if (!p) throw notFound('Product not found');
    const images = (await db.query('SELECT id, url, thumb_url, alt, sort_order FROM product_images WHERE product_id=$1 ORDER BY sort_order, created_at', [id])).rows;
    return { product: p, images };
  });
  app.post('/products', write, async (req) => {
    const b = parse(prodBody, req.body);
    return withTx(db, async (tx) => {
      await validateCats(tx as any, b.category_id, b.subcategory_id);
      let r;
      try {
        r = await tx.query(`INSERT INTO products (sku, barcode, name, name_hi, brand, category_id, subcategory_id, description, unit, pack_size, mrp, price, tax_rate, hsn_code, low_stock_threshold, max_per_order, is_active, is_featured, coins_eligible, offers_eligible)
          VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20) RETURNING *`,
          [b.sku, b.barcode ?? null, b.name, b.name_hi ?? null, b.brand ?? null, b.category_id, b.subcategory_id ?? null, b.description ?? null, b.unit, b.pack_size ?? null, b.mrp, b.price, b.tax_rate, b.hsn_code ?? null, b.low_stock_threshold, b.max_per_order ?? null, b.is_active, b.is_featured, b.coins_eligible, b.offers_eligible]);
      } catch (e: any) { if (e.code === '23505') throw conflict('DUPLICATE_SKU', `SKU "${b.sku}" already exists`); throw e; }
      if (b.opening_stock) await adjustStock(tx, { productId: r.rows[0].id, delta: b.opening_stock, reason: 'Opening stock', adminId: req.admin!.id, type: 'opening' });
      await audit(tx, { actorType: 'admin', actorId: req.admin!.id, action: 'product.create', entity: 'product', entityId: r.rows[0].id, after: r.rows[0], ip: req.ip });
      return { product: r.rows[0] };
    });
  });
  /** Price/details edit. Stock is changed only through /stock so that every change has a reason and a ledger row. */
  app.put('/products/:id', write, async (req) => {
    const { id } = parse(z.object({ id: uuid }), req.params); const b = parse(prodBody, req.body);
    return withTx(db, async (tx) => {
      const before = (await tx.query('SELECT * FROM products WHERE id=$1 FOR UPDATE', [id])).rows[0]; if (!before) throw notFound('Product not found');
      await validateCats(tx as any, b.category_id, b.subcategory_id);
      try {
        const r = await tx.query(`UPDATE products SET sku=$2, barcode=$3, name=$4, name_hi=$5, brand=$6, category_id=$7, subcategory_id=$8, description=$9, unit=$10, pack_size=$11, mrp=$12, price=$13, tax_rate=$14, hsn_code=$15,
          low_stock_threshold=$16, max_per_order=$17, is_active=$18, is_featured=$19, coins_eligible=$20, offers_eligible=$21 WHERE id=$1 RETURNING *`,
          [id, b.sku, b.barcode ?? null, b.name, b.name_hi ?? null, b.brand ?? null, b.category_id, b.subcategory_id ?? null, b.description ?? null, b.unit, b.pack_size ?? null, b.mrp, b.price, b.tax_rate, b.hsn_code ?? null, b.low_stock_threshold, b.max_per_order ?? null, b.is_active, b.is_featured, b.coins_eligible, b.offers_eligible]);
        await audit(tx, { actorType: 'admin', actorId: req.admin!.id, action: 'product.update', entity: 'product', entityId: id, before, after: r.rows[0], ip: req.ip });
        return { product: r.rows[0] };
      } catch (e: any) { if (e.code === '23505') throw conflict('DUPLICATE_SKU', `SKU "${b.sku}" already exists`); throw e; }
    });
  });
  app.patch('/products/:id/active', write, async (req) => {
    const { id } = parse(z.object({ id: uuid }), req.params); const b = parse(z.object({ is_active: z.boolean() }), req.body);
    const r = await db.query('UPDATE products SET is_active=$2 WHERE id=$1 RETURNING id, is_active', [id, b.is_active]); if (!r.rowCount) throw notFound('Product not found');
    await audit(db, { actorType: 'admin', actorId: req.admin!.id, action: b.is_active ? 'product.show' : 'product.hide', entity: 'product', entityId: id, ip: req.ip });
    return { product: r.rows[0] };
  });
  /** Products with order history are hidden, never deleted (order lines keep their own snapshot, but history stays honest). */
  app.delete('/products/:id', write, async (req) => {
    const { id } = parse(z.object({ id: uuid }), req.params);
    const used = (await db.query('SELECT (SELECT count(*)::int FROM order_items WHERE product_id=$1) AS o, (SELECT reserved_qty FROM products WHERE id=$1) AS r', [id])).rows[0];
    if (used.r === null || used.r === undefined) throw notFound('Product not found');
    if (used.o > 0) throw conflict('HAS_ORDERS', 'This product appears in past orders, so it cannot be deleted. Hide it instead.');
    const imgs = (await db.query('SELECT url, thumb_url FROM product_images WHERE product_id=$1', [id])).rows;
    try { await db.query('DELETE FROM products WHERE id=$1', [id]); } catch (e: any) { if (e.code === '23503') throw conflict('HAS_HISTORY', 'This product has stock history, so it cannot be deleted. Hide it instead.'); throw e; }
    for (const i of imgs) { await storage.remove(i.url); await storage.remove(i.thumb_url); }
    await audit(db, { actorType: 'admin', actorId: req.admin!.id, action: 'product.delete', entity: 'product', entityId: id, ip: req.ip });
    return { ok: true };
  });

  // ------------------------------------------------------------ product images
  app.post('/products/:id/images', write, async (req) => {
    const { id } = parse(z.object({ id: uuid }), req.params);
    if (!(await db.query('SELECT 1 FROM products WHERE id=$1', [id])).rowCount) throw notFound('Product not found');
    const n = (await db.query('SELECT count(*)::int n FROM product_images WHERE product_id=$1', [id])).rows[0].n;
    if (n >= 8) throw new AppError(400, 'TOO_MANY_IMAGES', 'A product can have up to 8 photos');
    const img = await storage.saveImage(await readImage(req), 'products');
    const r = await db.query('INSERT INTO product_images (product_id, url, thumb_url, sort_order) VALUES ($1,$2,$3,$4) RETURNING *', [id, img.url, img.thumbUrl, n]);
    await audit(db, { actorType: 'admin', actorId: req.admin!.id, action: 'product.image_add', entity: 'product', entityId: id, ip: req.ip });
    return { image: r.rows[0] };
  });
  app.put('/products/:id/images/order', write, async (req) => {
    const { id } = parse(z.object({ id: uuid }), req.params); const b = parse(z.object({ image_ids: z.array(uuid).min(1).max(8) }), req.body);
    await withTx(db, async (tx) => { for (let i = 0; i < b.image_ids.length; i++) await tx.query('UPDATE product_images SET sort_order=$3 WHERE id=$1 AND product_id=$2', [b.image_ids[i], id, i]); });
    return { ok: true };
  });
  app.delete('/products/:id/images/:imageId', write, async (req) => {
    const p = parse(z.object({ id: uuid, imageId: uuid }), req.params);
    const r = await db.query('DELETE FROM product_images WHERE id=$1 AND product_id=$2 RETURNING *', [p.imageId, p.id]); if (!r.rowCount) throw notFound('Image not found');
    await storage.remove(r.rows[0].url); await storage.remove(r.rows[0].thumb_url);
    await audit(db, { actorType: 'admin', actorId: req.admin!.id, action: 'product.image_delete', entity: 'product', entityId: p.id, ip: req.ip });
    return { ok: true };
  });

  // ------------------------------------------------------------ inventory
  app.get('/inventory', { preHandler: requireAdmin('inventory:read') }, async (req) => {
    const q = parse(pageParams.extend({ q: z.string().trim().max(60).optional(), filter: z.enum(['low', 'out', 'reserved']).optional() }), req.query);
    const args: unknown[] = []; const w = ['TRUE'];
    if (q.q) { args.push(`%${q.q.toLowerCase().replace(/[\\%_]/g, (m) => '\\' + m)}%`); w.push(`search_text LIKE $${args.length}`); }
    if (q.filter === 'low') w.push('stock_qty - reserved_qty <= low_stock_threshold AND stock_qty - reserved_qty > 0'); if (q.filter === 'out') w.push('stock_qty - reserved_qty <= 0'); if (q.filter === 'reserved') w.push('reserved_qty > 0');
    const total = (await db.query(`SELECT count(*)::int n FROM products WHERE ${w.join(' AND ')}`, args)).rows[0].n;
    const rows = (await db.query(`SELECT id, sku, name, unit, stock_qty, reserved_qty, (stock_qty-reserved_qty) AS available, low_stock_threshold, is_active FROM products WHERE ${w.join(' AND ')} ORDER BY (stock_qty-reserved_qty), name LIMIT ${q.limit} OFFSET ${(q.page - 1) * q.limit}`, args)).rows;
    return { items: rows, total, page: q.page, limit: q.limit };
  });
  app.post('/products/:id/stock', { preHandler: requireAdmin('inventory:write') }, async (req) => {
    const { id } = parse(z.object({ id: uuid }), req.params);
    const b = parse(z.object({ delta: z.number().int().min(-1000000).max(1000000).optional(), set_to: z.number().int().min(0).max(1000000).optional(), reason: z.string().trim().min(3).max(200) })
      .refine((v) => (v.delta === undefined) !== (v.set_to === undefined), { message: 'Give either a change (+/-) or a new total, not both' }), req.body);
    return withTx(db, async (tx) => {
      const res = await adjustStock(tx, { productId: id, delta: b.delta, setTo: b.set_to, reason: b.reason, adminId: req.admin!.id });
      await audit(tx, { actorType: 'admin', actorId: req.admin!.id, action: 'stock.adjust', entity: 'product', entityId: id, after: { ...res, delta: b.delta, set_to: b.set_to, reason: b.reason }, ip: req.ip });
      return { stock_qty: res.stock_qty, reserved_qty: res.reserved_qty, available: res.stock_qty - res.reserved_qty };
    });
  });
  app.get('/products/:id/movements', { preHandler: requireAdmin('inventory:read') }, async (req) => {
    const { id } = parse(z.object({ id: uuid }), req.params); const q = parse(z.object({ limit: z.coerce.number().int().min(1).max(200).default(50) }), req.query);
    const rows = (await db.query(`SELECT m.id, m.type, m.qty_delta, m.reserved_delta, m.stock_after, m.reserved_after, m.reason, m.order_id, o.order_no, a.name AS admin_name, m.created_at
      FROM stock_movements m LEFT JOIN orders o ON o.id=m.order_id LEFT JOIN admin_users a ON a.id=m.admin_id WHERE m.product_id=$1 ORDER BY m.id DESC LIMIT $2`, [id, q.limit])).rows;
    return { movements: rows };
  });
}
