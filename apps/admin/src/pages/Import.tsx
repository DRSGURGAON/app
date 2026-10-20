import { useRef, useState } from 'react';
import * as api from '../api';
import { dt } from '../api';
import { Badge, Check, useAction, useLoad } from '../ui';

export default function ImportPage() {
  const run = useAction(); const fileRef = useRef<HTMLInputElement>(null);
  const [applyUpdates, setApplyUpdates] = useState(false); const [updateStock, setUpdateStock] = useState(false); const [file, setFile] = useState<File | null>(null);
  const [preview, setPreview] = useState<any>(null); const [result, setResult] = useState<any>(null); const [busy, setBusy] = useState(false);
  const jobs = useLoad(() => api.get('/imports').then((r) => r.jobs));
  const doPreview = async () => { if (!file) return; setBusy(true); setResult(null); const r = await run(() => api.upload('/imports/preview', file, { apply_updates: String(applyUpdates), update_stock: String(updateStock) })); setBusy(false); if (r) setPreview(r); };
  const confirm = async () => { setBusy(true); const r = await run(() => api.post(`/imports/${preview.job_id}/confirm`, { apply_updates: applyUpdates }), 'Import applied'); setBusy(false); if (r) { setResult(r.result); setPreview(null); setFile(null); if (fileRef.current) fileRef.current.value = ''; jobs.reload(); } };
  const cancel = async () => { await run(() => api.post(`/imports/${preview.job_id}/cancel`)); setPreview(null); jobs.reload(); };
  return <><h1>Import products</h1>
    <div className="card"><h2>1 · Download the template</h2><p className="muted">Fill one row per product. Use the exact category names from your catalogue (unknown categories are rejected, never auto-created). Columns marked * are required.</p>
      <div className="row"><button onClick={() => run(() => api.download('/imports/template?format=xlsx'))}>⬇️ Excel template (.xlsx)</button><button onClick={() => run(() => api.download('/imports/template?format=csv'))}>⬇️ CSV template</button></div></div>
    <div className="card"><h2>2 · Upload and preview</h2><p className="muted">Nothing is saved until you confirm. Max 5,000 rows / 6 MB.</p>
      <input ref={fileRef} type="file" accept=".csv,.xlsx" onChange={(e) => { setFile(e.target.files?.[0] ?? null); setPreview(null); }} aria-label="Choose file" />
      <Check label="Also update products that already exist (matched by SKU)" checked={applyUpdates} onChange={setApplyUpdates} hint="Off = existing SKUs are left untouched; only new products are created." />
      <Check label="Include stock quantities for existing products" checked={updateStock} onChange={setUpdateStock} hint="Stock changes are recorded in the stock history. New products always get their opening stock." />
      <button className="primary" disabled={!file || busy} onClick={doPreview}>{busy ? 'Checking…' : 'Preview import'}</button></div>
    {preview ? <div className="card"><h2>3 · Review</h2>
      <div className="row"><Badge>{preview.counts.create} new</Badge><Badge kind="warn">{preview.counts.update} to update</Badge><Badge kind="grey">{preview.counts.unchanged} unchanged</Badge><Badge kind={preview.invalid_rows ? 'bad' : undefined}>{preview.invalid_rows} rows with errors</Badge><span className="muted">of {preview.total_rows} rows</span></div>
      {preview.errors.length ? <><h3>Problems (these rows will NOT be imported)</h3><table><thead><tr><th>Row</th><th>Field</th><th>Problem</th></tr></thead><tbody>{preview.errors.map((e: any, i: number) => <tr key={i}><td>{e.row}</td><td>{e.field}</td><td className="err">{e.message}</td></tr>)}</tbody></table></> : null}
      {preview.sample.length ? <><h3>Changes (first {preview.sample.length})</h3><table className="diff"><thead><tr><th>Row / SKU</th><th>Was</th><th>Becomes</th></tr></thead><tbody>
        {preview.sample.map((s: any) => s.action === 'create' ? <tr key={s.row}><td>{s.row} · {s.sku}</td><td colSpan={2} style={{ color: 'var(--ok)', textDecoration: 'none' }}>NEW: {s.values.name} · ₹{s.values.price} · stock {s.stock_qty}</td></tr>
          : <>{Object.entries(s.diff).map(([k, d]: any) => <tr key={s.row + k}><td>{s.row} · {s.sku} · {k}</td><td>{String(d.from ?? '—')}</td><td>{String(d.to ?? '—')}</td></tr>)}{s.stock_change ? <tr key={s.row + 's'}><td>{s.row} · {s.sku} · stock</td><td>{s.before?.stock_qty}</td><td>{s.stock_qty}</td></tr> : null}</>)}</tbody></table></> : <p className="muted">No changes to apply.</p>}
      <div className="row mt"><button className="primary" disabled={busy || (preview.counts.create === 0 && !(applyUpdates && preview.counts.update))} onClick={confirm}>Confirm import</button><button onClick={cancel}>Cancel</button></div></div> : null}
    {result ? <div className="card"><h2>Import finished</h2><p>Created <b>{result.created}</b> · Updated <b>{result.updated}</b> · Unchanged {result.unchanged} · Existing SKUs left untouched {result.skipped_updates}</p>
      {result.conflicts?.length ? <><h3>Skipped (nothing overwritten)</h3><table><tbody>{result.conflicts.map((c: any, i: number) => <tr key={i}><td>Row {c.row}</td><td>{c.sku}</td><td>{c.message}</td></tr>)}</tbody></table></> : null}</div> : null}
    <div className="card"><h2>Recent imports</h2>{jobs.data?.length ? <table><thead><tr><th>File</th><th>Status</th><th>New</th><th>Updates</th><th>Errors</th><th>When</th></tr></thead><tbody>{jobs.data.map((j: any) => <tr key={j.id}><td>{j.filename}</td><td>{j.status}</td><td>{j.create_count}</td><td>{j.update_count}</td><td>{j.invalid_rows}</td><td>{dt(j.applied_at ?? j.created_at)}</td></tr>)}</tbody></table> : <p className="muted">None yet.</p>}</div></>;
}
