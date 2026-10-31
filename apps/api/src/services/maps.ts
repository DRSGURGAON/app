import type { Db } from '../db/pool.js';
import type { LatLng, RoutingProvider } from './delivery.js';

// ------------------------------------------------------------------ distance cache (wraps any routing provider)
const TTL_DAYS = 90;
const r6 = (n: number) => Math.round(n * 1e6) / 1e6;
const r5 = (n: number) => Math.round(n * 1e5) / 1e5;

export class CachedRouting implements RoutingProvider {
  constructor(private inner: RoutingProvider, private db: Db) {}
  get method() { return this.inner.method; }
  async roadDistanceMeters(from: LatLng, to: LatLng, signal: AbortSignal): Promise<number> {
    const key = [r6(from.lat), r6(from.lng), r5(to.lat), r5(to.lng), this.inner.method];
    try {
      const hit = await this.db.query(`SELECT meters FROM distance_cache WHERE store_lat=$1 AND store_lng=$2 AND dest_lat=$3 AND dest_lng=$4 AND method=$5 AND created_at > now() - interval '${TTL_DAYS} days'`, key);
      if (hit.rowCount) return hit.rows[0].meters as number;
    } catch { /* cache is an optimisation only */ }
    const meters = await this.inner.roadDistanceMeters(from, to, signal);
    try {
      await this.db.query(`INSERT INTO distance_cache (store_lat, store_lng, dest_lat, dest_lng, method, meters) VALUES ($1,$2,$3,$4,$5,$6)
        ON CONFLICT (store_lat, store_lng, dest_lat, dest_lng, method) DO UPDATE SET meters = EXCLUDED.meters, created_at = now()`, [...key, Math.round(meters)]);
    } catch { /* ignore */ }
    return meters;
  }
}

// ------------------------------------------------------------------ places / geocoding (server-side; the key never reaches the app)
export interface PlaceSuggestion { place_id: string; text: string; main: string; secondary: string }
export interface PlaceDetails { place_id: string; latitude: number; longitude: number; formatted_address: string; pincode: string | null; locality: string | null }
export interface ReverseResult { formatted_address: string; pincode: string | null; locality: string | null }

export interface PlacesProvider {
  autocomplete(input: string, session: string, bias: LatLng | null, signal: AbortSignal): Promise<PlaceSuggestion[]>;
  details(placeId: string, session: string, signal: AbortSignal): Promise<PlaceDetails>;
  reverse(at: LatLng, signal: AbortSignal): Promise<ReverseResult | null>;
}

const comp = (list: any[] | undefined, type: string) => (list ?? []).find((c) => (c.types ?? []).includes(type));

export class GooglePlaces implements PlacesProvider {
  constructor(private apiKey: string, private fetchImpl: typeof fetch = fetch) {}

  async autocomplete(input: string, session: string, bias: LatLng | null, signal: AbortSignal): Promise<PlaceSuggestion[]> {
    const res = await this.fetchImpl('https://places.googleapis.com/v1/places:autocomplete', {
      method: 'POST', signal,
      headers: { 'content-type': 'application/json', 'X-Goog-Api-Key': this.apiKey, 'X-Goog-FieldMask': 'suggestions.placePrediction.placeId,suggestions.placePrediction.text.text,suggestions.placePrediction.structuredFormat' },
      body: JSON.stringify({
        input, sessionToken: session, includedRegionCodes: ['in'], languageCode: 'en',
        ...(bias ? { locationBias: { circle: { center: { latitude: bias.lat, longitude: bias.lng }, radius: 50000 } } } : {}),
      }),
    });
    if (!res.ok) throw new Error(`Google Places autocomplete HTTP ${res.status}`);
    const body: any = await res.json();
    return (body?.suggestions ?? []).map((s: any) => s.placePrediction).filter(Boolean).slice(0, 6).map((p: any) => ({
      place_id: String(p.placeId), text: String(p.text?.text ?? ''), main: String(p.structuredFormat?.mainText?.text ?? p.text?.text ?? ''), secondary: String(p.structuredFormat?.secondaryText?.text ?? ''),
    }));
  }

  async details(placeId: string, session: string, signal: AbortSignal): Promise<PlaceDetails> {
    const res = await this.fetchImpl(`https://places.googleapis.com/v1/places/${encodeURIComponent(placeId)}?sessionToken=${encodeURIComponent(session)}`, {
      signal, headers: { 'X-Goog-Api-Key': this.apiKey, 'X-Goog-FieldMask': 'id,location,formattedAddress,addressComponents' },
    });
    if (!res.ok) throw new Error(`Google Place details HTTP ${res.status}`);
    const b: any = await res.json();
    if (typeof b?.location?.latitude !== 'number' || typeof b?.location?.longitude !== 'number') throw new Error('Place has no location');
    const comps = b.addressComponents as any[] | undefined;
    const pin = (comps ?? []).find((c) => (c.types ?? []).includes('postal_code'))?.longText;
    const loc = (comps ?? []).find((c) => (c.types ?? []).includes('locality') || (c.types ?? []).includes('sublocality'))?.longText;
    return { place_id: String(b.id ?? placeId), latitude: b.location.latitude, longitude: b.location.longitude, formatted_address: String(b.formattedAddress ?? ''), pincode: /^\d{6}$/.test(pin ?? '') ? pin : null, locality: loc ?? null };
  }

  async reverse(at: LatLng, signal: AbortSignal): Promise<ReverseResult | null> {
    const res = await this.fetchImpl(`https://maps.googleapis.com/maps/api/geocode/json?latlng=${at.lat},${at.lng}&language=en&key=${encodeURIComponent(this.apiKey)}`, { signal });
    if (!res.ok) throw new Error(`Google Geocoding HTTP ${res.status}`);
    const b: any = await res.json();
    if (b?.status === 'ZERO_RESULTS') return null;
    if (b?.status !== 'OK') throw new Error(`Google Geocoding status ${b?.status}`);
    const r = b.results?.[0]; if (!r) return null;
    const pin = comp(r.address_components, 'postal_code')?.long_name;
    const loc = (comp(r.address_components, 'locality') ?? comp(r.address_components, 'sublocality'))?.long_name;
    return { formatted_address: String(r.formatted_address ?? ''), pincode: /^\d{6}$/.test(pin ?? '') ? pin : null, locality: loc ?? null };
  }
}
