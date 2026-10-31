import type { Queryable } from '../db/pool.js';
import { AppError } from '../lib/errors.js';
import { fromPaise } from '../lib/money.js';
import { calculateDeliveryFee, resolveDistance, type RoutingProvider } from './delivery.js';
import { resolveZone } from './pricing.js';
import type { AppSettings } from './settings.js';

export interface DeliveryEstimate {
  serviceable: boolean;
  fee: string | null;               // rupees, null when unknown
  rule: string | null;
  distance_km: number | null;
  method: string | null;
  zone: { id: string; name: string } | null;
  max_radius_km: number;
  error: { code: string; message: string } | null;
  zones_to_choose: Array<{ id: string; name: string; name_hi: string | null }> | null;
}

/**
 * "What would delivery to this pin cost?" - same engine as checkout (road distance, rounding, 2 km rule, max radius, zones),
 * used by the map screen to show the fee BEFORE the address is saved. Never guesses: no distance -> asks for a zone.
 */
export async function estimateDelivery(q: Queryable, S: AppSettings, routing: RoutingProvider | null, a: { latitude: number; longitude: number; zone_id?: string | null; pincode?: string | null }): Promise<DeliveryEstimate> {
  const zone = await resolveZone(q, { id: null, latitude: a.latitude, longitude: a.longitude, zone_id: a.zone_id ?? null, pincode: a.pincode ?? null });
  const store = S.store.latitude !== null && S.store.longitude !== null ? { lat: S.store.latitude, lng: S.store.longitude } : null;
  const dist = await resolveDistance({ store, address: { lat: a.latitude, lng: a.longitude }, settings: S.delivery, provider: routing });
  const base = { max_radius_km: S.delivery.max_radius_km, zone: zone ? { id: zone.id, name: zone.name } : null };
  try {
    const f = calculateDeliveryFee({ fulfilment: 'delivery', distanceKm: dist.km, distanceMethod: dist.method, zone, settings: S.delivery });
    return { ...base, serviceable: true, fee: fromPaise(f.fee_paise), rule: f.rule, distance_km: f.distance_km, method: f.distance_method, zone: f.zone, error: null, zones_to_choose: null };
  } catch (e) {
    if (!(e instanceof AppError)) throw e;
    let zones: DeliveryEstimate['zones_to_choose'] = null;
    if (e.code === 'DELIVERY_ZONE_REQUIRED') zones = (await q.query('SELECT id, name, name_hi FROM delivery_zones WHERE is_active ORDER BY sort_order, name')).rows;
    const km = (e.details as any)?.distance_km ?? dist.km;
    return { ...base, serviceable: false, fee: null, rule: null, distance_km: km === null || km === undefined ? null : Number(Number(km).toFixed(2)), method: dist.method === 'none' ? null : dist.method, error: { code: e.code, message: e.message }, zones_to_choose: zones };
  }
}
