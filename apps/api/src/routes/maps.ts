import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { RouteDeps } from '../app.js';
import { parse } from '../lib/validate.js';
import { AppError } from '../lib/errors.js';
import { loadSettings } from '../services/settings.js';
import { estimateDelivery } from '../services/estimate.js';

/** Map helpers for the app. All Google calls happen here, behind login + rate limits, so the server key is never exposed and cost is bounded. */
export async function mapsRoutes(app: FastifyInstance, { ctx, requireUser }: RouteDeps) {
  const limit = (max: number) => ({ preHandler: requireUser, config: { rateLimit: { max: ctx.config.NODE_ENV === 'test' ? 100000 : max, timeWindow: '1 minute' } } });
  const guard = async <T>(label: string, ms: number, fn: (s: AbortSignal) => Promise<T>): Promise<T> => {
    const c = new AbortController(); const t = setTimeout(() => c.abort(), ms);
    try { return await fn(c.signal); } catch (e) {
      if (e instanceof AppError) throw e;
      app.log.warn({ err: e }, `maps ${label} failed`);
      throw new AppError(503, 'MAPS_UNAVAILABLE', 'Map search is not available right now. You can still pick your location on the map or choose your delivery area.');
    } finally { clearTimeout(t); }
  };
  const need = () => { if (!ctx.places) throw new AppError(503, 'MAPS_UNAVAILABLE', 'Address search is not available. Please drop a pin on the map or choose your delivery area.'); return ctx.places; };

  app.get('/maps/autocomplete', limit(40), async (req) => {
    const q = parse(z.object({ q: z.string().trim().min(3).max(100), session: z.string().min(8).max(64).regex(/^[A-Za-z0-9_-]+$/) }), req.query);
    const places = need(); const s = await loadSettings(ctx.db);
    const bias = s.store.latitude !== null && s.store.longitude !== null ? { lat: s.store.latitude, lng: s.store.longitude } : null;
    return { suggestions: await guard('autocomplete', 4000, (sig) => places.autocomplete(q.q, q.session, bias, sig)) };
  });

  app.get('/maps/place', limit(40), async (req) => {
    const q = parse(z.object({ place_id: z.string().min(5).max(300), session: z.string().min(8).max(64).regex(/^[A-Za-z0-9_-]+$/) }), req.query);
    const places = need();
    return { place: await guard('details', 4000, (sig) => places.details(q.place_id, q.session, sig)) };
  });

  app.get('/maps/reverse', limit(40), async (req) => {
    const q = parse(z.object({ lat: z.coerce.number().min(-90).max(90), lng: z.coerce.number().min(-180).max(180) }), req.query);
    const places = need();
    return { result: await guard('reverse', 4000, (sig) => places.reverse({ lat: q.lat, lng: q.lng }, sig)) };
  });

  /** Fee + distance for a pin, before the address is saved. */
  app.post('/delivery/estimate', limit(60), async (req) => {
    const b = parse(z.object({ latitude: z.number().min(-90).max(90), longitude: z.number().min(-180).max(180), zone_id: z.string().uuid().nullish(), pincode: z.string().regex(/^\d{6}$/).nullish() }), req.body);
    const S = await loadSettings(ctx.db);
    return { estimate: await estimateDelivery(ctx.db, S, ctx.routing, b) };
  });
}
