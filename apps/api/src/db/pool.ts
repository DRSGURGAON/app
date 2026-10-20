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

/** Run fn inside a transaction. Retries on serialization failures / deadlocks (up to 3 attempts). */
export async function withTx<T>(db: Db, fn: (tx: Tx) => Promise<T>): Promise<T> {
  for (let attempt = 1; ; attempt++) {
    const client = await db.connect();
    try {
      await client.query('BEGIN');
      const result = await fn(client);
      await client.query('COMMIT');
      return result;
    } catch (err: any) {
      try { await client.query('ROLLBACK'); } catch { /* ignore */ }
      if ((err?.code === '40001' || err?.code === '40P01') && attempt < 3) continue;
      throw err;
    } finally {
      client.release();
    }
  }
}
