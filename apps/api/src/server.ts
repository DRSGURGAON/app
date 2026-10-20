import { loadConfig } from './config.js';
import { createPool } from './db/pool.js';
import { migrate } from './db/migrate.js';
import { buildApp } from './app.js';
import { createCtx } from './context.js';
import { expireUnpaidOrders } from './services/orders.js';
import { processPendingRefunds } from './services/payments.js';
import { expireAllDue } from './services/coins.js';
import { flushPush } from './services/notifications.js';

const config = loadConfig();
const db = createPool(config.DATABASE_URL, 15);
const ctx = createCtx(config, db);

if (process.env.AUTO_MIGRATE === 'true') {
  const applied = await migrate(db, (m) => console.log(m));
  console.log(applied.length ? `Applied ${applied.length} migration(s)` : 'Database up to date');
}

const app = await buildApp(ctx);

// Background workers. Each is idempotent, so running two API instances is safe.
const timers: NodeJS.Timeout[] = [];
const every = (name: string, ms: number, fn: () => Promise<unknown>) => {
  let running = false;
  timers.push(setInterval(async () => {
    if (running) return; running = true;
    try { await fn(); } catch (e) { app.log.error({ err: e }, `worker ${name} failed`); } finally { running = false; }
  }, ms).unref());
};
every('expire-unpaid-orders', 60_000, () => expireUnpaidOrders(ctx));
every('refund-retry', 120_000, () => processPendingRefunds(ctx));
every('coin-expiry', 6 * 3600_000, () => expireAllDue(db));
every('push-flush', 15_000, () => flushPush(db, ctx.push));

const shutdown = async (sig: string) => {
  app.log.info(`${sig} received, shutting down`);
  timers.forEach(clearInterval);
  try { await app.close(); await db.end(); } finally { process.exit(0); }
};
process.on('SIGTERM', () => void shutdown('SIGTERM'));
process.on('SIGINT', () => void shutdown('SIGINT'));

await app.listen({ port: config.PORT, host: '0.0.0.0' });
