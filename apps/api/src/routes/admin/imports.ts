import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { RouteDeps } from '../../app.js';
import { parse, uuid } from '../../lib/validate.js';
import { AppError, notFound } from '../../lib/errors.js';
import { buildPreview, confirmImport, buildTemplate } from '../../services/importer.js';

export async function adminImportRoutes(app: FastifyInstance, { ctx, requireAdmin }: RouteDeps) {
  const db = ctx.db; const guard = { preHandler: requireAdmin('imports:write') };
  app.get('/imports/template', guard, async (req, reply) => {
    const { format } = parse(z.object({ format: z.enum(['csv', 'xlsx']).default('xlsx') }), req.query);
    const t = await buildTemplate(db, format);
    return reply.header('Content-Type', t.contentType).header('Content-Disposition', `attachment; filename="${t.filename}"`).send(t.body);
  });
  /** Step 1: upload + validate. Nothing is written to the catalogue yet. */
  app.post('/imports/preview', guard, async (req) => {
    const f = await (req as any).file(); if (!f) throw new AppError(400, 'NO_FILE', 'Choose a .csv or .xlsx file');
    const field = (n: string) => { const v = f.fields?.[n]?.value; return v === undefined ? undefined : String(v); };
    const options = { apply_updates: field('apply_updates') === 'true', update_stock: field('update_stock') === 'true' };
    const buf: Buffer = await f.toBuffer(); if (f.file.truncated) throw new AppError(413, 'FILE_TOO_LARGE', 'File is too large (max 6 MB)');
    return buildPreview(db, req.admin!.id, f.filename, buf, options);
  });
  app.get('/imports/:id', guard, async (req) => {
    const { id } = parse(z.object({ id: uuid }), req.params);
    const j = (await db.query('SELECT id, filename, status, options, total_rows, valid_rows, invalid_rows, create_count, update_count, unchanged_count, created_at, applied_at FROM import_jobs WHERE id=$1', [id])).rows[0]; if (!j) throw notFound('Import not found');
    const errors = (await db.query('SELECT row_no, field, message FROM import_errors WHERE job_id=$1 ORDER BY row_no, id LIMIT 500', [id])).rows;
    return { job: j, errors };
  });
  /** Step 2: apply the previewed plan (once). */
  app.post('/imports/:id/confirm', guard, async (req) => {
    const { id } = parse(z.object({ id: uuid }), req.params);
    const b = parse(z.object({ apply_updates: z.boolean().optional() }).default({}), req.body ?? {});
    return { result: await confirmImport(db, id, req.admin!.id, req.ip, b) };
  });
  app.post('/imports/:id/cancel', guard, async (req) => {
    const { id } = parse(z.object({ id: uuid }), req.params);
    const r = await db.query(`UPDATE import_jobs SET status='cancelled' WHERE id=$1 AND status='previewed' RETURNING id`, [id]); if (!r.rowCount) throw notFound('No pending import with that id');
    return { ok: true };
  });
  app.get('/imports', guard, async () => ({ jobs: (await db.query('SELECT id, filename, status, total_rows, valid_rows, invalid_rows, create_count, update_count, unchanged_count, created_at, applied_at FROM import_jobs ORDER BY created_at DESC LIMIT 30')).rows }));
}
