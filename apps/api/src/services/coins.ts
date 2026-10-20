import type { Queryable, Tx } from '../db/pool.js';
import { AppError } from '../lib/errors.js';
import type { AppSettings } from './settings.js';

export type CoinTxnType = 'earn' | 'redeem' | 'redeem_refund' | 'earn_reversal' | 'expire' | 'adjust';

export interface PostArgs {
  userId: string;
  type: CoinTxnType;
  coins: number;               // signed: credits > 0, debits < 0
  ref: string;                 // unique idempotency reference
  orderId?: string | null;
  note?: string | null;
  adminId?: string | null;
  expiryDays?: number;         // for credit lots; 0 / undefined = never expires
}

export interface PostResult { duplicate: boolean; balanceAfter: number; txnId: number | null }

export async function ensureWallet(q: Queryable, userId: string): Promise<void> {
  await q.query('INSERT INTO wallets (user_id) VALUES ($1) ON CONFLICT DO NOTHING', [userId]);
}

/** Move coins from expired lots out of the balance (idempotent). Call inside a tx holding the wallet lock. */
async function sweepExpired(tx: Tx, userId: string): Promise<number> {
  const { rows } = await tx.query(
    `SELECT id, remaining FROM coin_lots WHERE user_id = $1 AND remaining > 0 AND expires_at IS NOT NULL AND expires_at <= now() ORDER BY id`, [userId]);
  let total = 0;
  for (const lot of rows) {
    const bal = (await tx.query('SELECT balance FROM wallets WHERE user_id=$1', [userId])).rows[0].balance as number;
    const newBal = bal - lot.remaining;
    const ins = await tx.query(
      `INSERT INTO wallet_transactions (user_id, type, coins, balance_after, ref, note) VALUES ($1,'expire',$2,$3,$4,'Coins expired')
       ON CONFLICT (ref) DO NOTHING RETURNING id`, [userId, -lot.remaining, newBal, `expire:lot:${lot.id}`]);
    if (ins.rowCount) {
      await tx.query('UPDATE wallets SET balance=$2, updated_at=now() WHERE user_id=$1', [userId, newBal]);
      total += lot.remaining;
    }
    await tx.query('UPDATE coin_lots SET remaining = 0 WHERE id = $1', [lot.id]);
  }
  return total;
}

export async function postLedger(tx: Tx, a: PostArgs): Promise<PostResult> {
  if (!Number.isInteger(a.coins) || a.coins === 0) throw new AppError(400, 'BAD_COINS', 'Coin amount must be a non-zero integer');
  await ensureWallet(tx, a.userId);
  await tx.query('SELECT balance FROM wallets WHERE user_id=$1 FOR UPDATE', [a.userId]);

  const dup = await tx.query('SELECT id, balance_after FROM wallet_transactions WHERE ref=$1', [a.ref]);
  if (dup.rowCount) return { duplicate: true, balanceAfter: dup.rows[0].balance_after, txnId: dup.rows[0].id };

  await sweepExpired(tx, a.userId);
  const balance = (await tx.query('SELECT balance FROM wallets WHERE user_id=$1', [a.userId])).rows[0].balance as number;
  const newBalance = balance + a.coins;
  if (newBalance < 0) throw new AppError(409, 'INSUFFICIENT_COINS', 'Not enough coins in the wallet');

  const ins = await tx.query(
    `INSERT INTO wallet_transactions (user_id, type, coins, balance_after, order_id, ref, note, admin_id)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING id`,
    [a.userId, a.type, a.coins, newBalance, a.orderId ?? null, a.ref, a.note ?? null, a.adminId ?? null]);
  const txnId = ins.rows[0].id as number;
  await tx.query('UPDATE wallets SET balance=$2, updated_at=now() WHERE user_id=$1', [a.userId, newBalance]);

  if (a.coins > 0) {
    const exp = a.expiryDays && a.expiryDays > 0 ? `now() + make_interval(days => ${Math.floor(a.expiryDays)})` : 'NULL';
    await tx.query(
      `INSERT INTO coin_lots (user_id, source_txn, coins, remaining, expires_at) VALUES ($1,$2,$3,$3, ${exp})`,
      [a.userId, txnId, a.coins]);
  } else {
    // consume lots: soonest-expiring first, never-expiring last
    let need = -a.coins;
    const lots = await tx.query(
      `SELECT id, remaining FROM coin_lots WHERE user_id=$1 AND remaining>0 AND (expires_at IS NULL OR expires_at > now())
       ORDER BY expires_at NULLS LAST, id FOR UPDATE`, [a.userId]);
    for (const lot of lots.rows) {
      if (need <= 0) break;
      const take = Math.min(need, lot.remaining);
      await tx.query('UPDATE coin_lots SET remaining = remaining - $2 WHERE id=$1', [lot.id, take]);
      need -= take;
    }
    // Any remainder means lots and wallet disagree (legacy adjustments). Balance check above already guarantees funds.
  }
  return { duplicate: false, balanceAfter: newBalance, txnId };
}

export async function getBalance(q: Queryable, userId: string): Promise<number> {
  const r = await q.query(
    `SELECT COALESCE(SUM(remaining),0)::int AS spendable FROM coin_lots WHERE user_id=$1 AND remaining>0 AND (expires_at IS NULL OR expires_at > now())`, [userId]);
  const w = await q.query('SELECT balance FROM wallets WHERE user_id=$1', [userId]);
  const bal = w.rows[0]?.balance ?? 0;
  // spendable can differ from balance only for legacy rows; never advertise more than either.
  return Math.min(bal, r.rows[0].spendable);
}

export async function walletSummary(q: Queryable, userId: string, coins: AppSettings['coins']) {
  const bal = await getBalance(q, userId);
  const agg = await q.query(
    `SELECT type, COALESCE(SUM(coins),0)::int AS total FROM wallet_transactions WHERE user_id=$1 GROUP BY type`, [userId]);
  const t: Record<string, number> = {};
  for (const r of agg.rows) t[r.type] = r.total;
  const pending = await q.query(
    `SELECT COALESCE(SUM(coins_to_earn),0)::int AS pending FROM orders
      WHERE user_id=$1 AND coins_credited_at IS NULL AND status IN ('pending_payment','placed','accepted','packing','ready_for_dispatch','out_for_delivery','ready_for_pickup')`, [userId]);
  const nextExpiry = await q.query(
    `SELECT expires_at, SUM(remaining)::int AS coins FROM coin_lots WHERE user_id=$1 AND remaining>0 AND expires_at > now()
      GROUP BY expires_at ORDER BY expires_at LIMIT 1`, [userId]);
  return {
    enabled: coins.enabled,
    balance: bal,
    pending: pending.rows[0].pending as number,
    earned: (t.earn ?? 0) + Math.max(t.adjust ?? 0, 0),
    redeemed: -(t.redeem ?? 0) - (t.redeem_refund ?? 0),
    reversed_or_expired: -((t.earn_reversal ?? 0) + (t.expire ?? 0)),
    coin_value: coins.coin_value,
    next_expiry: nextExpiry.rows[0] ? { at: nextExpiry.rows[0].expires_at, coins: nextExpiry.rows[0].coins } : null,
  };
}

export async function listTransactions(q: Queryable, userId: string, limit = 50, beforeId?: number) {
  const { rows } = await q.query(
    `SELECT t.id, t.type, t.coins, t.balance_after, t.note, t.created_at, o.order_no
       FROM wallet_transactions t LEFT JOIN orders o ON o.id = t.order_id
      WHERE t.user_id=$1 AND ($3::bigint IS NULL OR t.id < $3) ORDER BY t.id DESC LIMIT $2`, [userId, limit, beforeId ?? null]);
  return rows;
}

/** Sweep expired coins for every wallet that has any. Safe to run repeatedly (cron). */
export async function expireAllDue(db: { connect: () => Promise<Tx> }): Promise<number> {
  const probe = await db.connect();
  let users: string[] = [];
  try {
    users = (await probe.query(`SELECT DISTINCT user_id FROM coin_lots WHERE remaining>0 AND expires_at IS NOT NULL AND expires_at <= now()`)).rows.map((r) => r.user_id);
  } finally { probe.release(); }
  let total = 0;
  for (const u of users) {
    const c = await db.connect();
    try {
      await c.query('BEGIN');
      await ensureWallet(c, u);
      await c.query('SELECT 1 FROM wallets WHERE user_id=$1 FOR UPDATE', [u]);
      total += await sweepExpired(c, u);
      await c.query('COMMIT');
    } catch (e) { await c.query('ROLLBACK'); throw e; } finally { c.release(); }
  }
  return total;
}
