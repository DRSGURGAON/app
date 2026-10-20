import type { Db, Queryable } from '../db/pool.js';
import type { PushSender } from '../providers/fcm.js';

export async function notifyUser(q: Queryable, userId: string, type: string, title: string, body: string, data: Record<string, string> = {}) {
  await q.query('INSERT INTO notifications (user_id, type, title, body, data) VALUES ($1,$2,$3,$4,$5)', [userId, type, title, body, JSON.stringify(data)]);
}

/** Deliver queued notifications as push messages. Safe to call repeatedly; rows are claimed with SKIP LOCKED. */
export async function flushPush(db: Db, push: PushSender, limit = 50): Promise<number> {
  const client = await db.connect();
  let sent = 0;
  try {
    await client.query('BEGIN');
    const { rows } = await client.query(
      `SELECT id, user_id, title, body, data FROM notifications WHERE push_status='not_sent' ORDER BY created_at LIMIT $1 FOR UPDATE SKIP LOCKED`, [limit]);
    for (const n of rows) {
      if (!push.configured) { await client.query(`UPDATE notifications SET push_status='skipped' WHERE id=$1`, [n.id]); continue; }
      const toks = (await client.query('SELECT id, token FROM device_tokens WHERE user_id=$1', [n.user_id])).rows;
      let ok = false;
      for (const t of toks) {
        try {
          const r = await push.send(t.token, n.title, n.body, Object.fromEntries(Object.entries(n.data ?? {}).map(([k, v]) => [k, String(v)])));
          if (r === 'sent') ok = true; else await client.query('DELETE FROM device_tokens WHERE id=$1', [t.id]);
        } catch { /* transient: leave status for retry only if no token succeeded */ }
      }
      await client.query(`UPDATE notifications SET push_status=$2 WHERE id=$1`, [n.id, ok ? 'sent' : toks.length ? 'failed' : 'skipped']);
      if (ok) sent++;
    }
    await client.query('COMMIT');
  } catch (e) { await client.query('ROLLBACK'); throw e; } finally { client.release(); }
  return sent;
}
