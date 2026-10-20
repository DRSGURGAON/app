import Constants from 'expo-constants';
import { secure } from './storage';

export const API_URL: string = ((Constants.expoConfig?.extra as any)?.apiUrl ?? process.env.EXPO_PUBLIC_API_URL ?? 'http://localhost:4000').replace(/\/$/, '');

export class ApiError extends Error {
  constructor(public status: number, public code: string, message: string, public details?: any) { super(message); }
  get isNetwork() { return this.code === 'NETWORK' || this.code === 'TIMEOUT'; }
}

const ACCESS = 'ardh.access', REFRESH = 'ardh.refresh';
let accessToken: string | null = null; let refreshToken: string | null = null; let loaded = false;
let onSessionLost: (() => void) | null = null;
export const setSessionLostHandler = (fn: () => void) => { onSessionLost = fn; };

async function load() { if (loaded) return; accessToken = await secure.get(ACCESS); refreshToken = await secure.get(REFRESH); loaded = true; }
export async function setTokens(a: string | null, r: string | null) {
  accessToken = a; refreshToken = r; loaded = true;
  if (a && r) { await secure.set(ACCESS, a); await secure.set(REFRESH, r); } else { await secure.del(ACCESS); await secure.del(REFRESH); }
}
export async function hasSession() { await load(); return !!refreshToken; }
export async function getRefreshToken() { await load(); return refreshToken; }

let refreshing: Promise<boolean> | null = null;
async function refresh(): Promise<boolean> {
  if (refreshing) return refreshing;
  refreshing = (async () => {
    try {
      if (!refreshToken) return false;
      const res = await rawFetch('/v1/auth/refresh', { method: 'POST', body: { refresh_token: refreshToken } });
      if (!res.ok) { if (res.status === 401 || res.status === 403) await setTokens(null, null); return false; }
      const j = await res.json(); await setTokens(j.access_token, j.refresh_token); return true;
    } catch { return false; } finally { refreshing = null; }
  })();
  return refreshing;
}

async function rawFetch(path: string, o: { method?: string; body?: unknown; headers?: Record<string, string>; timeoutMs?: number; signal?: AbortSignal }) {
  const ctrl = new AbortController(); const timer = setTimeout(() => ctrl.abort(), o.timeoutMs ?? 20000);
  o.signal?.addEventListener('abort', () => ctrl.abort());
  try {
    return await fetch(API_URL + path, { method: o.method ?? 'GET', headers: { Accept: 'application/json', ...(o.body !== undefined ? { 'Content-Type': 'application/json' } : {}), ...o.headers }, body: o.body !== undefined ? JSON.stringify(o.body) : undefined, signal: ctrl.signal });
  } catch (e: any) {
    if (o.signal?.aborted) throw new ApiError(0, 'ABORTED', 'Cancelled');
    throw new ApiError(0, e?.name === 'AbortError' ? 'TIMEOUT' : 'NETWORK', e?.name === 'AbortError' ? 'The server took too long to respond.' : 'No internet connection or the server is unreachable.');
  } finally { clearTimeout(timer); }
}

export interface ReqOpts { method?: string; body?: unknown; auth?: boolean; idempotencyKey?: string; signal?: AbortSignal; timeoutMs?: number }
export async function api<T = any>(path: string, o: ReqOpts = {}): Promise<T> {
  await load();
  const send = () => rawFetch(path, { method: o.method, body: o.body, signal: o.signal, timeoutMs: o.timeoutMs, headers: { ...(o.auth !== false && accessToken ? { Authorization: `Bearer ${accessToken}` } : {}), ...(o.idempotencyKey ? { 'Idempotency-Key': o.idempotencyKey } : {}) } });
  let res = await send();
  if (res.status === 401 && o.auth !== false && refreshToken) {
    if (await refresh()) res = await send(); else { onSessionLost?.(); }
  }
  let data: any = null; const text = await res.text(); try { data = text ? JSON.parse(text) : null; } catch { /* non-JSON */ }
  if (!res.ok) {
    const e = data?.error;
    throw new ApiError(res.status, e?.code ?? `HTTP_${res.status}`, e?.message ?? (res.status >= 500 ? 'Something went wrong on our side. Please try again.' : 'Request failed.'), e?.details);
  }
  return data as T;
}
export const newKey = () => { const h = () => Math.floor(Math.random() * 0x10000).toString(16).padStart(4, '0'); return `${Date.now().toString(36)}-${h()}${h()}-${h()}${h()}`; };
