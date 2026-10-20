import { useRef, useState } from 'react';
import * as api from '../api';
import { dt, inr } from '../api';
import { useAdmin } from '../App';
import { Badge, Check, Confirm, Field, Loading, Modal, Num, Pager, useAction, useDebounced, useLoad } from '../ui';

const EMPTY: any = { sku: '', barcode: '', name: '', name_hi: '', brand: '', category_id: '', subcategory_id: '', description: '', unit: 'pc', pack_size: '', mrp: '', price: '', tax_rate: 0, hsn_code: '', low_stock_threshold: 5, max_per_order: null, is_active: true, is_featured: false, coins_eligible: true, offers_eligible: true, opening_stock: 0 };

export function StockModal({ p, onClose, onDone }: { p: { id: string; name: string; stock_qty: number; reserved_qty: number }; onClose: () => void; onDone: () => void }) {
  const run = useAction(); const [mode, setMode] = useState<'delta' | 'set'>('delta'); const [n, setN] = useState(0); const [reason, setReason] = useState('');
  const { data } = useLoad(() => api.get(`/products/${p.id}/movements`).then((r) => r.movements), [p.id]);
  return <Modal title={`Stock · ${p.name}`} onClose={onClose}>
    <p>On hand <b>{p.stock_qty}</b> · reserved for open orders <b>{p.reserved_qty}</b> · available <b>{p.stock_qty - p.reserved_qty}</b></p>
    <div className="row"><select style={{ maxWidth: 200 }} value={mode} onChange={(e) => setMode(e.target.value as any)}><option value="delta">Add / remove (+/−)</option><option value="set">Set total to</option></select><Num value={n} onChange={setN} min={mode === 'set' ? 0 : undefined} /></div>
    <Field label="Reason (required — saved in history)"><input value={reason} onChange={(e) => setReason(e.target.value)} placeholder="e.g. New stock received / damaged / recount" /></Field>
    <div className="row"><button className="primary" onClick={async () => { if (await run(() => api.post(`/products/${p.id}/stock`, mode === 'delta' ? { delta: n, reason } : { set_to: n, reason }), 'Stock updated')) { onDone(); onClose(); } }}>Save stock</button><button onClick={onClose}>Cancel</button></div>
    <h3>Recent movements</h3>{data ? <table><thead><tr><th>When</th><th>Type</th><th>Δ</th><th>Reason</th></tr></thead><tbody>{data.map((m: any) => <tr key={m.id}><td>{dt(m.created_at)}</td><td>{m.type}</td><td>{m.qty_delta ? `${m.qty_delta > 0 ? '+' : ''}${m.qty_delta}` : ''}{m.reserved_delta ? ` (res ${m.reserved_delta > 0 ? '+' : ''}${m.reserved_delta})` : ''}</td><td>{m.reason ?? m.order_no ?? ''}<small className="muted"> {m.admin_name ?? ''}</small></td></tr>)}</tbody></table> : <p className="muted">Loading…</p>}
  </Modal>;
}

function ProductForm({ id, cats, onClose, onSaved }: { id: string | 'new'; cats: any[]; onClose: () => void; onSaved: () => void }) {
  const run = useAction(); const fileRef = useRef<HTMLInputElement>(null);
  const [f, setF] = useState<any>(EMPTY); const [images, setImages] = useState<any[]>([]); const [loaded, setLoaded] = useState(id === 'new'); const [pid, setPid] = useState<string>(id);
  const load = async () => { const r = await api.get(`/products/${pid}`); setF({ ...EMPTY, ...r.product, subcategory_id: r.product.subcategory_id ?? '' }); setImages(r.images); setLoaded(true); };
  useLoad(async () => { if (id !== 'new') await load(); return 1; }, [id]);
  const set = (k: string, v: any) => setF((c: any) => ({ ...c, [k]: v }));
  const tops = cats.filter((c) => !c.parent_id); const subs = cats.filter((c) => c.parent_id === f.category_id);
  const save = async () => {
    const body = { ...f, subcategory_id: f.subcategory_id || null, mrp: String(f.mrp), price: String(f.price), tax_rate: Number(f.tax_rate), barcode: f.barcode || null, name_hi: f.name_hi || null, brand: f.brand || null, pack_size: f.pack_size || null, hsn_code: f.hsn_code || null, description: f.description || null };
    if (pid !== 'new') { delete body.opening_stock; }
    const r = await run(() => (pid === 'new' ? api.post('/products', body) : api.put(`/products/${pid}`, body)), 'Saved');
    if (r) { onSaved(); if (pid === 'new') { setPid(r.product.id); } else onClose(); }
  };
  const addImage = async (file: File) => { const r = await run(() => api.upload(`/products/${pid}/images`, file), 'Photo added'); if (r) setImages((c) => [...c, r.image]); };
  if (!loaded) return <Modal title="Product" onClose={onClose}><Loading /></Modal>;
  return <Modal title={pid === 'new' ? 'New product' : `Edit · ${f.name}`} onClose={onClose}>
    <div className="row"><div className="grow"><Field label="SKU *"><input value={f.sku} onChange={(e) => set('sku', e.target.value)} /></Field></div><div className="grow"><Field label="Barcode"><input value={f.barcode ?? ''} onChange={(e) => set('barcode', e.target.value)} /></Field></div></div>
    <Field label="Name (English) *"><input value={f.name} onChange={(e) => set('name', e.target.value)} /></Field>
    <div className="row"><div className="grow"><Field label="Name (Hindi)"><input value={f.name_hi ?? ''} onChange={(e) => set('name_hi', e.target.value)} /></Field></div><div className="grow"><Field label="Brand"><input value={f.brand ?? ''} onChange={(e) => set('brand', e.target.value)} /></Field></div></div>
    <div className="row"><div className="grow"><Field label="Category *"><select value={f.category_id} onChange={(e) => { set('category_id', e.target.value); set('subcategory_id', ''); }}><option value="">Choose…</option>{tops.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}</select></Field></div>
      <div className="grow"><Field label="Sub-category"><select value={f.subcategory_id ?? ''} onChange={(e) => set('subcategory_id', e.target.value)}><option value="">—</option>{subs.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}</select></Field></div></div>
    <div className="row"><div className="grow"><Field label="MRP ₹ *"><input inputMode="decimal" value={f.mrp} onChange={(e) => set('mrp', e.target.value)} /></Field></div><div className="grow"><Field label="Selling price ₹ *" hint="Cannot be above MRP"><input inputMode="decimal" value={f.price} onChange={(e) => set('price', e.target.value)} /></Field></div>
      <div className="grow"><Field label="Unit"><input value={f.unit} onChange={(e) => set('unit', e.target.value)} /></Field></div><div className="grow"><Field label="Pack size"><input value={f.pack_size ?? ''} onChange={(e) => set('pack_size', e.target.value)} placeholder="e.g. 5 kg" /></Field></div></div>
    <div className="row"><div className="grow"><Field label="GST % (included in price)"><Num value={f.tax_rate} onChange={(v) => set('tax_rate', v)} step={0.5} min={0} max={100} /></Field></div><div className="grow"><Field label="HSN"><input value={f.hsn_code ?? ''} onChange={(e) => set('hsn_code', e.target.value)} /></Field></div>
      <div className="grow"><Field label="Low-stock alert at"><Num value={f.low_stock_threshold} onChange={(v) => set('low_stock_threshold', v)} min={0} /></Field></div><div className="grow"><Field label="Max per order"><Num nullable value={f.max_per_order} onChange={(v) => set('max_per_order', v)} min={1} /></Field></div></div>
    {pid === 'new' ? <Field label="Opening stock"><Num value={f.opening_stock} onChange={(v) => set('opening_stock', v)} min={0} /></Field> : <p className="muted">Stock is changed from the Inventory page (with a reason).</p>}
    <Field label="Description"><textarea value={f.description ?? ''} onChange={(e) => set('description', e.target.value)} /></Field>
    <div className="row"><Check label="Visible in app" checked={f.is_active} onChange={(v) => set('is_active', v)} /><Check label="Featured" checked={f.is_featured} onChange={(v) => set('is_featured', v)} /><Check label="Earns coins" checked={f.coins_eligible} onChange={(v) => set('coins_eligible', v)} /><Check label="Coupons apply" checked={f.offers_eligible} onChange={(v) => set('offers_eligible', v)} /></div>
    <div className="row mt"><button className="primary" onClick={save}>{pid === 'new' ? 'Create product' : 'Save changes'}</button><button onClick={onClose}>Close</button></div>
    <h3>Photos</h3>{pid === 'new' ? <p className="muted">Create the product first, then add photos.</p> : <>
      <div className="imgs">{images.map((im, i) => <figure key={im.id}><img src={api.API + im.thumb_url} alt="" />{i === 0 ? <small>Main</small> : null}<button className="danger" style={{ minHeight: 28, padding: '0 8px' }} onClick={async () => { if (await run(() => api.del(`/products/${pid}/images/${im.id}`), 'Photo removed')) setImages((c) => c.filter((x) => x.id !== im.id)); }}>Remove</button></figure>)}</div>
      <input ref={fileRef} type="file" accept="image/jpeg,image/png,image/webp" hidden onChange={(e) => { const file = e.target.files?.[0]; if (file) void addImage(file); e.target.value = ''; }} /><button className="mt" onClick={() => fileRef.current?.click()} disabled={images.length >= 8}>＋ Add photo (min 100×100, up to 8)</button></>}
  </Modal>;
}

export default function Products() {
  const { can } = useAdmin(); const run = useAction();
  const [page, setPage] = useState(1); const [q, setQ] = useState(''); const [cat, setCat] = useState(''); const [status, setStatus] = useState(''); const [edit, setEdit] = useState<string | null>(null); const [stock, setStock] = useState<any>(null); const [del, setDel] = useState<any>(null);
  const dq = useDebounced(q);
  const cats = useLoad(() => api.get('/categories').then((r) => r.categories));
  const { data, error, reload } = useLoad(() => { const p = new URLSearchParams({ page: String(page), limit: '25' }); if (dq) p.set('q', dq); if (cat) p.set('category_id', cat); if (status === 'noimg') p.set('missing_image', 'true'); else if (status) p.set('status', status); return api.get('/products?' + p); }, [page, dq, cat, status]);
  return <>
    <div className="row"><h1>Products</h1>{can('catalog:write') ? <button className="primary right" onClick={() => setEdit('new')}>＋ Add product</button> : null}</div>
    <div className="card"><div className="row"><input style={{ maxWidth: 240 }} placeholder="Search name / SKU / brand" value={q} onChange={(e) => { setQ(e.target.value); setPage(1); }} aria-label="Search" />
      <select style={{ maxWidth: 220 }} value={cat} onChange={(e) => { setCat(e.target.value); setPage(1); }} aria-label="Category"><option value="">All categories</option>{(cats.data ?? []).map((c: any) => <option key={c.id} value={c.id}>{c.parent_id ? '— ' : ''}{c.name}</option>)}</select>
      <select style={{ maxWidth: 170 }} value={status} onChange={(e) => { setStatus(e.target.value); setPage(1); }} aria-label="Status"><option value="">All</option><option value="active">Visible</option><option value="hidden">Hidden</option><option value="low">Low stock</option><option value="out">Out of stock</option><option value="noimg">Missing photo</option></select></div></div>
    {!data ? <Loading error={error} retry={reload} /> : <div className="card" style={{ overflowX: 'auto' }}>{data.items.length ? <table><thead><tr><th></th><th>Product</th><th>Price</th><th>Stock</th><th>Status</th><th></th></tr></thead><tbody>
      {data.items.map((p: any) => <tr key={p.id}><td>{p.thumb_url ? <img className="thumb" src={api.API + p.thumb_url} alt="" /> : <div className="thumb" />}</td>
        <td><b>{p.name}</b>{p.is_sample ? <> <Badge kind="warn">SAMPLE</Badge></> : null}<br /><small className="muted">{p.sku} · {p.category_name}{p.subcategory_name ? ` › ${p.subcategory_name}` : ''}</small></td>
        <td>{inr(p.price)}{Number(p.mrp) > Number(p.price) ? <><br /><small className="muted"><s>{inr(p.mrp)}</s></small></> : null}</td>
        <td><Badge kind={p.available <= 0 ? 'bad' : p.available <= p.low_stock_threshold ? 'warn' : undefined}>{p.available}</Badge>{p.reserved_qty ? <small className="muted"> ({p.reserved_qty} reserved)</small> : null}</td>
        <td>{p.is_active ? 'Visible' : <Badge kind="grey">Hidden</Badge>}</td>
        <td><div className="row">{can('catalog:write') ? <button onClick={() => setEdit(p.id)}>Edit</button> : null}{can('inventory:write') ? <button onClick={() => setStock(p)}>Stock</button> : null}
          {can('catalog:write') ? <button onClick={async () => { await run(() => api.patch(`/products/${p.id}/active`, { is_active: !p.is_active }), p.is_active ? 'Hidden' : 'Visible'); reload(); }}>{p.is_active ? 'Hide' : 'Show'}</button> : null}
          {can('catalog:write') ? <button className="danger" onClick={() => setDel(p)}>Delete</button> : null}</div></td></tr>)}</tbody></table> : <p className="muted">No products found.</p>}
      <Pager page={data.page} limit={data.limit} total={data.total} onPage={setPage} /></div>}
    {edit && cats.data ? <ProductForm id={edit} cats={cats.data} onClose={() => setEdit(null)} onSaved={reload} /> : null}
    {stock ? <StockModal p={stock} onClose={() => setStock(null)} onDone={reload} /> : null}
    {del ? <Confirm danger title="Delete product?" text={`Delete "${del.name}" permanently? Products with past orders cannot be deleted — hide them instead.`} confirmLabel="Delete" onConfirm={async () => { await run(() => api.del(`/products/${del.id}`), 'Deleted'); reload(); }} onClose={() => setDel(null)} /> : null}</>;
}
