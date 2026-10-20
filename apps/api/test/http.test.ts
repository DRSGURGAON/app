import { describe, it, expect, beforeAll, afterAll, beforeEach } from 'vitest';
import sharp from 'sharp';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import type { FastifyInstance } from 'fastify';
import { buildApp } from '../src/app.js';
import { makeCtx, reset, openStore, mkCategory, mkProduct, mkAddress, setting } from './helpers.js';
import { hashPassword } from '../src/lib/crypto.js';

let app: FastifyInstance; let ctx: ReturnType<typeof makeCtx>; let uploadDir: string;

beforeAll(async () => {
  uploadDir = await mkdtemp(join(tmpdir(), 'uploads-'));
  ctx = makeCtx(); ctx.config = { ...ctx.config, UPLOAD_DIR: uploadDir, PUBLIC_BASE_URL: 'http://test.local' } as any;
  app = await buildApp(ctx); await app.ready();
});
afterAll(async () => { await app.close(); await ctx.db.end(); await rm(uploadDir, { recursive: true, force: true }); });
beforeEach(async () => { await reset(ctx.db); await openStore(ctx.db); ctx.otp.sent.length = 0; });

const json = (r: { body: string }) => JSON.parse(r.body);
async function customerToken(phone = '9876543210') {
  const a = await app.inject({ method: 'POST', url: '/v1/auth/otp/request', payload: { phone } });
  const code = json(a).dev_code as string;
  const b = await app.inject({ method: 'POST', url: '/v1/auth/otp/verify', payload: { phone, code } });
  return { res: b, body: json(b), auth: { authorization: `Bearer ${json(b).access_token}` } };
}
async function adminToken(role: 'owner' | 'manager' | 'staff' = 'owner', email = `${role}@t.test`) {
  await ctx.db.query(`INSERT INTO admin_users (email,name,password_hash,role) VALUES ($1,$2,$3,$4) ON CONFLICT (email) DO NOTHING`, [email, role, await hashPassword('correct-horse-9'), role]);
  const r = await app.inject({ method: 'POST', url: '/v1/admin/login', payload: { email, password: 'correct-horse-9' } });
  expect(r.statusCode).toBe(200);
  return { authorization: `Bearer ${json(r).token}` };
}

describe('customer auth over HTTP', () => {
  it('OTP login works, wrong code fails, refresh rotates and old refresh token is rejected', async () => {
    const bad = await app.inject({ method: 'POST', url: '/v1/auth/otp/request', payload: { phone: '9811111111' } });
    expect(bad.statusCode).toBe(200);
    const wrong = await app.inject({ method: 'POST', url: '/v1/auth/otp/verify', payload: { phone: '9811111111', code: json(bad).dev_code === '000000' ? '111111' : '000000' } });
    expect(wrong.statusCode).toBeGreaterThanOrEqual(400);
    const { body } = await customerToken('9822222222');
    expect(body.is_new).toBe(true);
    const r1 = await app.inject({ method: 'POST', url: '/v1/auth/refresh', payload: { refresh_token: body.refresh_token } });
    expect(r1.statusCode).toBe(200);
    const reuse = await app.inject({ method: 'POST', url: '/v1/auth/refresh', payload: { refresh_token: body.refresh_token } });
    expect(reuse.statusCode).toBe(401);
  });
  it('rejects requests without a token', async () => {
    expect((await app.inject({ method: 'GET', url: '/v1/me' })).statusCode).toBe(401);
    expect((await app.inject({ method: 'GET', url: '/v1/orders' })).statusCode).toBe(401);
  });
  it('invalid phone returns a clear 400 in the uniform error shape', async () => {
    const r = await app.inject({ method: 'POST', url: '/v1/auth/otp/request', payload: { phone: '12345' } });
    expect(r.statusCode).toBe(400);
    expect(json(r).error.code).toBeTruthy();
  });
});

describe('ordering over HTTP (server-side rules)', () => {
  it('browse → quote → order; min order, ₹70 far fee, pickup ₹0, idempotent retry', async () => {
    const cat = await mkCategory(ctx.db, 'Grocery'); const p = await mkProduct(ctx.db, { category: cat.id, price: 1000, stock: 10 });
    const small = await mkProduct(ctx.db, { category: cat.id, price: 400, stock: 10 });
    const list = await app.inject({ method: 'GET', url: '/v1/products?limit=10' });
    expect(list.statusCode).toBe(200); expect(json(list).items.length).toBe(2);

    const { body, auth } = await customerToken();
    const user = body.user.id as string;
    const near = await mkAddress(ctx.db, user, { lat: 28.4, lng: 75.8 });
    const far = await mkAddress(ctx.db, user, { lat: 28.45, lng: 75.8 }); // ~5.5 km straight line

    // below minimum
    const q1 = await app.inject({ method: 'POST', url: '/v1/cart/quote', headers: auth, payload: { items: [{ product_id: small.id, qty: 1 }], fulfilment: 'pickup', payment_method: 'cod' } });
    expect(json(q1).quote.can_checkout ?? json(q1).can_checkout).toBe(false);
    const o0 = await app.inject({ method: 'POST', url: '/v1/orders', headers: { ...auth, 'idempotency-key': 'key-below-min-1' }, payload: { items: [{ product_id: small.id, qty: 1 }], fulfilment: 'pickup', payment_method: 'cod' } });
    expect(o0.statusCode).toBeGreaterThanOrEqual(400);

    // missing idempotency key
    const o00 = await app.inject({ method: 'POST', url: '/v1/orders', headers: auth, payload: { items: [{ product_id: p.id, qty: 1 }], fulfilment: 'pickup', payment_method: 'cod' } });
    expect(o00.statusCode).toBe(400);

    // pickup => fee 0
    const o1 = await app.inject({ method: 'POST', url: '/v1/orders', headers: { ...auth, 'idempotency-key': 'key-pickup-0001' }, payload: { items: [{ product_id: p.id, qty: 1 }], fulfilment: 'pickup', payment_method: 'cod' } });
    expect(o1.statusCode).toBe(201); expect(json(o1).order.totals.delivery_fee).toBe('0.00'); expect(json(o1).order.totals.total).toBe('1000.00');

    // no routing provider + fallback 'ask_zone' => refuses to guess the distance
    const refused = await app.inject({ method: 'POST', url: '/v1/orders', headers: { ...auth, 'idempotency-key': 'key-nozone-001' }, payload: { items: [{ product_id: p.id, qty: 1 }], fulfilment: 'delivery', address_id: far.id, payment_method: 'cod' } });
    expect(refused.statusCode).toBe(422); expect(json(refused).error.code).toBe('DELIVERY_ZONE_REQUIRED');
    expect((await ctx.db.query('SELECT count(*)::int n FROM orders WHERE idempotency_key=$1', ['key-nozone-001'])).rows[0].n).toBe(0);
    // owner explicitly opts into straight-line fallback
    await setting(ctx.db, 'delivery', { fallback_mode: 'straight_line' });
    // far delivery => flat 70 total, stored on the order
    const o2 = await app.inject({ method: 'POST', url: '/v1/orders', headers: { ...auth, 'idempotency-key': 'key-far-000001' }, payload: { items: [{ product_id: p.id, qty: 1 }], fulfilment: 'delivery', address_id: far.id, payment_method: 'cod' } });
    expect(o2.statusCode, o2.body).toBe(201);
    const od = json(o2).order; expect(od.totals.delivery_fee).toBe('70.00'); expect(od.totals.total).toBe('1070.00'); expect(Number(od.delivery.distance_km)).toBeGreaterThan(2); expect(od.delivery.method).toBeTruthy();

    // replay with same key returns same order, no second reservation
    const again = await app.inject({ method: 'POST', url: '/v1/orders', headers: { ...auth, 'idempotency-key': 'key-far-000001' }, payload: { items: [{ product_id: p.id, qty: 1 }], fulfilment: 'delivery', address_id: far.id, payment_method: 'cod' } });
    expect(again.statusCode).toBe(200); expect(json(again).order.id).toBe(od.id); expect(json(again).replay).toBe(true);
    const stock = (await ctx.db.query('SELECT stock_qty, reserved_qty FROM products WHERE id=$1', [p.id])).rows[0];
    expect(stock.reserved_qty).toBe(2);

    // a different customer cannot read this order
    const other = await customerToken('9833333333');
    expect((await app.inject({ method: 'GET', url: `/v1/orders/${od.id}`, headers: other.auth })).statusCode).toBe(404);
    void near;
  });
});

describe('admin API', () => {
  it('login failure, lockout, permission checks by role', async () => {
    await ctx.db.query(`INSERT INTO admin_users (email,name,password_hash,role) VALUES ('x@t.test','x',$1,'staff')`, [await hashPassword('correct-horse-9')]);
    for (let i = 0; i < 5; i++) expect((await app.inject({ method: 'POST', url: '/v1/admin/login', payload: { email: 'x@t.test', password: 'nope' } })).statusCode).toBe(401);
    expect((await app.inject({ method: 'POST', url: '/v1/admin/login', payload: { email: 'x@t.test', password: 'correct-horse-9' } })).statusCode).toBe(429);

    const staff = await adminToken('staff'); const owner = await adminToken('owner'); const manager = await adminToken('manager');
    expect((await app.inject({ method: 'GET', url: '/v1/admin/orders', headers: staff })).statusCode).toBe(200);
    expect((await app.inject({ method: 'POST', url: '/v1/admin/categories', headers: staff, payload: { name: 'Nope' } })).statusCode).toBe(403);
    expect((await app.inject({ method: 'GET', url: '/v1/admin/staff', headers: manager })).statusCode).toBe(403);
    expect((await app.inject({ method: 'GET', url: '/v1/admin/audit-logs', headers: manager })).statusCode).toBe(403);
    expect((await app.inject({ method: 'GET', url: '/v1/admin/staff', headers: owner })).statusCode).toBe(200);
    expect((await app.inject({ method: 'GET', url: '/v1/admin/orders' })).statusCode).toBe(401);
    // a customer token is not an admin token
    const c = await customerToken(); expect((await app.inject({ method: 'GET', url: '/v1/admin/orders', headers: c.auth })).statusCode).toBe(401);
  });

  it('settings validation, audit trail, delivery preview and last-owner protection', async () => {
    const owner = await adminToken('owner');
    const bad = await app.inject({ method: 'PUT', url: '/v1/admin/settings/delivery', headers: owner, payload: { base_fee: -5 } });
    expect(bad.statusCode).toBe(400);
    const cur = json(await app.inject({ method: 'GET', url: '/v1/admin/settings', headers: owner })).settings.delivery;
    const ok = await app.inject({ method: 'PUT', url: '/v1/admin/settings/delivery', headers: owner, payload: { ...cur, base_fee: 40 } });
    expect(ok.statusCode).toBe(200);
    const logs = json(await app.inject({ method: 'GET', url: '/v1/admin/audit-logs?action=settings', headers: owner })).logs;
    expect(logs.length).toBe(1);
    const prev1 = json(await app.inject({ method: 'POST', url: '/v1/admin/delivery/preview', headers: owner, payload: { distance_km: 1.5 } }));
    expect(prev1.ok).toBe(true); expect(prev1.fee).toBe('40.00');
    const prev2 = json(await app.inject({ method: 'POST', url: '/v1/admin/delivery/preview', headers: owner, payload: { distance_km: 2.01 } }));
    expect(prev2.fee).toBe('70.00');
    const prevP = json(await app.inject({ method: 'POST', url: '/v1/admin/delivery/preview', headers: owner, payload: { distance_km: 9, fulfilment: 'pickup' } }));
    expect(prevP.fee).toBe('0.00');

    const me = json(await app.inject({ method: 'GET', url: '/v1/admin/me', headers: owner })).admin;
    const demote = await app.inject({ method: 'PUT', url: `/v1/admin/staff/${me.id}`, headers: owner, payload: { email: me.email, name: me.name, role: 'manager', status: 'active' } });
    expect(demote.statusCode).toBe(409);
  });

  it('products: CRUD, price>mrp rejected, duplicate SKU, stock needs reason, images validated', async () => {
    const owner = await adminToken('owner');
    const cat = json(await app.inject({ method: 'POST', url: '/v1/admin/categories', headers: owner, payload: { name: 'Stationery & School Supplies' } })).category;
    const sub = json(await app.inject({ method: 'POST', url: '/v1/admin/categories', headers: owner, payload: { name: 'Notebooks', parent_id: cat.id } })).category;
    const body = { sku: 'NB-1', name: 'Notebook', category_id: cat.id, subcategory_id: sub.id, mrp: '60', price: '50', opening_stock: 10 };
    const bad = await app.inject({ method: 'POST', url: '/v1/admin/products', headers: owner, payload: { ...body, price: '70' } });
    expect(bad.statusCode).toBe(400);
    const created = await app.inject({ method: 'POST', url: '/v1/admin/products', headers: owner, payload: body });
    expect(created.statusCode).toBe(200); const pid = json(created).product.id;
    expect((await app.inject({ method: 'POST', url: '/v1/admin/products', headers: owner, payload: body })).statusCode).toBe(409);
    expect((await app.inject({ method: 'POST', url: `/v1/admin/products/${pid}/stock`, headers: owner, payload: { delta: 5 } })).statusCode).toBe(400);
    const adj = await app.inject({ method: 'POST', url: `/v1/admin/products/${pid}/stock`, headers: owner, payload: { delta: 5, reason: 'New delivery' } });
    expect(json(adj).available).toBe(15);
    const mv = json(await app.inject({ method: 'GET', url: `/v1/admin/products/${pid}/movements`, headers: owner })).movements;
    expect(mv.map((m: any) => m.type)).toEqual(['adjustment', 'opening']);

    // image upload: real PNG ok, text file renamed .jpg rejected
    const png = await sharp({ create: { width: 300, height: 300, channels: 3, background: '#cc3333' } }).png().toBuffer();
    const multipart = (name: string, data: Buffer, type: string) => {
      const b = '----testboundary'; const head = Buffer.from(`--${b}\r\nContent-Disposition: form-data; name="file"; filename="${name}"\r\nContent-Type: ${type}\r\n\r\n`);
      return { headers: { ...owner, 'content-type': `multipart/form-data; boundary=${b}` }, payload: Buffer.concat([head, data, Buffer.from(`\r\n--${b}--\r\n`)]) };
    };
    const up = await app.inject({ method: 'POST', url: `/v1/admin/products/${pid}/images`, ...multipart('a.png', png, 'image/png') });
    expect(up.statusCode).toBe(200); expect(json(up).image.url).toMatch(/\.webp$/);
    const fake = await app.inject({ method: 'POST', url: `/v1/admin/products/${pid}/images`, ...multipart('evil.jpg', Buffer.from('<?php echo 1; ?>'), 'image/jpeg') });
    expect(fake.statusCode).toBe(400); expect(json(fake).error.code).toBe('INVALID_IMAGE');
    const tiny = await sharp({ create: { width: 20, height: 20, channels: 3, background: '#fff' } }).png().toBuffer();
    expect((await app.inject({ method: 'POST', url: `/v1/admin/products/${pid}/images`, ...multipart('t.png', tiny, 'image/png') })).statusCode).toBe(400);
  });

  it('CSV import: preview writes nothing, confirm applies once, re-import is idempotent, updates need opt-in, bad rows never import', async () => {
    const owner = await adminToken('owner');
    const cat = await mkCategory(ctx.db, 'Grocery');
    const csv = ['sku,name,category,mrp,price,stock_qty', 'A-1,Rice,Grocery,100,90,10', 'A-2,Dal,Grocery,200,180,5', 'A-3,Bad price,Grocery,50,60,1', 'A-4,No cat,Nowhere,50,40,1', 'A-1,Dup,Grocery,10,9,1'].join('\n');
    const mp = (content: string, fields: Record<string, string> = {}) => {
      const b = '----imp'; let p = '';
      for (const [k, v] of Object.entries(fields)) p += `--${b}\r\nContent-Disposition: form-data; name="${k}"\r\n\r\n${v}\r\n`;
      p += `--${b}\r\nContent-Disposition: form-data; name="file"; filename="p.csv"\r\nContent-Type: text/csv\r\n\r\n${content}\r\n--${b}--\r\n`;
      return { headers: { ...owner, 'content-type': `multipart/form-data; boundary=${b}` }, payload: p };
    };
    const prev = await app.inject({ method: 'POST', url: '/v1/admin/imports/preview', ...mp(csv) });
    expect(prev.statusCode).toBe(200); const pj = json(prev);
    expect(pj.counts.create).toBe(2); expect(pj.invalid_rows).toBe(3);
    expect((await ctx.db.query('SELECT count(*)::int n FROM products')).rows[0].n).toBe(0);
    const conf = await app.inject({ method: 'POST', url: `/v1/admin/imports/${pj.job_id}/confirm`, headers: owner, payload: {} });
    expect(json(conf).result.created).toBe(2);
    expect((await app.inject({ method: 'POST', url: `/v1/admin/imports/${pj.job_id}/confirm`, headers: owner, payload: {} })).statusCode).toBe(409);
    expect((await ctx.db.query('SELECT count(*)::int n FROM products')).rows[0].n).toBe(2);

    // same file again (valid rows only): nothing to change
    const clean = ['sku,name,category,mrp,price,stock_qty', 'A-1,Rice,Grocery,100,90,10', 'A-2,Dal,Grocery,200,180,5'].join('\n');
    const again = json(await app.inject({ method: 'POST', url: '/v1/admin/imports/preview', ...mp(clean) }));
    expect(again.counts).toEqual({ create: 0, update: 0, unchanged: 2 });

    // price change is a visible update and is skipped unless updates are enabled
    const changed = ['sku,name,category,mrp,price,stock_qty', 'A-1,Rice,Grocery,100,95,10'].join('\n');
    const pc = json(await app.inject({ method: 'POST', url: '/v1/admin/imports/preview', ...mp(changed) }));
    expect(pc.counts.update).toBe(1); expect(pc.sample[0].diff.price).toEqual({ from: '90.00', to: '95.00' });
    const skip = json(await app.inject({ method: 'POST', url: `/v1/admin/imports/${pc.job_id}/confirm`, headers: owner, payload: {} })).result;
    expect(skip.updated).toBe(0); expect(skip.skipped_updates).toBe(1);
    expect((await ctx.db.query(`SELECT price FROM products WHERE sku='A-1'`)).rows[0].price).toBe('90.00');
    const pc2 = json(await app.inject({ method: 'POST', url: '/v1/admin/imports/preview', ...mp(changed, { apply_updates: 'true' }) }));
    expect(json(await app.inject({ method: 'POST', url: `/v1/admin/imports/${pc2.job_id}/confirm`, headers: owner, payload: {} })).result.updated).toBe(1);
    expect((await ctx.db.query(`SELECT price FROM products WHERE sku='A-1'`)).rows[0].price).toBe('95.00');

    // edited after preview => skipped, not overwritten
    const changed2 = ['sku,name,category,mrp,price', 'A-2,Dal,Grocery,200,170'].join('\n');
    const pc3 = json(await app.inject({ method: 'POST', url: '/v1/admin/imports/preview', ...mp(changed2, { apply_updates: 'true' }) }));
    await ctx.db.query(`UPDATE products SET price=175 WHERE sku='A-2'`);
    const c3 = json(await app.inject({ method: 'POST', url: `/v1/admin/imports/${pc3.job_id}/confirm`, headers: owner, payload: {} })).result;
    expect(c3.updated).toBe(0); expect(c3.conflicts.length).toBe(1);
    expect((await ctx.db.query(`SELECT price FROM products WHERE sku='A-2'`)).rows[0].price).toBe('175.00');
    void cat;
  });

  it('order handling: staff moves order along, invalid jump blocked, cancel needs reason and releases stock, invoice escapes HTML', async () => {
    const owner = await adminToken('owner');
    const p = await mkProduct(ctx.db, { price: 1200, stock: 5, name: '<script>alert(1)</script>' });
    const { body, auth } = await customerToken();
    const place = async (key: string) => json(await app.inject({ method: 'POST', url: '/v1/orders', headers: { ...auth, 'idempotency-key': key }, payload: { items: [{ product_id: p.id, qty: 1 }], fulfilment: 'pickup', payment_method: 'cod' } })).order;
    const o = await place('order-key-0001');
    const jump = await app.inject({ method: 'POST', url: `/v1/admin/orders/${o.id}/status`, headers: owner, payload: { status: 'delivered' } });
    expect(jump.statusCode).toBe(409);
    const acc = await app.inject({ method: 'POST', url: `/v1/admin/orders/${o.id}/status`, headers: owner, payload: { status: 'accepted' } });
    expect(json(acc).order.status).toBe('accepted');
    expect((await app.inject({ method: 'POST', url: `/v1/admin/orders/${o.id}/status`, headers: owner, payload: { status: 'cancelled' } })).statusCode).toBe(400);
    const can = await app.inject({ method: 'POST', url: `/v1/admin/orders/${o.id}/status`, headers: owner, payload: { status: 'cancelled', reason: 'Out of stock at shelf' } });
    expect(json(can).order.status).toBe('cancelled');
    expect((await ctx.db.query('SELECT reserved_qty FROM products WHERE id=$1', [p.id])).rows[0].reserved_qty).toBe(0);
    const inv = await app.inject({ method: 'GET', url: `/v1/admin/orders/${o.id}/invoice`, headers: owner });
    expect(inv.statusCode).toBe(200); expect(inv.body).not.toContain('<script>alert(1)</script>'); expect(inv.body).toContain('&lt;script&gt;');
    void body; void setting;
  });
});

describe('public web pages (Play Store URLs)', () => {
  it('serves the privacy policy and account-deletion pages without login, escapes admin-edited text, and 404s unknown keys', async () => {
    const owner = await adminToken('owner');
    const cur = json(await app.inject({ method: 'GET', url: '/v1/admin/settings', headers: owner })).settings.policies;
    const put = await app.inject({ method: 'PUT', url: '/v1/admin/settings/policies', headers: owner, payload: { ...cur, privacy: { en: 'We keep <b>data</b> safe <script>alert(1)</script>', hi: 'हम डेटा सुरक्षित रखते हैं' } } });
    expect(put.statusCode).toBe(200);
    const r = await app.inject({ method: 'GET', url: '/policy/privacy' });
    expect(r.statusCode).toBe(200); expect(r.headers['content-type']).toContain('text/html');
    expect(r.body).toContain('हम डेटा सुरक्षित रखते हैं'); expect(r.body).not.toContain('<script>alert(1)</script>'); expect(r.body).toContain('&lt;script&gt;');
    expect((await app.inject({ method: 'GET', url: '/policy/nope' })).statusCode).toBe(404);
    const d = await app.inject({ method: 'GET', url: '/account-deletion' });
    expect(d.statusCode).toBe(200); expect(d.body).toContain('Delete your account');
  });
});
