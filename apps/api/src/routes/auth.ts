import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { RouteDeps } from '../app.js';
import { parse } from '../lib/validate.js';
import { logout, refreshSession, requestOtp, verifyOtp } from '../services/auth.js';

export async function authRoutes(app: FastifyInstance, { ctx }: RouteDeps) {
  const tight = (max: number) => ({ config: { rateLimit: { max: ctx.config.NODE_ENV === 'test' ? 100000 : max, timeWindow: '1 minute' } } });

  app.post('/auth/otp/request', tight(6), async (req) => {
    const { phone } = parse(z.object({ phone: z.string().min(10).max(16) }), req.body);
    return requestOtp(ctx.db, ctx.config, ctx.otp, phone, req.ip);
  });
  app.post('/auth/otp/verify', tight(12), async (req) => {
    const b = parse(z.object({ phone: z.string().min(10).max(16), code: z.string().regex(/^\d{6}$/, 'Enter the 6-digit code'), device: z.string().max(80).optional() }), req.body);
    return verifyOtp(ctx.db, ctx.config, b.phone, b.code, b.device ?? null);
  });
  app.post('/auth/refresh', tight(30), async (req) => {
    const b = parse(z.object({ refresh_token: z.string().min(20).max(200), device: z.string().max(80).optional() }), req.body);
    return refreshSession(ctx.db, ctx.config, b.refresh_token, b.device ?? null);
  });
  app.post('/auth/logout', tight(30), async (req) => {
    const b = parse(z.object({ refresh_token: z.string().max(200).optional() }), req.body ?? {});
    await logout(ctx.db, b.refresh_token);
    return { ok: true };
  });
}
