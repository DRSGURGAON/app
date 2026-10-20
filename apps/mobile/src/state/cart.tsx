import React, { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from 'react';
import { kv } from '../lib/storage';

export interface CartItem { product_id: string; qty: number; name: string; name_hi?: string | null; price: string; unit?: string | null; pack_size?: string | null; image_url?: string | null; max_per_order?: number | null }
interface CartCtx {
  items: CartItem[]; count: number; ready: boolean;
  add: (p: Omit<CartItem, 'qty'>, qty?: number) => void; setQty: (id: string, qty: number) => void; remove: (id: string) => void; clear: () => void; qtyOf: (id: string) => number;
  replaceAll: (items: { product_id: string; qty: number }[], snapshots?: Record<string, Omit<CartItem, 'qty' | 'product_id'>>) => void;
}
const Ctx = createContext<CartCtx>(null as any);
const KEY = 'ardh.cart.v1'; const MAX_QTY = 99;

export function reduceQty(cur: number, delta: number, max?: number | null) { return Math.max(0, Math.min(cur + delta, max ?? MAX_QTY, MAX_QTY)); }

export function CartProvider({ children }: { children: React.ReactNode }) {
  const [items, setItems] = useState<CartItem[]>([]); const [ready, setReady] = useState(false); const loaded = useRef(false);
  useEffect(() => { kv.get<CartItem[]>(KEY, []).then((i) => { setItems(Array.isArray(i) ? i.filter((x) => x?.product_id && x.qty > 0) : []); loaded.current = true; setReady(true); }); }, []);
  useEffect(() => { if (loaded.current) void kv.set(KEY, items); }, [items]);

  const add = useCallback((p: Omit<CartItem, 'qty'>, qty = 1) => setItems((cur) => {
    const i = cur.findIndex((c) => c.product_id === p.product_id);
    if (i === -1) return [...cur, { ...p, qty: Math.min(qty, p.max_per_order ?? MAX_QTY) }];
    const next = [...cur]; next[i] = { ...next[i], ...p, qty: reduceQty(next[i].qty, qty, p.max_per_order) }; return next;
  }), []);
  const setQty = useCallback((id: string, qty: number) => setItems((cur) => qty <= 0 ? cur.filter((c) => c.product_id !== id) : cur.map((c) => (c.product_id === id ? { ...c, qty: Math.min(qty, c.max_per_order ?? MAX_QTY, MAX_QTY) } : c))), []);
  const remove = useCallback((id: string) => setItems((cur) => cur.filter((c) => c.product_id !== id)), []);
  const clear = useCallback(() => setItems([]), []);
  const replaceAll = useCallback((list: { product_id: string; qty: number }[], snaps: Record<string, any> = {}) => setItems(list.map((l) => ({ product_id: l.product_id, qty: l.qty, name: snaps[l.product_id]?.name ?? '…', price: snaps[l.product_id]?.price ?? '0', ...snaps[l.product_id] }))), []);
  const value = useMemo<CartCtx>(() => ({ items, ready, count: items.reduce((n, i) => n + i.qty, 0), add, setQty, remove, clear, replaceAll, qtyOf: (id) => items.find((i) => i.product_id === id)?.qty ?? 0 }), [items, ready, add, setQty, remove, clear, replaceAll]);
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}
export const useCart = () => useContext(Ctx);
