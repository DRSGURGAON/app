import { describe, it, expect } from 'vitest';
import { calculateDeliveryFee, haversineKm, resolveDistance, toCentiKm, OsrmProvider, type ZoneRow, type RoutingProvider } from '../src/services/delivery.js';
import { settingsSchemas } from '../src/services/settings.js';
import { AppError } from '../src/lib/errors.js';

const d = (over: Partial<ReturnType<typeof settingsSchemas.delivery.parse>> = {}) => settingsSchemas.delivery.parse({ base_fee: 25, far_fee: 70, ...over });
const zone = (over: Partial<ZoneRow> = {}): ZoneRow => ({ id: 'z1', name: 'Town', name_hi: null, pincodes: ['127308'], fee_mode: 'base', custom_fee: null, min_order: null, is_active: true, ...over });
const fee = (km: number | null, over = {}, z: ZoneRow | null = null, fulfilment: 'delivery' | 'pickup' = 'delivery', method: any = 'road_osrm') =>
  calculateDeliveryFee({ fulfilment, distanceKm: km, distanceMethod: method, zone: z, settings: d(over) });

describe('delivery fee boundaries (admin base fee = 25, far fixed = 70)', () => {
  it('1 km -> admin base fee', () => { const q = fee(1); expect(q.fee_paise).toBe(2500); expect(q.rule).toBe('near_base'); });
  it('0 km -> admin base fee', () => expect(fee(0).fee_paise).toBe(2500));
  it('exactly 2.00 km -> still base fee (inclusive)', () => { const q = fee(2.0); expect(q.fee_paise).toBe(2500); expect(q.distance_km).toBe(2); });
  it('1.999 km -> base fee', () => expect(fee(1.999).fee_paise).toBe(2500));
  it('2.004 km rounds to 2.00 -> base fee', () => expect(fee(2.004).fee_paise).toBe(2500));
  it('2.005 km rounds to 2.01 -> fixed 70', () => expect(fee(2.005).fee_paise).toBe(7000));
  it('2.01 km -> fixed Rs 70', () => { const q = fee(2.01); expect(q.fee_paise).toBe(7000); expect(q.rule).toBe('far_fixed'); });
  it('2.5 km -> Rs 70 total (not per km, not added to base)', () => expect(fee(2.5).fee_paise).toBe(7000));
  it('5 km and 12.7 km -> still a flat Rs 70', () => { expect(fee(5).fee_paise).toBe(7000); expect(fee(12.7).fee_paise).toBe(7000); });
  it('floating point noise at the boundary (2.0000001) stays base', () => expect(fee(2.0000001).fee_paise).toBe(2500));
  it('admin can change the base fee without code changes', () => expect(fee(1.2, { base_fee: 0 }).fee_paise).toBe(0));
  it('admin can change the far fee too', () => expect(fee(3, { far_fee: 90 }).fee_paise).toBe(9000));
  it('toCentiKm rounds half up', () => { expect(toCentiKm(2.005)).toBe(201); expect(toCentiKm(2.0049)).toBe(200); });
  it('rejects negative / NaN distances', () => { expect(() => toCentiKm(-1)).toThrow(); expect(() => toCentiKm(NaN)).toThrow(); });
});

describe('store pickup', () => {
  it('is always zero, regardless of distance or zone', () => {
    expect(fee(10, {}, zone({ fee_mode: 'far' }), 'pickup').fee_paise).toBe(0);
    expect(fee(null, {}, null, 'pickup').rule).toBe('pickup_free');
  });
});

describe('distance unavailable', () => {
  it('missing coordinates + no zone -> asks for a zone, never guesses', () => {
    try { fee(null); throw new Error('should throw'); } catch (e) {
      expect(e).toBeInstanceOf(AppError); expect((e as AppError).code).toBe('DELIVERY_ZONE_REQUIRED');
    }
  });
  it('confirmed zone (base) is used and recorded as method=zone', () => {
    const q = fee(null, {}, zone({ fee_mode: 'base' }), 'delivery', 'none');
    expect(q.fee_paise).toBe(2500); expect(q.distance_method).toBe('zone'); expect(q.zone?.name).toBe('Town');
  });
  it('confirmed zone (far) charges the fixed far fee', () => expect(fee(null, {}, zone({ fee_mode: 'far' })).fee_paise).toBe(7000));
  it('custom zone fee', () => expect(fee(null, {}, zone({ fee_mode: 'custom', custom_fee: '45.50' })).fee_paise).toBe(4550));
  it('inactive zone is not accepted as fallback', () => expect(() => fee(null, {}, zone({ is_active: false }))).toThrow(/select your delivery area/));
  it('fallback_mode=block refuses', () => { try { fee(null, { fallback_mode: 'block' }, zone()); throw 0; } catch (e) { expect((e as AppError).code).toBe('DELIVERY_DISTANCE_UNAVAILABLE'); } });
});

describe('serviceability + overrides', () => {
  it('beyond max radius is rejected', () => { try { fee(11, { max_radius_km: 10 }); throw 0; } catch (e) { expect((e as AppError).code).toBe('DELIVERY_NOT_SERVICEABLE'); } });
  it('max radius 0 means unlimited', () => expect(fee(80, { max_radius_km: 0 }).fee_paise).toBe(7000));
  it('zone_mode=zones requires a matched active zone', () => {
    expect(() => fee(1, { zone_mode: 'zones' })).toThrow(/do not deliver/);
    expect(fee(1, { zone_mode: 'zones' }, zone()).fee_paise).toBe(2500);
  });
  it('zone override replaces distance rule only when enabled', () => {
    expect(fee(1, {}, zone({ fee_mode: 'far' })).fee_paise).toBe(2500); // override off
    const q = fee(1, { zone_overrides_enabled: true }, zone({ fee_mode: 'far', min_order: '1500' }));
    expect(q.fee_paise).toBe(7000); expect(q.zone_min_order_paise).toBe(150000);
  });
  it('zone min order ignored while overrides are off', () => expect(fee(1, {}, zone({ min_order: '1500' })).zone_min_order_paise).toBeNull());
});

describe('resolveDistance', () => {
  const store = { lat: 28.4, lng: 75.8 };
  const addr = { lat: 28.41, lng: 75.81 };
  const okProvider: RoutingProvider = { method: 'road_osrm', roadDistanceMeters: async () => 1850 };
  const failing: RoutingProvider = { method: 'road_osrm', roadDistanceMeters: async () => { throw new Error('boom'); } };
  const hanging: RoutingProvider = { method: 'road_osrm', roadDistanceMeters: (_a, _b, signal) => new Promise((_r, rej) => signal.addEventListener('abort', () => rej(new Error('aborted')))) };

  it('missing address coordinates', async () => {
    const r = await resolveDistance({ store, address: null, settings: d(), provider: okProvider });
    expect(r).toMatchObject({ km: null, reason: 'missing_address_coordinates' });
  });
  it('store location not configured', async () => {
    const r = await resolveDistance({ store: null, address: addr, settings: d(), provider: okProvider });
    expect(r).toMatchObject({ km: null, reason: 'store_location_not_configured' });
  });
  it('uses road distance when the provider answers', async () => {
    const r = await resolveDistance({ store, address: addr, settings: d(), provider: okProvider });
    expect(r).toEqual({ km: 1.85, method: 'road_osrm' });
  });
  it('routing failure + ask_zone -> unavailable (no silent substitute)', async () => {
    const r = await resolveDistance({ store, address: addr, settings: d(), provider: failing });
    expect(r).toMatchObject({ km: null, reason: 'routing_failed' });
  });
  it('routing timeout is treated as failure', async () => {
    const r = await resolveDistance({ store, address: addr, settings: d(), provider: hanging, timeoutMs: 30 });
    expect(r).toMatchObject({ km: null, reason: 'routing_failed' });
  });
  it('routing failure + explicit straight_line fallback -> labelled straight_line', async () => {
    const r = await resolveDistance({ store, address: addr, settings: d({ fallback_mode: 'straight_line', straight_line_factor: 1.3 }), provider: failing });
    expect(r.method).toBe('straight_line');
    expect(r.km).toBeCloseTo(haversineKm(store, addr) * 1.3, 6);
  });
  it('no provider configured + ask_zone -> unavailable', async () => {
    const r = await resolveDistance({ store, address: addr, settings: d(), provider: null });
    expect(r).toMatchObject({ km: null, reason: 'no_routing_provider' });
  });
  it('OSRM provider parses a real-shaped response and rejects bad ones', async () => {
    const mk = (body: any, ok = true) => new OsrmProvider('http://osrm', (async () => ({ ok, status: ok ? 200 : 500, json: async () => body })) as any);
    const sig = new AbortController().signal;
    expect(await mk({ code: 'Ok', routes: [{ distance: 2010.4 }] }).roadDistanceMeters(store, addr, sig)).toBe(2010.4);
    await expect(mk({ code: 'NoRoute', routes: [] }).roadDistanceMeters(store, addr, sig)).rejects.toThrow();
    await expect(mk({}, false).roadDistanceMeters(store, addr, sig)).rejects.toThrow();
  });
  it('haversine sanity: ~111.19 km per degree of latitude', () => {
    expect(haversineKm({ lat: 0, lng: 0 }, { lat: 1, lng: 0 })).toBeCloseTo(111.195, 2);
  });
});
