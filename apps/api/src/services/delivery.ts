import { AppError } from '../lib/errors.js';
import { fromPaise, toPaise, type Paise } from '../lib/money.js';
import type { AppSettings } from './settings.js';

export interface LatLng { lat: number; lng: number }
export interface ZoneRow {
  id: string; name: string; name_hi: string | null; pincodes: string[];
  fee_mode: 'base' | 'far' | 'custom'; custom_fee: string | null; min_order: string | null; is_active: boolean;
}

export type DistanceMethod = 'road_osrm' | 'road_google' | 'straight_line' | 'zone' | 'none';
export type FeeRule = 'pickup_free' | 'near_base' | 'far_fixed' | 'zone_base' | 'zone_far' | 'zone_custom';

export interface DeliveryQuote {
  fee_paise: Paise;
  rule: FeeRule;
  distance_km: number | null;      // rounded to 2 decimals (10 m) - the figure the fee decision used
  distance_method: DistanceMethod;
  zone: { id: string; name: string } | null;
  zone_min_order_paise: Paise | null;
}

// ------------------------------------------------------------------ geometry
export function haversineKm(a: LatLng, b: LatLng): number {
  const R = 6371.0088;
  const rad = (d: number) => (d * Math.PI) / 180;
  const dLat = rad(b.lat - a.lat), dLng = rad(b.lng - a.lng);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.min(1, Math.sqrt(h)));
}

/**
 * Distance rounding policy (documented in docs/BUSINESS_RULES.md):
 * distances are rounded half-up to 2 decimals of a kilometre (10 m) BEFORE the 2 km comparison,
 * so 2.004 km is treated as 2.00 km (near) and 2.005 km as 2.01 km (far).
 */
export function toCentiKm(km: number): number {
  if (!Number.isFinite(km) || km < 0) throw new Error(`Invalid distance: ${km}`);
  return Math.round(km * 100 + 1e-9);
}

// ------------------------------------------------------------------ fee decision (pure)
export interface FeeInput {
  fulfilment: 'delivery' | 'pickup';
  distanceKm: number | null;
  distanceMethod: DistanceMethod;
  zone: ZoneRow | null;
  settings: AppSettings['delivery'];
}

function zoneFee(zone: ZoneRow, d: AppSettings['delivery']): { fee: Paise; rule: FeeRule } {
  if (zone.fee_mode === 'base') return { fee: toPaise(d.base_fee), rule: 'zone_base' };
  if (zone.fee_mode === 'far') return { fee: toPaise(d.far_fee), rule: 'zone_far' };
  return { fee: toPaise(zone.custom_fee ?? '0'), rule: 'zone_custom' };
}

export function calculateDeliveryFee(input: FeeInput): DeliveryQuote {
  const { fulfilment, distanceKm, zone, settings: d } = input;
  const zoneMin = zone?.min_order != null && d.zone_overrides_enabled ? toPaise(zone.min_order) : null;
  const zoneRef = zone ? { id: zone.id, name: zone.name } : null;

  if (fulfilment === 'pickup') {
    return { fee_paise: 0, rule: 'pickup_free', distance_km: null, distance_method: 'none', zone: null, zone_min_order_paise: null };
  }

  // serviceability by zone list
  if (d.zone_mode === 'zones' && (!zone || !zone.is_active)) {
    throw new AppError(422, 'DELIVERY_NOT_SERVICEABLE', 'We do not deliver to this area yet. Please choose Store Pickup or a different address.');
  }

  let centi: number | null = null;
  if (distanceKm !== null) {
    centi = toCentiKm(distanceKm);
    if (d.max_radius_km > 0 && centi > toCentiKm(d.max_radius_km)) {
      throw new AppError(422, 'DELIVERY_NOT_SERVICEABLE', `Delivery is available up to ${d.max_radius_km} km from the store.`, { distance_km: centi / 100 });
    }
  }

  // Zone override (admin explicitly enabled): the zone decides the fee.
  if (d.zone_overrides_enabled && zone) {
    const z = zoneFee(zone, d);
    return { fee_paise: z.fee, rule: z.rule, distance_km: centi === null ? null : centi / 100, distance_method: centi === null ? 'zone' : input.distanceMethod, zone: zoneRef, zone_min_order_paise: zoneMin };
  }

  if (centi !== null) {
    const near = centi <= toCentiKm(d.near_radius_km);
    return {
      fee_paise: toPaise(near ? d.base_fee : d.far_fee),
      rule: near ? 'near_base' : 'far_fixed',
      distance_km: centi / 100,
      distance_method: input.distanceMethod,
      zone: zoneRef,
      zone_min_order_paise: zoneMin,
    };
  }

  // Distance unavailable -> never guess.
  if (d.fallback_mode === 'ask_zone' && zone && zone.is_active) {
    const z = zoneFee(zone, d);
    return { fee_paise: z.fee, rule: z.rule, distance_km: null, distance_method: 'zone', zone: zoneRef, zone_min_order_paise: zoneMin };
  }
  if (d.fallback_mode === 'block') {
    throw new AppError(422, 'DELIVERY_DISTANCE_UNAVAILABLE', 'We could not work out the delivery distance. Please choose Store Pickup or call the store.');
  }
  throw new AppError(422, 'DELIVERY_ZONE_REQUIRED', 'We could not calculate the distance to your address. Please select your delivery area to see the exact delivery charge.');
}

// ------------------------------------------------------------------ routing providers
export interface RoutingProvider {
  readonly method: 'road_osrm' | 'road_google';
  roadDistanceMeters(from: LatLng, to: LatLng, signal: AbortSignal): Promise<number>;
}

export class OsrmProvider implements RoutingProvider {
  readonly method = 'road_osrm' as const;
  constructor(private baseUrl: string, private fetchImpl: typeof fetch = fetch) {}
  async roadDistanceMeters(from: LatLng, to: LatLng, signal: AbortSignal): Promise<number> {
    const url = `${this.baseUrl.replace(/\/$/, '')}/route/v1/driving/${from.lng},${from.lat};${to.lng},${to.lat}?overview=false`;
    const res = await this.fetchImpl(url, { signal });
    if (!res.ok) throw new Error(`OSRM HTTP ${res.status}`);
    const body: any = await res.json();
    const m = body?.routes?.[0]?.distance;
    if (body?.code !== 'Ok' || typeof m !== 'number') throw new Error('OSRM returned no route');
    return m;
  }
}

export class GoogleRoutesProvider implements RoutingProvider {
  readonly method = 'road_google' as const;
  constructor(private apiKey: string, private fetchImpl: typeof fetch = fetch) {}
  async roadDistanceMeters(from: LatLng, to: LatLng, signal: AbortSignal): Promise<number> {
    const res = await this.fetchImpl('https://routes.googleapis.com/directions/v2:computeRoutes', {
      method: 'POST',
      signal,
      headers: { 'content-type': 'application/json', 'X-Goog-Api-Key': this.apiKey, 'X-Goog-FieldMask': 'routes.distanceMeters' },
      body: JSON.stringify({
        origin: { location: { latLng: { latitude: from.lat, longitude: from.lng } } },
        destination: { location: { latLng: { latitude: to.lat, longitude: to.lng } } },
        travelMode: 'DRIVE',
      }),
    });
    if (!res.ok) throw new Error(`Google Routes HTTP ${res.status}`);
    const body: any = await res.json();
    const m = body?.routes?.[0]?.distanceMeters;
    if (typeof m !== 'number') throw new Error('Google Routes returned no route');
    return m;
  }
}

export type DistanceResult =
  | { km: number; method: DistanceMethod; reason?: undefined }
  | { km: null; method: 'none'; reason: 'missing_address_coordinates' | 'store_location_not_configured' | 'routing_failed' | 'no_routing_provider' };

/**
 * Work out the distance between the store and the delivery address.
 *  - Road distance when a routing provider is configured and answers.
 *  - Straight-line (x factor) ONLY when the admin explicitly set fallback_mode = 'straight_line'; recorded on the order as such.
 *  - Otherwise unavailable -> caller must ask for a zone (never a silent guess).
 */
export async function resolveDistance(opts: {
  store: LatLng | null;
  address: LatLng | null;
  settings: AppSettings['delivery'];
  provider: RoutingProvider | null;
  timeoutMs?: number;
}): Promise<DistanceResult> {
  const { store, address, settings, provider } = opts;
  if (!address) return { km: null, method: 'none', reason: 'missing_address_coordinates' };
  if (!store) return { km: null, method: 'none', reason: 'store_location_not_configured' };

  let failed = false;
  if (provider) {
    const ctrl = new AbortController();
    const t = setTimeout(() => ctrl.abort(), opts.timeoutMs ?? 4000);
    try {
      const meters = await provider.roadDistanceMeters(store, address, ctrl.signal);
      return { km: meters / 1000, method: provider.method };
    } catch {
      failed = true;
    } finally {
      clearTimeout(t);
    }
  }
  if (settings.fallback_mode === 'straight_line') {
    return { km: haversineKm(store, address) * settings.straight_line_factor, method: 'straight_line' };
  }
  return { km: null, method: 'none', reason: failed ? 'routing_failed' : 'no_routing_provider' };
}

export const rupees = fromPaise;
