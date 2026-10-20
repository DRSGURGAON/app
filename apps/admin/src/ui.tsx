import React, { createContext, useCallback, useContext, useEffect, useState } from 'react';
import { ApiError } from './api';

// ------------------------------------------------------------------ toasts
const ToastCtx = createContext<(msg: string, kind?: 'ok' | 'bad') => void>(() => {});
export const useToast = () => useContext(ToastCtx);
export function ToastProvider({ children }: { children: React.ReactNode }) {
  const [items, setItems] = useState<{ id: number; msg: string; kind: string }[]>([]);
  const push = useCallback((msg: string, kind: 'ok' | 'bad' = 'ok') => { const id = Date.now() + Math.random(); setItems((c) => [...c, { id, msg, kind }]); setTimeout(() => setItems((c) => c.filter((x) => x.id !== id)), kind === 'bad' ? 6000 : 3000); }, []);
  return <ToastCtx.Provider value={push}>{children}<div className="toasts" role="status" aria-live="polite">{items.map((i) => <div key={i.id} className={`toast ${i.kind}`}>{i.msg}</div>)}</div></ToastCtx.Provider>;
}
function friendly(e: unknown): string {
  const m = e instanceof Error ? e.message : 'Something went wrong';
  return m.replace(/Too small: expected string to have >=(\d+) characters?/, 'please enter at least $1 characters').replace(/Too small: expected number to be >=(-?[\d.]+)/, 'must be at least $1').replace(/Too big: expected number to be <=(-?[\d.]+)/, 'must be at most $1').replace(/Invalid input: expected number, received (?:NaN|string|null)/, 'enter a number');
}
/** Run an async action, toast errors, return undefined on failure. */
export function useAction() {
  const toast = useToast();
  return useCallback(async <T,>(fn: () => Promise<T>, okMsg?: string): Promise<T | undefined> => {
    try { const r = await fn(); if (okMsg) toast(okMsg, 'ok'); return r; } catch (e) { toast(friendly(e), 'bad'); return undefined; }
  }, [toast]);
}

// ------------------------------------------------------------------ data
export function useLoad<T>(fn: () => Promise<T>, deps: unknown[] = []) {
  const [data, setData] = useState<T | null>(null); const [error, setError] = useState<string | null>(null); const [loading, setLoading] = useState(true);
  const load = useCallback(async () => { setLoading(true); try { setData(await fn()); setError(null); } catch (e) { setError(e instanceof ApiError ? e.message : 'Failed to load'); } finally { setLoading(false); } }, deps); // eslint-disable-line react-hooks/exhaustive-deps
  useEffect(() => { void load(); }, [load]);
  return { data, error, loading, reload: load, setData };
}
export const Loading = ({ error, retry }: { error?: string | null; retry?: () => void }) => error ? <div className="card"><div className="err">{error}</div>{retry ? <button onClick={retry}>Try again</button> : null}</div> : <div className="card muted">Loading…</div>;

// ------------------------------------------------------------------ primitives
export function Modal({ title, onClose, children, small }: { title: string; onClose: () => void; children: React.ReactNode; small?: boolean }) {
  useEffect(() => { const h = (e: KeyboardEvent) => e.key === 'Escape' && onClose(); window.addEventListener('keydown', h); return () => window.removeEventListener('keydown', h); }, [onClose]);
  return <div className="modal-bg" onMouseDown={(e) => e.target === e.currentTarget && onClose()}><div className={`modal ${small ? 'sm' : ''}`} role="dialog" aria-modal="true" aria-label={title}><h2>{title}<button className="ghost" onClick={onClose} aria-label="Close">✕</button></h2>{children}</div></div>;
}
export function Field({ label, hint, children }: { label: string; hint?: string; children: React.ReactNode }) { return <label className="f"><span>{label}</span>{children}{hint ? <div className="hint">{hint}</div> : null}</label>; }
export function Check({ label, checked, onChange, hint }: { label: string; checked: boolean; onChange: (v: boolean) => void; hint?: string }) { return <div><label className="chk"><input type="checkbox" checked={checked} onChange={(e) => onChange(e.target.checked)} />{label}</label>{hint ? <div className="hint" style={{ marginTop: -6, marginBottom: 8 }}>{hint}</div> : null}</div>; }
export function Num({ value, onChange, step, min, max, nullable }: { value: number | null | undefined; onChange: (v: any) => void; step?: number; min?: number; max?: number; nullable?: boolean }) {
  return <input type="number" inputMode="decimal" value={value ?? ''} step={step ?? 1} min={min} max={max} onChange={(e) => onChange(e.target.value === '' ? (nullable ? null : 0) : Number(e.target.value))} />;
}
export const Badge = ({ children, kind }: { children: React.ReactNode; kind?: 'warn' | 'bad' | 'grey' }) => <span className={`badge ${kind ?? ''}`}>{children}</span>;
export function Pager({ page, limit, total, onPage }: { page: number; limit: number; total: number; onPage: (p: number) => void }) {
  const pages = Math.max(1, Math.ceil(total / limit));
  return <div className="pager no-print"><button disabled={page <= 1} onClick={() => onPage(page - 1)}>← Prev</button><span className="muted">Page {page} of {pages} · {total} total</span><button disabled={page >= pages} onClick={() => onPage(page + 1)}>Next →</button></div>;
}
export function useDebounced<T>(v: T, ms = 350) { const [d, setD] = useState(v); useEffect(() => { const t = setTimeout(() => setD(v), ms); return () => clearTimeout(t); }, [v, ms]); return d; }
export function Confirm({ title, text, confirmLabel = 'Confirm', danger, onConfirm, onClose }: { title: string; text: string; confirmLabel?: string; danger?: boolean; onConfirm: () => void | Promise<void>; onClose: () => void }) {
  const [busy, setBusy] = useState(false);
  return <Modal title={title} onClose={onClose} small><p>{text}</p><div className="row"><button className={danger ? 'danger' : 'primary'} disabled={busy} onClick={async () => { setBusy(true); try { await onConfirm(); } finally { setBusy(false); } onClose(); }}>{confirmLabel}</button><button onClick={onClose}>Cancel</button></div></Modal>;
}
export const statusKind = (s: string): 'warn' | 'bad' | 'grey' | undefined => (['cancelled', 'rejected'].includes(s) ? 'bad' : ['refund_pending', 'pending_payment'].includes(s) ? 'warn' : ['refunded'].includes(s) ? 'grey' : undefined);
