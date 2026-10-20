import { useState } from 'react';
import * as api from '../api';
import { inr } from '../api';
import { Badge, Check, Confirm, Field, Loading, Modal, Num, useAction, useLoad } from '../ui';
import { SettingsForm, useSettings } from './Settings';

function ZoneForm({ z, onClose, onSaved }: { z: any; onClose: () => void; onSaved: () => void }) {
  const run = useAction(); const [f, setF] = useState<any>({ name: '', name_hi: '', pincodes: [], fee_mode: 'base', custom_fee: null, min_order: null, sort_order: 0, is_active: true, ...z }); const [pins, setPins] = useState((z.pincodes ?? []).join(', '));
  const set = (k: string, v: any) => setF((c: any) => ({ ...c, [k]: v }));
  const save = async () => { const body = { name: f.name, name_hi: f.name_hi || null, pincodes: pins.split(/[\s,]+/).filter(Boolean), fee_mode: f.fee_mode, custom_fee: f.fee_mode === 'custom' ? Number(f.custom_fee) : null, min_order: f.min_order === null || f.min_order === '' ? null : Number(f.min_order), sort_order: Number(f.sort_order) || 0, is_active: f.is_active }; const r = await run(() => (z.id ? api.put(`/zones/${z.id}`, body) : api.post('/zones', body)), 'Zone saved'); if (r) { onSaved(); onClose(); } };
  return <Modal title={z.id ? 'Edit zone' : 'New delivery zone'} onClose={onClose} small>
    <Field label="Zone name *"><input value={f.name} onChange={(e) => set('name', e.target.value)} /></Field><Field label="Name (Hindi)"><input value={f.name_hi ?? ''} onChange={(e) => set('name_hi', e.target.value)} /></Field>
    <Field label="PIN codes (comma separated)"><input value={pins} onChange={(e) => setPins(e.target.value)} placeholder="127308, 127309" /></Field>
    <Field label="Delivery fee"><select value={f.fee_mode} onChange={(e) => set('fee_mode', e.target.value)}><option value="base">Base fee</option><option value="far">Far flat fee</option><option value="custom">Custom amount</option></select></Field>
    {f.fee_mode === 'custom' ? <Field label="Custom fee ₹"><Num value={f.custom_fee} onChange={(v) => set('custom_fee', v)} min={0} /></Field> : null}
    <Field label="Zone minimum order ₹ (blank = store default)"><Num nullable value={f.min_order} onChange={(v) => set('min_order', v)} min={0} /></Field><Check label="Active" checked={f.is_active} onChange={(v) => set('is_active', v)} />
    <div className="row"><button className="primary" onClick={save}>Save</button><button onClick={onClose}>Cancel</button></div></Modal>;
}

function Preview({ zones }: { zones: any[] }) {
  const run = useAction(); const [f, setF] = useState<any>({ fulfilment: 'delivery', distance_km: '', pincode: '', zone_id: '', latitude: '', longitude: '' }); const [res, setRes] = useState<any>(null);
  const go = async () => { const b: any = { fulfilment: f.fulfilment }; if (f.distance_km !== '') b.distance_km = Number(f.distance_km); if (f.pincode) b.pincode = f.pincode; if (f.zone_id) b.zone_id = f.zone_id; if (f.latitude !== '' && f.longitude !== '') { b.latitude = Number(f.latitude); b.longitude = Number(f.longitude); } const r = await run(() => api.post('/delivery/preview', b)); if (r) setRes(r); };
  const set = (k: string, v: any) => setF((c: any) => ({ ...c, [k]: v }));
  return <div className="card"><h2>Fee preview</h2><p className="muted">Try a distance, PIN code, zone or coordinates to see exactly what a customer would be charged with the saved rules.</p>
    <div className="row"><div className="grow"><Field label="Type"><select value={f.fulfilment} onChange={(e) => set('fulfilment', e.target.value)}><option value="delivery">Delivery</option><option value="pickup">Pickup</option></select></Field></div><div className="grow"><Field label="Distance (km)"><input inputMode="decimal" value={f.distance_km} onChange={(e) => set('distance_km', e.target.value)} placeholder="e.g. 1.8 or 2.4" /></Field></div>
      <div className="grow"><Field label="PIN code"><input value={f.pincode} onChange={(e) => set('pincode', e.target.value)} /></Field></div><div className="grow"><Field label="Zone"><select value={f.zone_id} onChange={(e) => set('zone_id', e.target.value)}><option value="">—</option>{zones.map((z) => <option key={z.id} value={z.id}>{z.name}</option>)}</select></Field></div></div>
    <div className="row"><div className="grow"><Field label="Latitude"><input value={f.latitude} onChange={(e) => set('latitude', e.target.value)} /></Field></div><div className="grow"><Field label="Longitude"><input value={f.longitude} onChange={(e) => set('longitude', e.target.value)} /></Field></div></div>
    <button className="primary" onClick={go}>Calculate</button>
    {res ? <div className="card mt" style={{ background: '#fafbf8' }}>{res.ok ? <><p style={{ fontSize: 22, margin: 0 }}><b>{Number(res.fee) === 0 ? 'Free' : inr(res.fee)}</b></p><p className="muted">Rule: {res.rule} · Distance: {res.distance_km ?? 'n/a'} km ({res.method}){res.zone ? ` · Zone: ${typeof res.zone === 'string' ? res.zone : res.zone.name}` : ''}</p></> : <p className="err">{res.error.message}</p>}{res.distance_note ? <p className="muted">{res.distance_note}</p> : null}</div> : null}</div>;
}

export default function Delivery() {
  const s = useSettings(); const run = useAction(); const zones = useLoad(() => api.get('/zones').then((r) => r.zones)); const [edit, setEdit] = useState<any>(null); const [del, setDel] = useState<any>(null);
  if (!s.data) return <Loading error={s.error} retry={s.reload} />;
  const noCoords = s.data.store.latitude == null || s.data.store.longitude == null;
  return <><h1>Delivery</h1>
    {noCoords ? <div className="card" style={{ background: 'var(--amber-s)' }}><b>Store location not set.</b> Distance-based fees can't be calculated until you enter the shop's latitude and longitude in <a href="#/settings">Store & policies</a>. Until then customers are asked to choose a delivery area (zone).</div> : null}
    <SettingsForm name="delivery" settings={s.data} onSaved={s.setData} />
    <div className="card"><div className="row"><h2 style={{ margin: 0 }}>Delivery zones</h2><button className="primary right" onClick={() => setEdit({})}>＋ Add zone</button></div>
      {zones.data ? <table><thead><tr><th>Zone</th><th>PIN codes</th><th>Fee</th><th>Status</th><th></th></tr></thead><tbody>{zones.data.map((z: any) => <tr key={z.id}><td>{z.name}</td><td>{(z.pincodes ?? []).join(', ') || '—'}</td><td>{z.fee_mode === 'custom' ? inr(z.custom_fee) : z.fee_mode === 'far' ? 'Far flat fee' : 'Base fee'}</td><td>{z.is_active ? 'Active' : <Badge kind="grey">Off</Badge>}</td><td><div className="row"><button onClick={() => setEdit(z)}>Edit</button><button className="danger" onClick={() => setDel(z)}>Delete</button></div></td></tr>)}</tbody></table> : <Loading />}</div>
    {zones.data ? <Preview zones={zones.data} /> : null}
    {edit ? <ZoneForm z={edit} onClose={() => setEdit(null)} onSaved={zones.reload} /> : null}
    {del ? <Confirm danger title="Delete zone?" text={`Delete "${del.name}"?`} confirmLabel="Delete" onConfirm={async () => { await run(() => api.del(`/zones/${del.id}`), 'Deleted'); zones.reload(); }} onClose={() => setDel(null)} /> : null}</>;
}
