import React, { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import { api } from '../lib/api';
import { kv } from '../lib/storage';

export interface StoreConfig {
  store: { name_hi: string; name_en: string; phone: string; address_hi: string; address_en: string; open_time: string; close_time: string; open_now: boolean; closed_reason: string | null; closed_message: string; delivery_enabled: boolean; pickup_enabled: boolean; pickup_instructions: string };
  delivery: { base_fee: string; far_fee: string; near_radius_km: number; max_radius_km: number };
  order: { min_order: string; cod_enabled: boolean; online_enabled: boolean; payment_window_minutes: number };
  coins: { enabled: boolean; coin_value: number; earn_coins_per_unit: number; earn_spend_unit: number };
  first_order: { enabled: boolean; [k: string]: unknown };
  payments: { provider: string; mode: string; live: boolean };
  policies: Record<'privacy' | 'terms' | 'delivery' | 'cancellation' | 'refund', { en: string; hi: string }>;
}
interface Ctx { config: StoreConfig | null; loading: boolean; error: string | null; reload: () => Promise<void> }
const C = createContext<Ctx>({ config: null, loading: true, error: null, reload: async () => {} });

export function StoreConfigProvider({ children }: { children: React.ReactNode }) {
  const [config, setConfig] = useState<StoreConfig | null>(null); const [loading, setLoading] = useState(true); const [error, setError] = useState<string | null>(null);
  const reload = useCallback(async () => {
    setLoading(true);
    try { const c = await api<StoreConfig>('/v1/config', { auth: false }); setConfig(c); setError(null); void kv.set('ardh.config.cache', c); }
    catch (e: any) { setError(e?.message ?? 'error'); const cached = await kv.get<StoreConfig | null>('ardh.config.cache', null); if (cached) setConfig(cached); }
    finally { setLoading(false); }
  }, []);
  useEffect(() => { void reload(); }, [reload]);
  const value = useMemo(() => ({ config, loading, error, reload }), [config, loading, error, reload]);
  return <C.Provider value={value}>{children}</C.Provider>;
}
export const useStoreConfig = () => useContext(C);
