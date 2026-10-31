import { api, ApiError } from './api';
import type { Key } from '../i18n/en';

export interface Coords { latitude: number; longitude: number }
export interface PlaceSuggestion { place_id: string; text: string; main: string; secondary: string }
export interface PlaceDetails { place_id: string; latitude: number; longitude: number; formatted_address: string; pincode: string | null; locality: string | null }
export interface Estimate {
  serviceable: boolean; fee: string | null; rule: string | null; distance_km: number | null; method: string | null; zone: { id: string; name: string } | null;
  max_radius_km: number; error: { code: string; message: string } | null; zones_to_choose: { id: string; name: string; name_hi: string | null }[] | null;
}

/** Google bills address search per "session" (typing + the final pick). One token per search, new token after a pick. */
export const newSession = () => Array.from({ length: 24 }, () => 'abcdefghijklmnopqrstuvwxyz0123456789'[Math.floor(Math.random() * 36)]).join('');

export const searchPlaces = (q: string, session: string, signal?: AbortSignal) =>
  api<{ suggestions: PlaceSuggestion[] }>(`/v1/maps/autocomplete?q=${encodeURIComponent(q)}&session=${session}`, { signal }).then((r) => r.suggestions);
export const getPlace = (placeId: string, session: string) => api<{ place: PlaceDetails }>(`/v1/maps/place?place_id=${encodeURIComponent(placeId)}&session=${session}`).then((r) => r.place);
export const reversePin = (c: Coords) => api<{ result: { formatted_address: string; pincode: string | null; locality: string | null } | null }>(`/v1/maps/reverse?lat=${c.latitude}&lng=${c.longitude}`).then((r) => r.result);
export const estimateDelivery = (c: Coords, extra: { zone_id?: string | null; pincode?: string | null } = {}, signal?: AbortSignal) =>
  api<{ estimate: Estimate }>('/v1/delivery/estimate', { method: 'POST', body: { latitude: c.latitude, longitude: c.longitude, zone_id: extra.zone_id ?? null, pincode: /^\d{6}$/.test(extra.pincode ?? '') ? extra.pincode : null }, signal }).then((r) => r.estimate);

export const isMapsUnavailable = (e: unknown) => e instanceof ApiError && e.code === 'MAPS_UNAVAILABLE';

/** Turn a server estimate into a one-line message key + variables (server numbers are shown as-is; the app never recalculates fees). */
export function describeEstimate(e: Estimate): { key: Key; vars: Record<string, string | number>; ok: boolean } {
  if (e.serviceable && e.fee !== null) {
    const fee = Number(e.fee).toLocaleString('en-IN', { maximumFractionDigits: 2 });
    if (e.method === 'zone' || e.distance_km === null) return { key: 'estZone', vars: { zone: e.zone?.name ?? '', fee }, ok: true };
    if (e.method === 'straight_line') return { key: 'estApprox', vars: { km: e.distance_km, fee }, ok: true };
    return { key: 'estRoad', vars: { km: e.distance_km, fee }, ok: true };
  }
  if (e.error?.code === 'DELIVERY_NOT_SERVICEABLE') {
    return e.distance_km !== null ? { key: 'estOutside', vars: { km: e.distance_km, max: e.max_radius_km }, ok: false } : { key: 'estOutsideNoDist', vars: { max: e.max_radius_km }, ok: false };
  }
  if (e.error?.code === 'DELIVERY_ZONE_REQUIRED') return { key: 'estNeedZone', vars: {}, ok: false };
  return { key: 'estFailed', vars: {}, ok: false };
}
