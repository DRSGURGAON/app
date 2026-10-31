import { describe, it, expect, beforeAll, afterAll, beforeEach } from 'vitest';
import type { FastifyInstance } from 'fastify';
import { buildApp } from '../src/app.js';
import { makeCtx, reset, openStore, setting } from './helpers.js';
import { CachedRouting, GooglePlaces, type PlacesProvider } from '../src/services/maps.js';
import { GoogleRoutesProvider, type RoutingProvider } from '../src/services/delivery.js';

const STORE = { latitude: 28.4325, longitude: 75.8165 };
let app: FastifyInstance; let ctx: ReturnType<typeof makeCtx>;
let meters = 1800; let calls = 0; let routeFails = false; let placesFail = false;
const inner: RoutingProvider = { method: 'road_google', roadDistanceMeters: async () => { calls++; if (routeFails) throw new Error('boom'); return meters; } };
const places: PlacesProvider = {
  autocomplete: async (q) => { if (placesFail) throw new Error('down'); return [{ place_id: 'abc12345', text: `${q}, Loharu`, main: q, secondary: 'Loharu, Haryana' }]; },
  details: async () => ({ place_id: 'abc12345', latitude: 28.44, longitude: 75.82, formatted_address: 'Main Bazaar, Loharu', pincode: '127308', locality: 'Loharu' }),
  reverse: async () => ({ formatted_address: 'Near Singhla Hospital, Loharu', pincode: '127308', locality: 'Loharu' }),
};

beforeAll(async () => { ctx = makeCtx(); ctx.routing = new CachedRouting(inner, ctx.db); ctx.places = places; app = await buildApp(ctx); await app.ready(); });
afterAll(async () => { await app.close(); await ctx.db.end(); });
beforeEach(async () => { await reset(ctx.db); await openStore(ctx.db); await setting(ctx.db, 'store', STORE); await setting(ctx.db, 'delivery', { base_fee: 30, far_fee: 70, near_radius_km: 2, max_radius_km: 15, fallback_mode: 'ask_zone' }); meters = 1800; calls = 0; routeFails = false; placesFail = false; ctx.places = places; });

const json = (r: { body: string }) => JSON.parse(r.body);
async function login(phone = '9876543210') {
  const a = await app.inject({ method: 'POST', url: '/v1/auth/otp/request', payload: { phone } });
  const b = await app.inject({ method: 'POST', url: '/v1/auth/otp/verify', payload: { phone, code: json(a).dev_code } });
  return { authorization: `Bearer ${json(b).access_token}` };
}
const est = async (h: any, lat = 28.45, lng = 75.83, extra: any = {}) => json(await app.inject({ method: 'POST', url: '/v1/delivery/estimate', headers: h, payload: { latitude: lat, longitude: lng, ...extra } })).estimate;

describe('delivery estimate for a map pin', () => {
  it('needs login', async () => { expect((await app.inject({ method: 'POST', url: '/v1/delivery/estimate', payload: { latitude: 28.45, longitude: 75.83 } })).statusCode).toBe(401); });
  it('1.8 km road distance -> base fee; 2.00 km -> base; 2.01 km -> flat 70 (not per km, not added)', async () => {
    const h = await login();
    meters = 1800; let e = await est(h); expect(e).toMatchObject({ serviceable: true, fee: '30.00', rule: 'near_base', distance_km: 1.8, method: 'road_google' });
    meters = 2000; e = await est(h, 28.451, 75.831); expect(e).toMatchObject({ fee: '30.00', rule: 'near_base', distance_km: 2 });
    meters = 2010; e = await est(h, 28.452, 75.832); expect(e).toMatchObject({ fee: '70.00', rule: 'far_fixed', distance_km: 2.01 });
    meters = 9400; e = await est(h, 28.46, 75.84); expect(e).toMatchObject({ fee: '70.00', rule: 'far_fixed' });
  });
  it('beyond 15 km is refused and does NOT spend a routing call', async () => {
    const h = await login();
    const e = await est(h, 28.9, 76.5); // ~90 km away
    expect(e.serviceable).toBe(false); expect(e.error.code).toBe('DELIVERY_NOT_SERVICEABLE'); expect(calls).toBe(0);
  });
  it('road distance over 15 km (straight line under) is also refused', async () => {
    const h = await login(); meters = 15500; const e = await est(h, 28.5, 75.9);
    expect(e.serviceable).toBe(false); expect(e.error.code).toBe('DELIVERY_NOT_SERVICEABLE'); expect(e.distance_km).toBe(15.5);
  });
  it('the same pin is billed once (cached)', async () => {
    const h = await login(); await est(h, 28.45, 75.83); await est(h, 28.45, 75.83); await est(h, 28.450001, 75.830001);
    expect(calls).toBe(1);
    expect((await ctx.db.query('SELECT count(*)::int n FROM distance_cache')).rows[0].n).toBe(1);
  });
  it('routing failure never guesses: asks for a zone', async () => {
    const h = await login(); await ctx.db.query(`INSERT INTO delivery_zones (name, pincodes, fee_mode) VALUES ('Town', '{}', 'base')`);
    routeFails = true; const e = await est(h, 28.47, 75.85);
    expect(e.serviceable).toBe(false); expect(e.error.code).toBe('DELIVERY_ZONE_REQUIRED'); expect(e.fee).toBeNull(); expect(e.zones_to_choose).toHaveLength(1);
  });
  it('store location not set -> no distance, asks for a zone', async () => {
    const h = await login(); await setting(ctx.db, 'store', { latitude: null, longitude: null }); const e = await est(h);
    expect(e.error.code).toBe('DELIVERY_ZONE_REQUIRED'); expect(calls).toBe(0);
  });
  it('rejects nonsense coordinates', async () => { const h = await login(); expect((await app.inject({ method: 'POST', url: '/v1/delivery/estimate', headers: h, payload: { latitude: 200, longitude: 75 } })).statusCode).toBe(400); });
});

describe('address search endpoints', () => {
  const S = 'sess_1234567890';
  it('require login and valid input', async () => {
    expect((await app.inject({ method: 'GET', url: `/v1/maps/autocomplete?q=loharu&session=${S}` })).statusCode).toBe(401);
    const h = await login();
    expect((await app.inject({ method: 'GET', url: `/v1/maps/autocomplete?q=lo&session=${S}`, headers: h })).statusCode).toBe(400);
    expect((await app.inject({ method: 'GET', url: '/v1/maps/autocomplete?q=loharu&session=bad token!', headers: h })).statusCode).toBe(400);
  });
  it('returns suggestions, place details with PIN, and reverse geocode', async () => {
    const h = await login();
    const a = json(await app.inject({ method: 'GET', url: `/v1/maps/autocomplete?q=main%20bazaar&session=${S}`, headers: h })); expect(a.suggestions[0].place_id).toBe('abc12345');
    const p = json(await app.inject({ method: 'GET', url: `/v1/maps/place?place_id=abc12345&session=${S}`, headers: h })); expect(p.place).toMatchObject({ pincode: '127308', latitude: 28.44 });
    const r = json(await app.inject({ method: 'GET', url: '/v1/maps/reverse?lat=28.43&lng=75.81', headers: h })); expect(r.result.pincode).toBe('127308');
  });
  it('degrades gracefully: provider down or not configured -> 503 MAPS_UNAVAILABLE (pin + zones still work)', async () => {
    const h = await login(); placesFail = true;
    let r = await app.inject({ method: 'GET', url: `/v1/maps/autocomplete?q=loharu&session=${S}`, headers: h }); expect(r.statusCode).toBe(503); expect(json(r).error.code).toBe('MAPS_UNAVAILABLE'); expect(r.body).not.toContain('down');
    ctx.places = null; r = await app.inject({ method: 'GET', url: '/v1/maps/reverse?lat=28.43&lng=75.81', headers: h }); expect(r.statusCode).toBe(503);
    expect(json(await app.inject({ method: 'GET', url: '/v1/config' })).maps.search_enabled).toBe(false);
  });
});

describe('Google provider request/response mapping (mocked HTTP; the real Google API was not called)', () => {
  const resp = (body: unknown, ok = true) => ({ ok, status: ok ? 200 : 403, json: async () => body }) as any;
  it('Routes API: sends the field mask + key in headers, returns metres', async () => {
    let seen: any; const f = (async (url: string, init: any) => { seen = { url, init }; return resp({ routes: [{ distanceMeters: 2345 }] }); }) as any;
    const m = await new GoogleRoutesProvider('KEY', f).roadDistanceMeters({ lat: 1, lng: 2 }, { lat: 3, lng: 4 }, new AbortController().signal);
    expect(m).toBe(2345); expect(seen.url).toBe('https://routes.googleapis.com/directions/v2:computeRoutes');
    expect(seen.init.headers['X-Goog-FieldMask']).toBe('routes.distanceMeters'); expect(seen.init.headers['X-Goog-Api-Key']).toBe('KEY'); expect(seen.url).not.toContain('KEY');
    expect(JSON.parse(seen.init.body).travelMode).toBe('DRIVE');
  });
  it('Places: maps autocomplete, details (PIN) and reverse geocoding; ZERO_RESULTS -> null; errors throw', async () => {
    const sig = new AbortController().signal; let last: any;
    const mk = (body: any, ok = true) => new GooglePlaces('KEY', (async (u: string, i: any) => { last = { u, i }; return resp(body, ok); }) as any);
    const a = await mk({ suggestions: [{ placePrediction: { placeId: 'P1', text: { text: 'Loharu, Haryana' }, structuredFormat: { mainText: { text: 'Loharu' }, secondaryText: { text: 'Haryana' } } } }, {}] }).autocomplete('loh', 'sess_12345678', { lat: 28.4, lng: 75.8 }, sig);
    expect(a).toEqual([{ place_id: 'P1', text: 'Loharu, Haryana', main: 'Loharu', secondary: 'Haryana' }]);
    const body = JSON.parse(last.i.body); expect(body.includedRegionCodes).toEqual(['in']); expect(body.locationBias.circle.radius).toBe(50000); expect(last.i.headers['X-Goog-Api-Key']).toBe('KEY');
    const d = await mk({ id: 'P1', location: { latitude: 28.4, longitude: 75.8 }, formattedAddress: 'Loharu', addressComponents: [{ types: ['postal_code'], longText: '127308' }, { types: ['locality'], longText: 'Loharu' }] }).details('P1', 'sess_12345678', sig);
    expect(d).toMatchObject({ latitude: 28.4, pincode: '127308', locality: 'Loharu' });
    expect(await mk({ status: 'ZERO_RESULTS', results: [] }).reverse({ lat: 0, lng: 0 }, sig)).toBeNull();
    const r = await mk({ status: 'OK', results: [{ formatted_address: 'X', address_components: [{ types: ['postal_code'], long_name: '127308' }] }] }).reverse({ lat: 1, lng: 1 }, sig); expect(r?.pincode).toBe('127308');
    await expect(mk({}, false).autocomplete('loh', 'sess_12345678', null, sig)).rejects.toThrow();
    await expect(mk({ status: 'REQUEST_DENIED' }).reverse({ lat: 1, lng: 1 }, sig)).rejects.toThrow();
  });
});
