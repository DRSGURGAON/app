import type { Config } from './config.js';
import type { Db } from './db/pool.js';
import { createPaymentProvider } from './providers/payments.js';
import { createOtpSender } from './providers/otp.js';
import { createPush } from './providers/fcm.js';
import { OsrmProvider, GoogleRoutesProvider, type RoutingProvider } from './services/delivery.js';
import { CachedRouting, GooglePlaces, type PlacesProvider } from './services/maps.js';
import type { AppCtx } from './services/orders.js';

export function createRouting(c: Config, db?: Db): RoutingProvider | null {
  let p: RoutingProvider | null = null;
  if (c.ROUTING_PROVIDER === 'osrm' && c.OSRM_BASE_URL) p = new OsrmProvider(c.OSRM_BASE_URL);
  if (c.ROUTING_PROVIDER === 'google' && c.GOOGLE_MAPS_API_KEY) p = new GoogleRoutesProvider(c.GOOGLE_MAPS_API_KEY);
  return p && db ? new CachedRouting(p, db) : p; // cached so the same address is never billed twice
}

/** Address search / reverse-geocode. Needs the same server-side Google key; can be switched off with GOOGLE_PLACES_ENABLED=false. */
export function createPlaces(c: Config): PlacesProvider | null {
  return c.GOOGLE_MAPS_API_KEY && c.GOOGLE_PLACES_ENABLED ? new GooglePlaces(c.GOOGLE_MAPS_API_KEY) : null;
}

export function createCtx(config: Config, db: Db): AppCtx {
  return { db, config, payments: createPaymentProvider(config), otp: createOtpSender(config), push: createPush(config), routing: createRouting(config, db), places: createPlaces(config) };
}
