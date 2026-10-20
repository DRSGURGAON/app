import { useRef, useState } from 'react';
import * as api from '../api';
import { dt, inr } from '../api';
import { useAdmin } from '../App';
import { Badge, Check, Confirm, Field, Loading, Modal, Num, Pager, useAction, useLoad } from '../ui';

const toLocal = (v?: string | null) => { if (!v) return ''; const d = new Date(v); const p = (n: number) => String(n).padStart(2, '0'); return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}`; };
const iso = (v: string) => (v ? new Date(v).toISOString() : null);

function CouponForm({ c, onClose, onSaved }: { c: any; onClose: () => void; onSaved: () => void }) {
  const run = useAction(); const now = new Date(); const later = new Date(Date.now() + 30 * 864e5);
  const [f, setF] = useState<any>({ code: '', title: '', description: '', discount_type: 'percent', discount_value: '5', min_spend: '999', max_discount: '', usage_limit: null, per_user_limit: 1, first_order_only: false, festival: '', is_public: false, is_active: true, ...c, starts_at: toLocal(c.starts_at ?? now.toISOString()), ends_at: toLocal(c.ends_at ?? later.toISOString()), max_discount_: undefined });
  const set = (k: string, v: any) => setF((x: any) => ({ ...x, [k]: v }));
  const save = async () => {
    const body = { code: f.code, title: f.title, description: f.description || null, discount_type: f.discount_type, discount_value: String(f.discount_value), min_spend: String(f.min_spend || 0), max_discount: f.max_discount === '' || f.max_discount == null ? null : String(f.max_discount),
      starts_at: iso(f.starts_at), ends_at: iso(f.ends_at), usage_limit: f.usage_limit, per_user_limit: f.per_user_limit, category_ids: c.category_ids ?? [], product_ids: c.product_ids ?? [], first_order_only: f.first_order_only, festival: f.festival || null, is_public: f.is_public, is_active: f.is_active };
    const r = await run(() => (c.id ? api.put(`/coupons/${c.id}`, body) : api.post('/coupons', body)), 'Coupon saved'); if (r) { onSaved(); onClose(); }
  };
  return <Modal title={c.id ? `Edit ${c.code}` : 'New coupon'} onClose={onClose}>
    <div className="row"><div className="grow"><Field label="Code *"><input value={f.code} onChange={(e) => set('code', e.target.value.toUpperCase())} /></Field></div><div className="grow"><Field label="Title shown to customers *"><input value={f.title} onChange={(e) => set('title', e.target.value)} /></Field></div></div>
    <div className="row"><div className="grow"><Field label="Type"><select value={f.discount_type} onChange={(e) => set('discount_type', e.target.value)}><option value="percent">Percent off</option><option value="fixed">Fixed ₹ off</option></select></Field></div>
      <div className="grow"><Field label={f.discount_type === 'percent' ? 'Percent *' : 'Amount ₹ *'}><input inputMode="decimal" value={f.discount_value} onChange={(e) => set('discount_value', e.target.value)} /></Field></div>
      <div className="grow"><Field label="Min. spend ₹"><input inputMode="decimal" value={f.min_spend} onChange={(e) => set('min_spend', e.target.value)} /></Field></div><div className="grow"><Field label="Max discount ₹ (optional)"><input inputMode="decimal" value={f.max_discount ?? ''} onChange={(e) => set('max_discount', e.target.value)} /></Field></div></div>
    <div className="row"><div className="grow"><Field label="Starts"><input type="datetime-local" value={f.starts_at} onChange={(e) => set('starts_at', e.target.value)} /></Field></div><div className="grow"><Field label="Ends"><input type="datetime-local" value={f.ends_at} onChange={(e) => set('ends_at', e.target.value)} /></Field></div></div>
    <div className="row"><div className="grow"><Field label="Total uses allowed (blank = unlimited)"><Num nullable value={f.usage_limit} onChange={(v) => set('usage_limit', v)} min={1} /></Field></div><div className="grow"><Field label="Uses per customer"><Num value={f.per_user_limit} onChange={(v) => set('per_user_limit', v)} min={1} /></Field></div><div className="grow"><Field label="Festival tag"><input value={f.festival ?? ''} onChange={(e) => set('festival', e.target.value)} placeholder="e.g. Diwali" /></Field></div></div>
    <Field label="Description"><textarea value={f.description ?? ''} onChange={(e) => set('description', e.target.value)} /></Field>
    <div className="row"><Check label="First order only" checked={f.first_order_only} onChange={(v) => set('first_order_only', v)} /><Check label="Show in app's coupon list" checked={f.is_public} onChange={(v) => set('is_public', v)} /><Check label="Active" checked={f.is_active} onChange={(v) => set('is_active', v)} /></div>
    <div className="row mt"><button className="primary" onClick={save}>Save coupon</button><button onClick={onClose}>Cancel</button></div></Modal>;
}

export function Coupons() {
  const { can } = useAdmin(); const run = useAction(); const [page, setPage] = useState(1); const [edit, setEdit] = useState<any>(null); const [del, setDel] = useState<any>(null);
  const { data, error, reload } = useLoad(() => api.get(`/coupons?page=${page}&limit=25`), [page]);
  return <><div className="row"><h1>Coupons</h1>{can('offers:write') ? <button className="primary right" onClick={() => setEdit({})}>＋ New coupon</button> : null}</div>
    {!data ? <Loading error={error} retry={reload} /> : <div className="card" style={{ overflowX: 'auto' }}><table><thead><tr><th>Code</th><th>Offer</th><th>Valid</th><th>Used</th><th>Status</th><th></th></tr></thead><tbody>
      {data.items.map((c: any) => <tr key={c.id}><td><b>{c.code}</b><br /><small className="muted">{c.title}</small></td><td>{c.discount_type === 'percent' ? `${Number(c.discount_value)}%` : inr(c.discount_value)} off{Number(c.min_spend) ? <><br /><small className="muted">min {inr(c.min_spend)}{c.max_discount ? `, max ${inr(c.max_discount)}` : ''}</small></> : null}{c.first_order_only ? <><br /><Badge kind="warn">first order</Badge></> : null}</td>
        <td><small>{dt(c.starts_at)} →<br />{dt(c.ends_at)}</small></td><td>{c.used_count}{c.usage_limit ? ` / ${c.usage_limit}` : ''}</td><td>{c.live ? <Badge>Live</Badge> : <Badge kind="grey">{c.is_active ? 'Not live' : 'Disabled'}</Badge>}</td>
        <td>{can('offers:write') ? <div className="row"><button onClick={() => setEdit(c)}>Edit</button><button onClick={async () => { await run(() => api.patch(`/coupons/${c.id}/active`, { is_active: !c.is_active }), c.is_active ? 'Disabled' : 'Enabled'); reload(); }}>{c.is_active ? 'Disable' : 'Enable'}</button><button className="danger" onClick={() => setDel(c)}>Delete</button></div> : null}</td></tr>)}</tbody></table>
      {!data.items.length ? <p className="muted">No coupons yet.</p> : null}<Pager page={data.page} limit={data.limit} total={data.total} onPage={setPage} /></div>}
    {edit ? <CouponForm c={edit} onClose={() => setEdit(null)} onSaved={reload} /> : null}
    {del ? <Confirm danger title="Delete coupon?" text={`Delete ${del.code}? A coupon that has been used cannot be deleted — disable it instead.`} confirmLabel="Delete" onConfirm={async () => { await run(() => api.del(`/coupons/${del.id}`), 'Deleted'); reload(); }} onClose={() => setDel(null)} /> : null}</>;
}

function BannerForm({ b, onClose, onSaved }: { b: any; onClose: () => void; onSaved: () => void }) {
  const run = useAction(); const fileRef = useRef<HTMLInputElement>(null);
  const [f, setF] = useState<any>({ title: '', subtitle: '', festival: '', terms: '', link_type: 'none', link_ref: '', sort_order: 0, is_active: true, ...b, starts_at: toLocal(b.starts_at), ends_at: toLocal(b.ends_at) }); const set = (k: string, v: any) => setF((x: any) => ({ ...x, [k]: v }));
  const save = async () => { const body = { title: f.title, subtitle: f.subtitle || null, festival: f.festival || null, terms: f.terms || null, link_type: f.link_type, link_ref: f.link_type === 'none' ? null : f.link_ref, starts_at: iso(f.starts_at), ends_at: iso(f.ends_at), sort_order: Number(f.sort_order) || 0, is_active: f.is_active }; const r = await run(() => (b.id ? api.put(`/banners/${b.id}`, body) : api.post('/banners', body)), 'Banner saved'); if (r) { onSaved(); if (b.id) onClose(); else onClose(); } };
  return <Modal title={b.id ? 'Edit banner' : 'New banner'} onClose={onClose}>
    <Field label="Title *"><input value={f.title} onChange={(e) => set('title', e.target.value)} /></Field><Field label="Subtitle"><input value={f.subtitle ?? ''} onChange={(e) => set('subtitle', e.target.value)} /></Field>
    <div className="row"><div className="grow"><Field label="Festival tag"><input value={f.festival ?? ''} onChange={(e) => set('festival', e.target.value)} /></Field></div><div className="grow"><Field label="Sort order"><Num value={f.sort_order} onChange={(v) => set('sort_order', v)} min={0} /></Field></div></div>
    <div className="row"><div className="grow"><Field label="Opens"><select value={f.link_type} onChange={(e) => set('link_type', e.target.value)}><option value="none">Nothing</option><option value="category">A category (slug)</option><option value="product">A product (id)</option><option value="coupon">A coupon (code)</option></select></Field></div>
      {f.link_type !== 'none' ? <div className="grow"><Field label="Reference"><input value={f.link_ref ?? ''} onChange={(e) => set('link_ref', e.target.value)} /></Field></div> : null}</div>
    <div className="row"><div className="grow"><Field label="Show from"><input type="datetime-local" value={f.starts_at} onChange={(e) => set('starts_at', e.target.value)} /></Field></div><div className="grow"><Field label="Show until"><input type="datetime-local" value={f.ends_at} onChange={(e) => set('ends_at', e.target.value)} /></Field></div></div>
    <Field label="Terms (shown to customers)"><textarea value={f.terms ?? ''} onChange={(e) => set('terms', e.target.value)} /></Field><Check label="Active" checked={f.is_active} onChange={(v) => set('is_active', v)} />
    {b.id ? <div className="row">{b.image_url ? <img className="thumb" style={{ width: 120 }} src={api.API + b.image_url} alt="" /> : null}<input ref={fileRef} type="file" accept="image/jpeg,image/png,image/webp" hidden onChange={async (e) => { const file = e.target.files?.[0]; if (file && (await run(() => api.upload(`/banners/${b.id}/image`, file), 'Image updated'))) onSaved(); e.target.value = ''; }} /><button onClick={() => fileRef.current?.click()}>Upload banner image</button></div> : <p className="muted">Save first, then upload the image.</p>}
    <div className="row mt"><button className="primary" onClick={save}>Save banner</button><button onClick={onClose}>Close</button></div></Modal>;
}

export function Banners() {
  const { can } = useAdmin(); const run = useAction(); const { data, error, reload } = useLoad(() => api.get('/banners').then((r) => r.banners)); const [edit, setEdit] = useState<any>(null); const [del, setDel] = useState<any>(null);
  return <><div className="row"><h1>Banners & festival offers</h1>{can('offers:write') ? <button className="primary right" onClick={() => setEdit({})}>＋ New banner</button> : null}</div>
    {!data ? <Loading error={error} retry={reload} /> : <div className="card" style={{ overflowX: 'auto' }}><table><thead><tr><th></th><th>Banner</th><th>Schedule</th><th>Status</th><th></th></tr></thead><tbody>
      {data.map((b: any) => <tr key={b.id}><td>{b.image_url ? <img className="thumb" style={{ width: 90 }} src={api.API + b.image_url} alt="" /> : <div className="thumb" style={{ width: 90 }} />}</td><td><b>{b.title}</b>{b.festival ? <> <Badge kind="warn">{b.festival}</Badge></> : null}<br /><small className="muted">{b.subtitle}</small></td><td><small>{b.starts_at ? dt(b.starts_at) : 'Always'} → {b.ends_at ? dt(b.ends_at) : 'no end'}</small></td><td>{b.is_active ? 'Active' : <Badge kind="grey">Off</Badge>}</td>
        <td>{can('offers:write') ? <div className="row"><button onClick={() => setEdit(b)}>Edit</button><button className="danger" onClick={() => setDel(b)}>Delete</button></div> : null}</td></tr>)}</tbody></table>{!data.length ? <p className="muted">No banners.</p> : null}</div>}
    {edit ? <BannerForm b={edit} onClose={() => setEdit(null)} onSaved={reload} /> : null}
    {del ? <Confirm danger title="Delete banner?" text={`Delete "${del.title}"?`} confirmLabel="Delete" onConfirm={async () => { await run(() => api.del(`/banners/${del.id}`), 'Deleted'); reload(); }} onClose={() => setDel(null)} /> : null}</>;
}
