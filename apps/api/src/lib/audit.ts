import type { Queryable } from '../db/pool.js';

export interface AuditEntry {
  actorType: 'admin' | 'customer' | 'system';
  actorId?: string | null;
  action: string;
  entity?: string;
  entityId?: string | null;
  before?: unknown;
  after?: unknown;
  ip?: string | null;
}

export async function audit(q: Queryable, e: AuditEntry): Promise<void> {
  await q.query(
    `INSERT INTO audit_logs (actor_type, actor_id, action, entity, entity_id, before, after, ip)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
    [e.actorType, e.actorId ?? null, e.action, e.entity ?? null, e.entityId ?? null,
     e.before === undefined ? null : JSON.stringify(e.before),
     e.after === undefined ? null : JSON.stringify(e.after), e.ip ?? null],
  );
}
