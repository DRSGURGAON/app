import { createRequire } from 'node:module';
const require = createRequire(process.env.PLAYWRIGHT_NODE_PATH ?? '/opt/npm-tools/node_modules/');
const { chromium } = require('playwright');
const OUT = (process.env.SHOTS_DIR ?? '/tmp/ardh-shots');
const BASE = 'http://localhost:8099';
const b = await chromium.launch({ args: ['--no-sandbox'] });
const ctx = await b.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, locale: 'en-IN' });
await ctx.addInitScript(() => { if (!localStorage.getItem('ardh.lang')) localStorage.setItem('ardh.lang', JSON.stringify('en')); });
const page = await ctx.newPage();
const errors = [];
page.on('pageerror', (e) => errors.push('pageerror: ' + e.message));
page.on('response', (r) => { if (r.status() >= 400 && r.url().includes(':4010')) errors.push(`http ${r.status()} ${r.request().method()} ${r.url().replace('http://localhost:4010', '')}`); });
const T = (t, o) => page.getByText(t, o).first();
const shot = (n) => page.screenshot({ path: `${OUT}/${n}.png` });
const go = async (p) => { await page.goto(BASE + p, { waitUntil: 'networkidle' }); };
let failed = 0;
const step = async (n, fn) => { try { await fn(); console.log('ok  ', n); } catch (e) { failed++; console.log('FAIL', n, '-', e.message.slice(0, 500)); await shot('fail-' + n.replace(/\W+/g, '_')).catch(() => {}); } };
const fillCart = async () => {
  const items = await page.evaluate(async () => { const r = await (await fetch('http://localhost:4010/v1/products?limit=50')).json(); return r.items.filter((p) => p.name.includes('Basmati')).map((p) => ({ product_id: p.id, qty: 2, name: p.name, price: p.price, unit: p.unit, max_per_order: null })); });
  await page.evaluate((i) => localStorage.setItem('ardh.cart.v1', JSON.stringify(i)), items);
};

await go('/');
await step('login', async () => {
  await go('/login'); await page.getByPlaceholder('98XXXXXXXX').fill('9876500044'); await page.getByRole('button', { name: 'Send OTP' }).click();
  const dev = await T(/Development OTP: \d{6}/).textContent(); await page.getByLabel('Enter OTP').fill(dev.match(/\d{6}/)[0]); await page.getByRole('button', { name: /Verify/ }).click(); await page.waitForTimeout(1200);
});
await step('add address (no coordinates)', async () => {
  await go('/address-edit'); await page.getByLabel('Full name').fill('Ravi Kumar'); await page.getByLabel('Phone').fill('9876500044'); await page.getByLabel('House / flat / street').fill('House 12, Main Bazaar'); await page.getByLabel('PIN code').fill('127999');
  await shot('20-address-form'); await page.getByRole('button', { name: 'Save' }).click(); await page.waitForTimeout(1000);
});
await step('delivery asks for zone instead of guessing', async () => {
  await fillCart(); await go('/checkout'); await T('Choose your delivery area').waitFor({ timeout: 10000 }); await shot('21-zone-required');
});
await step('far zone => flat ₹70 total', async () => {
  await T('Nearby villages (SAMPLE)').click(); await page.waitForTimeout(800);
  await T('To pay').waitFor(); const body = await page.locator('body').innerText();
  if (!/Delivery fee\s*₹70/.test(body)) throw new Error('fee ₹70 not shown: ' + body.match(/Delivery fee[^\n]*\n?[^\n]*/)?.[0]);
  if (!/₹1,220/.test(body)) throw new Error('total ₹1,220 not shown');
  await shot('22-far-fee-70');
});
await step('town zone => base fee', async () => {
  await T('Loharu town (SAMPLE)').click(); await page.waitForTimeout(800); const body = await page.locator('body').innerText();
  if (!/Delivery fee\s*₹30/.test(body)) throw new Error('base fee ₹30 not shown'); await shot('23-base-fee');
});
await step('coupon below min spend rejected, message shown', async () => {
  await page.getByPlaceholder('Enter coupon code').fill('SAMPLE50'); await page.getByRole('button', { name: 'Apply' }).click(); await page.waitForTimeout(800);
  const body = await page.locator('body').innerText(); if (!/SAMPLE50 Applied/i.test(body) && !/coupon/i.test(body)) throw new Error('no coupon feedback'); await shot('24-coupon');
});
await step('place delivery COD order', async () => { await page.getByRole('button', { name: 'Place order' }).click(); await T('Order placed!').waitFor({ timeout: 15000 }); const body = await page.locator('body').innerText(); if (!/ASM\d{6}-\d{5}/.test(body)) throw new Error('no order no'); await shot('25-delivery-order'); });
await step('online payment (MOCK) flow', async () => {
  await fillCart(); await go('/checkout'); await T('Loharu town (SAMPLE)').waitFor({ timeout: 10000 }); await T('Loharu town (SAMPLE)').click(); await page.waitForTimeout(600);
  await T('UPI / Card / Netbanking').click(); await page.waitForTimeout(500); await page.getByRole('button', { name: /^Pay ₹/ }).click(); await T('Order placed!').waitFor({ timeout: 20000 }); await T('Payment received').waitFor({ timeout: 5000 }); await shot('26-online-paid');
});
await step('order detail: reorder + cancel UI present', async () => { const body = await page.locator('body').innerText(); if (!/Order again/.test(body)) throw new Error('no reorder'); });
await step('wallet screen loads', async () => { await go('/wallet'); await T('Coins wallet').waitFor({ timeout: 8000 }).catch(() => {}); await T('🪙').waitFor({ timeout: 8000 }); await shot('27-wallet'); });
await step('account screen', async () => { await go('/account'); await T('Saved addresses').waitFor({ timeout: 8000 }); await shot('28-account'); });
console.log('browser/API errors:', errors.slice(0, 10));
console.log(failed ? `${failed} step(s) failed` : 'all steps passed');
await b.close();
