import pg from 'pg';
import type { PoolClient } from 'pg';

// Return NUMERIC as string (exact), BIGINT as number (safe for our id/seq ranges).
pg.types.setTypeParser(1700, (v) => v);
pg.types.setTypeParser(20, (v) => Number(v));

export type Db = pg.Pool;
export type Tx = PoolClient;
export type Queryable = Pick<pg.Pool, 'query'>;

export function createPool(url: string, max = 10): Db {
  return new pg.Pool({ connectionString: url, max, idleTimeoutMillis: 30_000 });
}

export const TX_MAX_ATTEMPTS = 3;

/**
 * Run fn inside a transaction. On a serialization failure (40001) or deadlock (40P01) the WHOLE transaction is rolled
 * back and fn re-runs from the start on a fresh connection, up to TX_MAX_ATTEMPTS, after a short random back-off.
 * fn must therefore only do database work (no gateway / HTTP calls): a rolled-back attempt leaves no rows behind.
 */
export async function withTx<T>(db: Db, fn: (tx: Tx) => Promise<T>): Promise<T> {
  for (let attempt = 1; ; attempt++) {
    const client = await db.connect();
    let retry = false;
    try {
      await client.query('BEGIN');
      const result = await fn(client);
      await client.query('COMMIT');
      return result;
    } catch (err: any) {
      try { await client.query('ROLLBACK'); } catch { /* ignore */ }
      if ((err?.code === '40001' || err?.code === '40P01') && attempt < TX_MAX_ATTEMPTS) retry = true;
      else throw err;
    } finally {
      client.release();
    }
    if (retry) await new Promise((r) => setTimeout(r, 20 * attempt + Math.floor(Math.random() * 30)));
  }
}
