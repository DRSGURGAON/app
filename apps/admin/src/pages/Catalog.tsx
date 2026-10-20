import { useRef, useState } from 'react';
import * as api from '../api';
import { useAdmin } from '../App';
import { Badge, Check, Confirm, Field, Loading, Modal, Num, Pager, useAction, useDebounced, useLoad } from '../ui';
import { StockModal } from './Products';

function CategoryForm({ cat, tops, onClose, onSaved }: { cat: any; tops: any[]; onClose: () => void; onSaved: () => void }) {
  const run = useAction(); const fileRef = useRef<HTMLInputElement>(null); const [f, setF] = useState<any>({ name: '', name_hi: '', parent_id: '', description: '', sort_order: 0, is_active: true, ...cat });
  const set = (k: string, v: any) => setF((c: any) => ({ ...c, [k]: v }));
  const save = async () => { const body = { name: f.name, name_hi: f.name_hi || null, parent_id: f.parent_id || null, description: f.description || null, sort_order: Number(f.sort_order) || 0, is_active: f.is_active }; const r = await run(() => (cat.id ? api.put(`/categories/${cat.id}`, body) : api.post('/categories', body)), 'Saved'); if (r) { onSaved(); onClose(); } };
  return <Modal title={cat.id ? 'Edit category' : 'New category'} onClose={onClose} small>
    <Field label="Name (English) *"><input value={f.name} onChange={(e) => set('name', e.target.value)} /></Field><Field label="Name (Hindi)"><input value={f.name_hi ?? ''} onChange={(e) => set('name_hi', e.target.value)} /></Field>
    <Field label="Parent (leave empty for a main category)"><select value={f.parent_id ?? ''} onChange={(e) => set('parent_id', e.target.value)}><option value="">— Main category —</option>{tops.filter((t) => t.id !== cat.id).map((t) => <option key={t.id} value={t.id}>{t.name}</option>)}</select></Field>
    <Field label="Sort order"><Num value={f.sort_order} onChange={(v) => set('sort_order', v)} min={0} /></Field><Check label="Visible in app" checked={f.is_active} onChange={(v) => set('is_active', v)} />
    {cat.id ? <div className="row">{cat.image_url ? <img className="thumb" src={api.API + cat.image_url} alt="" /> : null}<input ref={fileRef} type="file" accept="image/jpeg,image/png,image/webp" hidden onChange={async (e) => { const file = e.target.files?.[0]; if (file && (await run(() => api.upload(`/categories/${cat.id}/image`, file), 'Image updated'))) onSaved(); e.target.value = ''; }} /><button onClick={() => fileRef.current?.click()}>Upload image</button></div> : null}
    <div className="row mt"><button className="primary" onClick={save}>Save</button><button onClick={onClose}>Cancel</button></div></Modal>;
}

export function Categories() {
  const { can } = useAdmin(); const run = useAction(); const { data, error, reload } = useLoad(() => api.get('/categories').then((r) => r.categories));
  const [edit, setEdit] = useState<any>(null); const [del, setDel] = useState<any>(null);
  if (!data) return <Loading error={error} retry={reload} />;
  const tops = data.filter((c: any) => !c.parent_id);
  const Row = ({ c, sub }: { c: any; sub?: boolean }) => <tr><td style={{ paddingLeft: sub ? 28 : 10 }}>{sub ? '↳ ' : ''}<b>{c.name}</b>{c.name_hi ? <small className="muted"> · {c.name_hi}</small> : null}</td><td>{c.product_count}</td><td>{c.is_active ? 'Visible' : <Badge kind="grey">Hidden</Badge>}</td>
    <td>{can('catalog:write') ? <div className="row"><button onClick={() => setEdit(c)}>Edit</button><button className="danger" onClick={() => setDel(c)}>Delete</button></div> : null}</td></tr>;
  return <><div className="row"><h1>Categories</h1>{can('catalog:write') ? <button className="primary right" onClick={() => setEdit({})}>＋ Add category</button> : null}</div>
    <div className="card" style={{ overflowX: 'auto' }}><table><thead><tr><th>Name</th><th>Products</th><th>Status</th><th></th></tr></thead><tbody>{tops.map((t: any) => <><Row key={t.id} c={t} />{data.filter((s: any) => s.parent_id === t.id).map((s: any) => <Row key={s.id} c={s} sub />)}</>)}</tbody></table></div>
    {edit ? <CategoryForm cat={edit} tops={tops} onClose={() => setEdit(null)} onSaved={reload} /> : null}
    {del ? <Confirm danger title="Delete category?" text={`Delete "${del.name}"? A category with products or sub-categories cannot be deleted — hide it instead.`} confirmLabel="Delete" onConfirm={async () => { await run(() => api.del(`/categories/${del.id}`), 'Deleted'); reload(); }} onClose={() => setDel(null)} /> : null}</>;
}

export function Inventory() {
  const { can } = useAdmin(); const [page, setPage] = useState(1); const [q, setQ] = useState(''); const [filter, setFilter] = useState(''); const [stock, setStock] = useState<any>(null); const dq = useDebounced(q);
  const { data, error, reload } = useLoad(() => { const p = new URLSearchParams({ page: String(page), limit: '30' }); if (dq) p.set('q', dq); if (filter) p.set('filter', filter); return api.get('/inventory?' + p); }, [page, dq, filter]);
  return <><h1>Inventory</h1><div className="card"><div className="row"><input style={{ maxWidth: 260 }} placeholder="Search name / SKU" value={q} onChange={(e) => { setQ(e.target.value); setPage(1); }} aria-label="Search" />
    <select style={{ maxWidth: 200 }} value={filter} onChange={(e) => { setFilter(e.target.value); setPage(1); }} aria-label="Filter"><option value="">All items</option><option value="low">Low stock</option><option value="out">Out of stock</option><option value="reserved">Has reserved stock</option></select></div></div>
    {!data ? <Loading error={error} retry={reload} /> : <div className="card" style={{ overflowX: 'auto' }}><table><thead><tr><th>Item</th><th>On hand</th><th>Reserved</th><th>Available</th><th></th></tr></thead><tbody>
      {data.items.map((p: any) => <tr key={p.id}><td>{p.name}<br /><small className="muted">{p.sku}{p.is_active ? '' : ' · hidden'}</small></td><td>{p.stock_qty}</td><td>{p.reserved_qty}</td><td><Badge kind={p.available <= 0 ? 'bad' : p.available <= p.low_stock_threshold ? 'warn' : undefined}>{p.available}</Badge></td><td>{can('inventory:write') ? <button onClick={() => setStock(p)}>Adjust / history</button> : null}</td></tr>)}</tbody></table>
      {!data.items.length ? <p className="muted">Nothing here.</p> : null}<Pager page={data.page} limit={data.limit} total={data.total} onPage={setPage} /></div>}
    {stock ? <StockModal p={stock} onClose={() => setStock(null)} onDone={reload} /> : null}</>;
}
