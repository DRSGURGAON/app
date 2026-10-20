import Fastify, { type FastifyInstance, type FastifyReply, type FastifyRequest } from 'fastify';
import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import rateLimit from '@fastify/rate-limit';
import multipart from '@fastify/multipart';
import fastifyStatic from '@fastify/static';
import { mkdir } from 'node:fs/promises';
import { resolve } from 'node:path';
import { existsSync } from 'node:fs';
import { AppError, unauthorized, forbidden } from './lib/errors.js';
import type { AppCtx } from './services/orders.js';
import { verifyToken, hasPermission, type Permission } from './services/auth.js';
import { catalogRoutes } from './routes/catalog.js';
import { authRoutes } from './routes/auth.js';
import { customerRoutes } from './routes/customer.js';
import { orderRoutes } from './routes/orders.js';
import { adminCoreRoutes } from './routes/admin/core.js';
import { adminCatalogRoutes } from './routes/admin/catalog.js';
import { adminOrderRoutes } from './routes/admin/orders.js';
import { adminOfferRoutes } from './routes/admin/offers.js';
import { adminImportRoutes } from './routes/admin/imports.js';
import { publicPageRoutes } from './routes/publicPages.js';

declare module 'fastify' {
  interface FastifyRequest {
    rawBody?: Buffer;
    userId?: string;
    admin?: { id: string; email: string; name: string; role: 'owner' | 'manager' | 'staff'; extra_permissions: string[] };
  }
}

export async function buildApp(ctx: AppCtx): Promise<FastifyInstance> {
  const isProd = ctx.config.NODE_ENV === 'production';
  const app = Fastify({
    logger: ctx.config.NODE_ENV === 'test' ? false : { level: isProd ? 'info' : 'debug', redact: ['req.headers.authorization', 'req.headers.cookie'] },
    trustProxy: true,
    bodyLimit: 2 * 1024 * 1024,
  });

  await app.register(helmet, { crossOriginResourcePolicy: { policy: 'cross-origin' }, contentSecurityPolicy: false });
  const origins = ctx.config.CORS_ORIGINS.split(',').map((s) => s.trim()).filter(Boolean);
  await app.register(cors, { origin: origins.length ? origins : !isProd, methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'], allowedHeaders: ['authorization', 'content-type', 'idempotency-key'], maxAge: 600 });
  await app.register(rateLimit, { global: true, max: ctx.config.NODE_ENV === 'test' ? 100000 : 300, timeWindow: '1 minute' });
  await app.register(multipart, { limits: { fileSize: 6 * 1024 * 1024, files: 8 } });

  // Keep the raw bytes: payment webhooks are signed over the exact body.
  app.addContentTypeParser('application/json', { parseAs: 'buffer' }, (req, body, done) => {
    req.rawBody = body as Buffer;
    if (!(body as Buffer).length) return done(null, {});
    try { done(null, JSON.parse((body as Buffer).toString('utf8'))); } catch { done(new AppError(400, 'INVALID_JSON', 'Request body is not valid JSON'), undefined); }
  });

  app.setErrorHandler((err: any, req, reply) => {
    if (err instanceof AppError) return reply.status(err.status).send({ error: { code: err.code, message: err.message, details: err.details } });
    if (err?.statusCode === 429) return reply.status(429).send({ error: { code: 'RATE_LIMITED', message: 'Too many requests. Please slow down and try again shortly.' } });
    if (err?.code === 'FST_REQ_FILE_TOO_LARGE') return reply.status(413).send({ error: { code: 'FILE_TOO_LARGE', message: 'Image is too large (max 6 MB)' } });
    if (err?.validation || (err?.statusCode && err.statusCode < 500)) return reply.status(err.statusCode ?? 400).send({ error: { code: 'BAD_REQUEST', message: err.message } });
    if (err?.code === '23505') return reply.status(409).send({ error: { code: 'DUPLICATE', message: 'This record already exists', details: isProd ? undefined : err.detail } });
    if (err?.code === '23503') return reply.status(409).send({ error: { code: 'IN_USE', message: 'This record is linked to other data and cannot be changed this way' } });
    if (err?.code === '23514') return reply.status(400).send({ error: { code: 'CONSTRAINT', message: isProd ? 'Value not allowed' : `Value not allowed (${err.constraint})` } });
    req.log.error({ err }, 'unhandled error');
    return reply.status(500).send({ error: { code: 'INTERNAL', message: 'Something went wrong on our side. Please try again.' } });
  });
  app.setNotFoundHandler((_req, reply) => reply.status(404).send({ error: { code: 'NOT_FOUND', message: 'Not found' } }));

  // ---- auth helpers (preHandlers)
  const requireUser = async (req: FastifyRequest) => {
    const h = req.headers.authorization;
    if (!h?.startsWith('Bearer ')) throw unauthorized();
    const id = await verifyToken(ctx.config, h.slice(7), 'user');
    const u = await ctx.db.query('SELECT status FROM users WHERE id=$1', [id]);
    if (!u.rowCount || u.rows[0].status !== 'active') throw unauthorized('Session expired. Please log in again.');
    req.userId = id;
  };
  const optionalUser = async (req: FastifyRequest) => { if (req.headers.authorization) await requireUser(req); };
  const requireAdmin = (perm?: Permission) => async (req: FastifyRequest) => {
    const h = req.headers.authorization;
    if (!h?.startsWith('Bearer ')) throw unauthorized();
    const id = await verifyToken(ctx.config, h.slice(7), 'admin');
    const a = await ctx.db.query('SELECT id, email, name, role, extra_permissions, status FROM admin_users WHERE id=$1', [id]);
    if (!a.rowCount || a.rows[0].status !== 'active') throw unauthorized('Session expired. Please log in again.');
    req.admin = a.rows[0];
    if (perm && !hasPermission(req.admin!, perm)) throw forbidden(`Your role does not allow this (${perm})`);
  };
  const deps = { ctx, requireUser, optionalUser, requireAdmin };
  app.decorate('deps', deps);

  app.get('/health', async () => {
    await ctx.db.query('SELECT 1');
    return { ok: true, time: new Date().toISOString() };
  });

  await app.register(async (r) => publicPageRoutes(r, deps));
  await app.register(async (r) => catalogRoutes(r, deps), { prefix: '/v1' });
  await app.register(async (r) => authRoutes(r, deps), { prefix: '/v1' });
  await app.register(async (r) => customerRoutes(r, deps), { prefix: '/v1' });
  await app.register(async (r) => orderRoutes(r, deps), { prefix: '/v1' });
  await app.register(async (r) => { await adminCoreRoutes(r, deps); await adminCatalogRoutes(r, deps); await adminOrderRoutes(r, deps); await adminOfferRoutes(r, deps); await adminImportRoutes(r, deps); }, { prefix: '/v1/admin' });

  // Uploaded product/category images
  const uploadDir = resolve(ctx.config.UPLOAD_DIR);
  await mkdir(uploadDir, { recursive: true });
  await app.register(fastifyStatic, { root: uploadDir, prefix: '/uploads/', decorateReply: false, maxAge: '7d', immutable: true });

  // Optionally serve the built admin panel from the same server (single deployment for a small store).
  if (ctx.config.ADMIN_DIST_DIR && existsSync(ctx.config.ADMIN_DIST_DIR)) {
    await app.register(fastifyStatic, { root: resolve(ctx.config.ADMIN_DIST_DIR), prefix: '/admin/', decorateReply: false });
    app.get('/admin', (_req, reply: FastifyReply) => reply.redirect('/admin/'));
    // The admin SPA uses hash routing, so no catch-all fallback is needed (fastify-static already serves /admin/*).
  }
  return app;
}

export interface RouteDeps {
  ctx: AppCtx;
  requireUser: (req: FastifyRequest) => Promise<void>;
  optionalUser: (req: FastifyRequest) => Promise<void>;
  requireAdmin: (perm?: Permission) => (req: FastifyRequest) => Promise<void>;
}
