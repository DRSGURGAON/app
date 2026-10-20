import type { FastifyInstance } from 'fastify';
import type { RouteDeps } from '../app.js';
import { loadSettings } from '../services/settings.js';

const esc = (v: unknown) => String(v ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]!));
const TITLES: Record<string, string> = { privacy: 'Privacy Policy', terms: 'Terms & Conditions', delivery: 'Delivery Policy', cancellation: 'Cancellation Policy', refund: 'Refund Policy' };

const page = (title: string, body: string) => `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${esc(title)}</title>
<style>body{font:16px/1.6 system-ui,sans-serif;max-width:720px;margin:0 auto;padding:20px;color:#1b1f1b}h1{color:#1b5e20;font-size:24px}pre{white-space:pre-wrap;font:inherit}.muted{color:#5e675e}a{color:#1b5e20}</style></head><body>${body}</body></html>`;

/** Public, unauthenticated web pages (needed for Play Store listing: privacy policy URL and account-deletion URL). Content comes from Admin → Store & policies. */
export async function publicPageRoutes(app: FastifyInstance, { ctx }: RouteDeps) {
  app.get('/policy/:key', async (req, reply) => {
    const key = String((req.params as any).key);
    if (!TITLES[key]) return reply.status(404).type('text/html').send(page('Not found', '<h1>Page not found</h1>'));
    const s = await loadSettings(ctx.db); const p = (s.policies as any)[key] as { en: string; hi: string };
    const store = s.store;
    return reply.type('text/html; charset=utf-8').send(page(`${TITLES[key]} · ${store.name_en}`,
      `<h1>${esc(TITLES[key])}</h1><p class="muted">${esc(store.name_en)} · ${esc(store.address_en)} · Phone ${esc(store.phone)}</p><h2>English</h2><pre>${esc(p.en)}</pre><h2>हिन्दी</h2><pre>${esc(p.hi)}</pre>`));
  });
  app.get('/account-deletion', async (_req, reply) => {
    const s = (await loadSettings(ctx.db)).store;
    return reply.type('text/html; charset=utf-8').send(page(`Delete your account · ${s.name_en}`,
      `<h1>Delete your account and data</h1><p>You can ask us to delete your ${esc(s.name_en)} account and personal data (name, phone number, saved addresses, device tokens, notifications).</p>
<h2>In the app</h2><p>Account → Delete my account.</p><h2>Without the app</h2><p>Call or WhatsApp <b>${esc(s.phone)}</b> from your registered mobile number and ask for account deletion. We process requests within 7 days, once any open orders are completed.</p>
<h2>What is kept</h2><p>Order and invoice records are retained as required for accounting and tax purposes, without your personal details (name, phone number, saved addresses).</p>`));
  });
}
