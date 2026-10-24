import { useEffect, useRef, useState } from 'react';
import { api, ApiError } from './api';

export interface Blocker { code: string; message: string; details?: any }
export interface Quote {
  lines: { product_id: string; name: string; name_hi: string | null; unit: string; pack_size: string | null; image_url: string | null; mrp: string; unit_price: string; qty: number; line_total: string; available: number; issue: Blocker | null }[];
  totals: { mrp_total: string; subtotal: string; savings: string; coupon_discount: string; first_order_discount: string; coin_discount: string; delivery_fee: string | null; tax_included: string; total: string | null; total_before_delivery: string };
  coupon: { code: string; applied: boolean; title?: string; error?: Blocker } | null;
  first_order: { enabled: boolean; eligible: boolean; applied: boolean; discount: string; note?: string };
  coins: { enabled: boolean; balance: number; requested: number; applied: number; max_usable: number; coin_value: string; will_earn: number; earn_note?: string };
  min_order: { required: string; current: string; shortfall: string; met: boolean; basis: string };
  delivery: { fulfilment: 'delivery' | 'pickup'; fee: string | null; rule: string | null; distance_km: number | null; method: string | null; zone: { id: string; name: string } | null; pending: boolean; error: Blocker | null; zones_to_choose: { id: string; name: string; name_hi: string | null }[] | null };
  store: { open: boolean; reason?: string };
  blockers: Blocker[]; can_checkout: boolean;
}
export interface QuoteParams { items: { product_id: string; qty: number }[]; fulfilment: 'delivery' | 'pickup'; address_id?: string | null; zone_id?: string | null; coupon_code?: string | null; use_coins?: number; payment_method?: 'cod' | 'online' | 'upi' | null }

/** Debounced server quote. The server is the only source of truth for prices, fees and discounts. */
export function useQuote(p: QuoteParams, enabled = true) {
  const [quote, setQuote] = useState<Quote | null>(null); const [loading, setLoading] = useState(enabled); const [error, setError] = useState<ApiError | null>(null);
  const seq = useRef(0); const key = JSON.stringify(p); const [tick, setTick] = useState(0);
  useEffect(() => {
    if (!enabled || p.items.length === 0) { setQuote(null); setLoading(false); return; }
    const id = ++seq.current; setLoading(true);
    const h = setTimeout(async () => {
      try { const r = await api<{ quote: Quote }>('/v1/cart/quote', { method: 'POST', body: p }); if (id === seq.current) { setQuote(r.quote); setError(null); } }
      catch (e: any) { if (id === seq.current) setError(e instanceof ApiError ? e : new ApiError(0, 'UNKNOWN', e?.message ?? 'error')); }
      finally { if (id === seq.current) setLoading(false); }
    }, 250);
    return () => { clearTimeout(h); seq.current++; };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key, enabled, tick]);
  return { quote, loading, error, reload: () => setTick((n) => n + 1) };
}
