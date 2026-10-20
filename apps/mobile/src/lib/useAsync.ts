import { useCallback, useEffect, useRef, useState } from 'react';
import { ApiError } from './api';

export interface AsyncState<T> { data: T | null; loading: boolean; error: ApiError | null; reload: () => Promise<void>; setData: (d: T | null) => void }
/** Small data hook: loading / error / retry, ignores stale responses. */
export function useAsync<T>(fn: (signal: AbortSignal) => Promise<T>, deps: unknown[] = [], enabled = true): AsyncState<T> {
  const [data, setData] = useState<T | null>(null); const [loading, setLoading] = useState(enabled); const [error, setError] = useState<ApiError | null>(null);
  const seq = useRef(0); const fnRef = useRef(fn); fnRef.current = fn;
  const run = useCallback(async () => {
    const id = ++seq.current; const ctrl = new AbortController(); setLoading(true); setError(null);
    try { const d = await fnRef.current(ctrl.signal); if (id === seq.current) setData(d); }
    catch (e: any) { if (id === seq.current && e?.code !== 'ABORTED') setError(e instanceof ApiError ? e : new ApiError(0, 'UNKNOWN', e?.message ?? 'Error')); }
    finally { if (id === seq.current) setLoading(false); }
  }, []);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  useEffect(() => { if (enabled) void run(); else setLoading(false); return () => { seq.current++; }; }, [enabled, ...deps]);
  return { data, loading, error, reload: run, setData };
}
