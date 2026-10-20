import { describe, it, expect, afterAll, beforeEach } from 'vitest';
import { makeCtx, reset, mkUser, setting } from './helpers.js';
import { postLedger, getBalance, walletSummary, listTransactions, expireAllDue } from '../src/services/coins.js';
import { loadSettings } from '../src/services/settings.js';

const ctx = makeCtx(); const db = ctx.db;
afterAll(async () => { await db.end(); });
beforeEach(async () => { await reset(db); });

async function post(args: Parameters<typeof postLedger>[1]) {
  const c = await db.connect();
  try { await c.query('BEGIN'); const r = await postLedger(c, args); await c.query('COMMIT'); return r; } catch (e) { await c.query('ROLLBACK'); throw e; } finally { c.release(); }
}

describe('coins ledger', () => {
  it('is append-only: UPDATE and DELETE are rejected by the database', async () => {
    const u = await mkUser(db); await post({ userId: u.id, type: 'adjust', coins: 10, ref: 'r1' });
    await expect(db.query('UPDATE wallet_transactions SET coins = 999')).rejects.toThrow(/append-only/);
    await expect(db.query('DELETE FROM wallet_transactions')).rejects.toThrow(/append-only/);
    await expect(db.query(`INSERT INTO audit_logs (actor_type, action) VALUES ('system','x')`).then(() => db.query('DELETE FROM audit_logs'))).rejects.toThrow(/append-only/);
  });
  it('duplicate reference never double-credits or double-debits', async () => {
    const u = await mkUser(db);
    expect((await post({ userId: u.id, type: 'earn', coins: 25, ref: 'order:1:earn' })).duplicate).toBe(false);
    expect((await post({ userId: u.id, type: 'earn', coins: 25, ref: 'order:1:earn' })).duplicate).toBe(true);
    await post({ userId: u.id, type: 'redeem', coins: -5, ref: 'order:2:redeem' }); await post({ userId: u.id, type: 'redeem', coins: -5, ref: 'order:2:redeem' });
    expect(await getBalance(db, u.id)).toBe(20);
    expect((await listTransactions(db, u.id)).map((t) => t.coins)).toEqual([-5, 25]);
  });
  it('cannot spend more than the balance, and the balance can never go negative', async () => {
    const u = await mkUser(db); await post({ userId: u.id, type: 'adjust', coins: 10, ref: 'g' });
    await expect(post({ userId: u.id, type: 'redeem', coins: -11, ref: 'x' })).rejects.toMatchObject({ code: 'INSUFFICIENT_COINS' });
    await expect(db.query('UPDATE wallets SET balance = -1')).rejects.toThrow();
    expect(await getBalance(db, u.id)).toBe(10);
  });
  it('concurrent redemptions cannot overspend (balance 10, 6 x 4 coins -> exactly 2 succeed)', async () => {
    const u = await mkUser(db); await post({ userId: u.id, type: 'adjust', coins: 10, ref: 'g' });
    const res = await Promise.allSettled(Array.from({ length: 6 }, (_, i) => post({ userId: u.id, type: 'redeem', coins: -4, ref: `c${i}` })));
    expect(res.filter((r) => r.status === 'fulfilled')).toHaveLength(2); expect(await getBalance(db, u.id)).toBe(2);
    const sum = (await db.query('SELECT SUM(coins)::int s FROM wallet_transactions WHERE user_id=$1', [u.id])).rows[0].s; expect(sum).toBe(2);
  });
  it('balance_after in every row matches the running total', async () => {
    const u = await mkUser(db);
    for (const [i, c] of [10, -3, 7, -9].entries()) await post({ userId: u.id, type: c > 0 ? 'adjust' : 'redeem', coins: c, ref: `s${i}` });
    const rows = (await db.query('SELECT coins, balance_after FROM wallet_transactions ORDER BY id')).rows;
    let run = 0; for (const r of rows) { run += r.coins; expect(r.balance_after).toBe(run); }
  });
});

describe('expiry', () => {
  it('expired coins are removed by the sweep, logged in the ledger, and cannot be spent', async () => {
    const u = await mkUser(db);
    await post({ userId: u.id, type: 'earn', coins: 40, ref: 'e1', expiryDays: 30 });
    await db.query(`UPDATE coin_lots SET expires_at = now() - interval '1 day'`);
    expect(await getBalance(db, u.id)).toBe(0); // never advertised as spendable
    await expect(post({ userId: u.id, type: 'redeem', coins: -1, ref: 'r' })).rejects.toMatchObject({ code: 'INSUFFICIENT_COINS' });
    expect(await expireAllDue(db as any)).toBe(40); // the failed spend rolled back, so the scheduled sweep does the removal
    expect((await db.query('SELECT balance FROM wallets WHERE user_id=$1', [u.id])).rows[0].balance).toBe(0);
  });
  it('sweep job posts an expire entry and is idempotent', async () => {
    const u = await mkUser(db); await post({ userId: u.id, type: 'earn', coins: 40, ref: 'e1', expiryDays: 30 }); await post({ userId: u.id, type: 'earn', coins: 5, ref: 'e2' });
    await db.query(`UPDATE coin_lots SET expires_at = now() - interval '1 day' WHERE coins = 40`);
    expect(await expireAllDue(db as any)).toBe(40); expect(await expireAllDue(db as any)).toBe(0);
    expect(await getBalance(db, u.id)).toBe(5);
    expect((await db.query(`SELECT type, coins, balance_after FROM wallet_transactions WHERE type='expire'`)).rows).toEqual([{ type: 'expire', coins: -40, balance_after: 5 }]);
    const s = await walletSummary(db, u.id, (await loadSettings(db)).coins);
    expect(s).toMatchObject({ balance: 5, earned: 45, reversed_or_expired: 40 });
  });
  it('spends the soonest-expiring coins first (FIFO by expiry)', async () => {
    const u = await mkUser(db);
    await post({ userId: u.id, type: 'earn', coins: 10, ref: 'never' });                    // no expiry
    await post({ userId: u.id, type: 'earn', coins: 10, ref: 'soon', expiryDays: 5 });
    await post({ userId: u.id, type: 'redeem', coins: -10, ref: 'spend' });
    const lots = (await db.query('SELECT coins, remaining, expires_at IS NULL AS never FROM coin_lots ORDER BY id')).rows;
    expect(lots).toEqual([{ coins: 10, remaining: 10, never: true }, { coins: 10, remaining: 0, never: false }]);
  });
  it('expiry_days = 0 means coins never expire', async () => {
    const u = await mkUser(db); await setting(db, 'coins', { expiry_days: 0 });
    await post({ userId: u.id, type: 'earn', coins: 10, ref: 'n', expiryDays: 0 });
    expect((await db.query('SELECT expires_at FROM coin_lots')).rows[0].expires_at).toBeNull();
  });
});
