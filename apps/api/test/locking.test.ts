import { describe, it, expect, afterAll, beforeEach } from 'vitest';
import { randomUUID } from 'node:crypto';
import { makeCtx, reset, mkProduct, mkUser, openStore } from './helpers.js';
import { withTx, TX_MAX_ATTEMPTS } from '../src/db/pool.js';
import { createOrder, getOrderDetail, transitionOrder } from '../src/services/orders.js';
import { adminRefund, applyPaymentCaptured, applyRefundProcessed, createPaymentSession, confirmPayment } from '../src/services/payments.js';

// Money rows are always locked orders → payments → refunds, and withTx retries whole transactions on deadlock.
const ctx = makeCtx();
const db = ctx.db;
afterAll(async () => { await db.end(); });
beforeEach(async () => { await reset(db); await openStore(db); });

const mkAdmin = async () => (await db.query(`INSERT INTO admin_users (email,name,password_hash,role) VALUES ($1,'Owner','x','owner') RETURNING id`, [`${randomUUID()}@t.test`])).rows[0].id as string;
async function pendingOnlineOrder() {
  const u = await mkUser(db); const p = await mkProduct(db, { price: 1000, stock: 50 });
  const r = await createOrder(ctx, u.id, { idempotency_key: randomUUID(), items: [{ product_id: p.id, qty: 1 }], fulfilment: 'pickup', payment_method: 'online' });
  const s = await createPaymentSession(ctx, r.orderId, u.id);
  return { u, orderId: r.orderId, providerOrderId: s.provider_order_id };
}
/** Wait until some backend is blocked on a row lock (i.e. the concurrent transaction under test is waiting). */
async function untilSomeoneWaits() {
  for (let i = 0; i < 100; i++) {
    const n = (await db.query(`SELECT count(*)::int n FROM pg_locks WHERE NOT granted AND locktype IN ('transactionid','tuple')`)).rows[0].n;
    if (n > 0) return;
    await new Promise((r) => setTimeout(r, 50));
  }
  throw new Error('the concurrent transaction never started waiting');
}
/**
 * Simulates a cancellation / admin refund: holds the ORDER lock, then asks for the PAYMENT lock while `other` runs.
 * With the old payment→order order, `other` would already hold the payment row here and this request would hang
 * until a deadlock was detected; lock_timeout (shorter than deadlock_timeout) turns that hang into a test failure.
 */
async function holdOrderThenPayment(orderId: string, other: () => Promise<unknown>) {
  const c = await db.connect();
  try {
    await c.query('BEGIN');
    await c.query(`SET LOCAL lock_timeout = '500ms'`);
    await c.query('SELECT id FROM orders WHERE id=$1 FOR UPDATE', [orderId]);
    const running = other();
    await untilSomeoneWaits();
    await c.query('SELECT id FROM payments WHERE order_id=$1 FOR UPDATE', [orderId]); // must not wait on `other`
    await c.query('COMMIT');
    return await running;
  } catch (e) { await c.query('ROLLBACK').catch(() => {}); throw e; } finally { c.release(); }
}

describe('withTx bounded retry', () => {
  const marker = () => `retry-test-${randomUUID()}`;
  const rows = async (m: string) => (await db.query(`SELECT count(*)::int n FROM audit_logs WHERE action=$1`, [m])).rows[0].n;
  const deadlock = () => Object.assign(new Error('deadlock detected'), { code: '40P01' });

  it('re-runs the whole transaction after a deadlock; the failed attempt leaves no rows', async () => {
    const m = marker(); let calls = 0;
    const out = await withTx(db, async (tx) => {
      calls++;
      await tx.query(`INSERT INTO audit_logs (actor_type, action, entity) VALUES ('system',$1,'test')`, [m]);
      if (calls === 1) throw deadlock();
      return 'done';
    });
    expect(out).toBe('done'); expect(calls).toBe(2); expect(await rows(m)).toBe(1);
  });
  it(`gives up after ${TX_MAX_ATTEMPTS} attempts and writes nothing`, async () => {
    const m = marker(); let calls = 0;
    await expect(withTx(db, async (tx) => { calls++; await tx.query(`INSERT INTO audit_logs (actor_type, action, entity) VALUES ('system',$1,'test')`, [m]); throw deadlock(); })).rejects.toMatchObject({ code: '40P01' });
    expect(calls).toBe(TX_MAX_ATTEMPTS); expect(await rows(m)).toBe(0);
  });
  it('does not retry other errors', async () => {
    let calls = 0;
    await expect(withTx(db, async () => { calls++; throw Object.assign(new Error('unique'), { code: '23505' }); })).rejects.toMatchObject({ code: '23505' });
    expect(calls).toBe(1);
  });
});

describe('lock order: capture / refund webhooks lock the order before the payment', () => {
  it('a payment capture waits for a cancellation holding the order, instead of deadlocking it', async () => {
    const { orderId, providerOrderId } = await pendingOnlineOrder();
    const outcome = await holdOrderThenPayment(orderId, () => withTx(db, (tx) => applyPaymentCaptured(tx, { providerOrderId, providerPaymentId: `pay_${randomUUID()}`, amountPaise: 100000 })));
    expect(outcome).toBe('paid');
    expect((await getOrderDetail(db, orderId)).payment_status).toBe('paid');
  });

  it('a refund-processed event waits for a cancellation holding the order, instead of deadlocking it', async () => {
    const admin = await mkAdmin(); const { u, orderId, providerOrderId } = await pendingOnlineOrder();
    const sim = ctx.payments.simulatePayment(providerOrderId, 100000);
    await confirmPayment(ctx, u.id, { providerOrderId, providerPaymentId: sim.providerPaymentId, signature: sim.signature });
    const refund = (await db.query(`INSERT INTO refunds (payment_id, order_id, amount, reason, created_by) SELECT id, order_id, 200, 'test', $2 FROM payments WHERE provider_order_id=$1 RETURNING id`, [providerOrderId, admin])).rows[0];
    await holdOrderThenPayment(orderId, () => withTx(db, (tx) => applyRefundProcessed(tx, { providerPaymentId: sim.providerPaymentId, providerRefundId: `rfnd_${randomUUID()}`, amountPaise: 20000 })));
    expect((await db.query('SELECT status FROM refunds WHERE id=$1', [refund.id])).rows[0].status).toBe('processed');
    expect((await getOrderDetail(db, orderId)).payment_status).toBe('partially_refunded');
  });
});

describe('concurrent late capture vs cancellation', () => {
  it('whichever wins, the money is refunded exactly once and nothing errors', async () => {
    const admin = await mkAdmin();
    for (let i = 0; i < 8; i++) {
      const { orderId, providerOrderId } = await pendingOnlineOrder();
      const res = await Promise.allSettled([
        withTx(db, (tx) => applyPaymentCaptured(tx, { providerOrderId, providerPaymentId: `pay_${randomUUID()}`, amountPaise: 100000 })),
        transitionOrder(ctx, orderId, 'cancelled', { type: 'admin', id: admin }, { reason: 'race test' }),
      ]);
      expect(res.map((r) => r.status)).toEqual(['fulfilled', 'fulfilled']);
      const refunds = (await db.query('SELECT amount FROM refunds WHERE order_id=$1', [orderId])).rows;
      expect(refunds).toEqual([{ amount: '1000.00' }]);
      expect((await db.query(`SELECT count(*)::int n FROM payments WHERE order_id=$1 AND status='paid'`, [orderId])).rows[0].n).toBe(1);
      expect((await getOrderDetail(db, orderId)).status).toBe('refund_pending');
    }
  });

  it('concurrent admin refunds never exceed the paid amount', async () => {
    const admin = await mkAdmin(); const { u, orderId, providerOrderId } = await pendingOnlineOrder();
    const sim = ctx.payments.simulatePayment(providerOrderId, 100000);
    await confirmPayment(ctx, u.id, { providerOrderId, providerPaymentId: sim.providerPaymentId, signature: sim.signature });
    await Promise.allSettled([1, 2, 3, 4].map(() => adminRefund(ctx, orderId, admin, '400', 'race')));
    const total = (await db.query(`SELECT COALESCE(SUM(amount),0)::numeric(12,2)::text s FROM refunds WHERE order_id=$1 AND status IN ('pending','processing','processed')`, [orderId])).rows[0].s;
    expect(total).toBe('800.00'); // two ₹400 fit into ₹1,000, the other two are refused
  });
});
