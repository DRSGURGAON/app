const TOKEN = 'ardh.admin.token';
export const API = (import.meta.env.VITE_API_URL as string | undefined)?.replace(/\/$/, '') ?? '';
export class ApiError extends Error { constructor(public status: number, public code: string, message: string, public details?: any) { super(message); } }
let onAuthLost: (() => void) | null = null;
export const setAuthLostHandler = (f: () => void) => { onAuthLost = f; };
export const getToken = () => { try { return localStorage.getItem(TOKEN); } catch { return null; } };
export const setToken = (t: string | null) => { try { t ? localStorage.setItem(TOKEN, t) : localStorage.removeItem(TOKEN); } catch { /* ignore */ } };

async function raw(path: string, init: RequestInit & { json?: unknown; form?: FormData } = {}) {
  const headers: Record<string, string> = { Accept: 'application/json', ...(init.headers as Record<string, string> | undefined) };
  const t = getToken(); if (t) headers.Authorization = `Bearer ${t}`;
  let body: BodyInit | undefined = init.body ?? undefined;
  if (init.json !== undefined) { headers['Content-Type'] = 'application/json'; body = JSON.stringify(init.json); } else if (init.form) body = init.form;
  let res: Response;
  try { res = await fetch(API + '/v1/admin' + path, { ...init, headers, body }); } catch { throw new ApiError(0, 'NETWORK', 'Cannot reach the server. Check your internet connection.'); }
  if (res.status === 401 && path !== '/login') { setToken(null); onAuthLost?.(); }
  return res;
}
async function parse<T>(res: Response): Promise<T> {
  const text = await res.text(); let data: any = null; try { data = text ? JSON.parse(text) : null; } catch { /* not json */ }
  if (!res.ok) throw new ApiError(res.status, data?.error?.code ?? `HTTP_${res.status}`, data?.error?.message ?? `Request failed (${res.status})`, data?.error?.details);
  return data as T;
}
export const get = <T = any>(path: string) => raw(path).then((r) => parse<T>(r));
export const post = <T = any>(path: string, json?: unknown) => raw(path, { method: 'POST', json: json ?? {} }).then((r) => parse<T>(r));
export const put = <T = any>(path: string, json: unknown) => raw(path, { method: 'PUT', json }).then((r) => parse<T>(r));
export const patch = <T = any>(path: string, json: unknown) => raw(path, { method: 'PATCH', json }).then((r) => parse<T>(r));
export const del = <T = any>(path: string) => raw(path, { method: 'DELETE' }).then((r) => parse<T>(r));
export const upload = <T = any>(path: string, file: File, fields: Record<string, string> = {}) => { const f = new FormData(); for (const [k, v] of Object.entries(fields)) f.append(k, v); f.append('file', file); return raw(path, { method: 'POST', form: f }).then((r) => parse<T>(r)); };
/** Authenticated download / open (templates, invoices need the bearer token, so a plain link will not work). */
export async function fetchBlob(path: string): Promise<{ blob: Blob; filename?: string }> {
  const res = await raw(path); if (!res.ok) { await parse(res); }
  const cd = res.headers.get('content-disposition') ?? ''; return { blob: await res.blob(), filename: /filename="([^"]+)"/.exec(cd)?.[1] };
}
export async function download(path: string) { const { blob, filename } = await fetchBlob(path); const a = document.createElement('a'); a.href = URL.createObjectURL(blob); a.download = filename ?? 'download'; a.click(); setTimeout(() => URL.revokeObjectURL(a.href), 5000); }
export async function openHtml(path: string) { const { blob } = await fetchBlob(path); window.open(URL.createObjectURL(new Blob([await blob.text()], { type: 'text/html' })), '_blank'); }
export const inr = (v: unknown) => (v === null || v === undefined || v === '' ? '—' : '₹' + Number(v).toLocaleString('en-IN', { minimumFractionDigits: Number.isInteger(Number(v)) ? 0 : 2, maximumFractionDigits: 2 }));
export const dt = (v: string | null | undefined) => (v ? new Date(v).toLocaleString('en-IN', { day: 'numeric', month: 'short', year: '2-digit', hour: 'numeric', minute: '2-digit', timeZone: 'Asia/Kolkata' }) : '—');
