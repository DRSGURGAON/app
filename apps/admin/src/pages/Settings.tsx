import { useState } from 'react';
import * as api from '../api';
import { useAdmin } from '../App';
import { Check, Field, Loading, Num, useAction, useLoad } from '../ui';

export type Fld = { k: string; label: string; type: 'text' | 'num' | 'bool' | 'select' | 'textarea' | 'time'; hint?: string; opts?: [string, string][]; step?: number; nullable?: boolean; int?: boolean };

export const SPECS: Record<string, { title: string; perm: string; fields: Fld[]; note?: string }> = {
  store: { title: 'Store details & hours', perm: 'settings:write', fields: [
    { k: 'name_en', label: 'Store name (English)', type: 'text' }, { k: 'name_hi', label: 'Store name (Hindi)', type: 'text' }, { k: 'tagline', label: 'Tagline', type: 'text' }, { k: 'phone', label: 'Phone', type: 'text' },
    { k: 'address_en', label: 'Address (English)', type: 'text' }, { k: 'address_hi', label: 'Address (Hindi)', type: 'text' }, { k: 'pincode', label: 'PIN code', type: 'text' },
    { k: 'latitude', label: 'Store latitude', type: 'num', step: 0.000001, nullable: true, hint: 'Needed for distance-based delivery fees. Right-click the shop on Google Maps to copy it.' }, { k: 'longitude', label: 'Store longitude', type: 'num', step: 0.000001, nullable: true },
    { k: 'open_time', label: 'Opens', type: 'time' }, { k: 'close_time', label: 'Closes', type: 'time' }, { k: 'enforce_hours', label: 'Only accept orders during opening hours', type: 'bool' },
    { k: 'temporarily_closed', label: 'Temporarily closed (stops all new orders)', type: 'bool' }, { k: 'closed_message', label: 'Message shown when closed', type: 'text' },
    { k: 'delivery_enabled', label: 'Home delivery available', type: 'bool' }, { k: 'pickup_enabled', label: 'Store pickup available', type: 'bool' }, { k: 'pickup_instructions', label: 'Pickup instructions', type: 'text' } ] },
  delivery: { title: 'Delivery fee rules', perm: 'delivery:write', note: 'Rule: distance up to the near radius pays the base fee. Beyond it, customers pay one flat far fee (₹70 by default) — not per km, not added to the base fee. Pickup is always free.', fields: [
    { k: 'near_radius_km', label: 'Near radius (km)', type: 'num', step: 0.1 }, { k: 'base_fee', label: 'Base fee within radius (₹)', type: 'num', step: 1, hint: 'Set the real value for your shop. The starting value is only a placeholder.' }, { k: 'far_fee', label: 'Flat fee beyond radius (₹, total)', type: 'num', step: 1 },
    { k: 'max_radius_km', label: 'Maximum delivery distance (km, 0 = no limit)', type: 'num', step: 1 }, { k: 'zone_mode', label: 'Fee method', type: 'select', opts: [['radius', 'Distance (radius)'], ['zones', 'Zones only']] }, { k: 'zone_overrides_enabled', label: 'Let zones override the distance fee', type: 'bool' },
    { k: 'fallback_mode', label: 'If distance cannot be calculated', type: 'select', opts: [['ask_zone', 'Ask the customer to choose a delivery area (recommended)'], ['straight_line', 'Use straight-line distance (explicit estimate)'], ['block', 'Block delivery']] }, { k: 'straight_line_factor', label: 'Straight-line multiplier (road ≈ 1.3× straight)', type: 'num', step: 0.05 } ] },
  order: { title: 'Order rules', perm: 'settings:write', fields: [
    { k: 'min_order', label: 'Minimum order (₹, before delivery fee)', type: 'num', step: 1 }, { k: 'min_applies_to_pickup', label: 'Minimum applies to pickup too', type: 'bool' }, { k: 'min_after_coupon', label: 'Measure minimum after coupon discount', type: 'bool' }, { k: 'min_after_coins', label: 'Measure minimum after coin discount', type: 'bool' },
    { k: 'cod_enabled', label: 'Cash on delivery / pay at store', type: 'bool' }, { k: 'online_enabled', label: 'Online payment (UPI / card)', type: 'bool' }, { k: 'max_lines', label: 'Max different items per order', type: 'num', int: true }, { k: 'payment_window_minutes', label: 'Minutes to complete online payment', type: 'num', int: true } ] },
  coins: { title: 'Coins wallet', perm: 'offers:write', fields: [
    { k: 'enabled', label: 'Coins enabled', type: 'bool' }, { k: 'earn_coins_per_unit', label: 'Coins earned per spend unit', type: 'num', int: true }, { k: 'earn_spend_unit', label: 'Spend unit (₹)', type: 'num', int: true, hint: 'e.g. 1 coin for every ₹100' }, { k: 'coin_value', label: 'Value of 1 coin (₹)', type: 'num', step: 0.1 },
    { k: 'max_redeem_coins_per_order', label: 'Max coins usable per order', type: 'num', int: true }, { k: 'min_order_to_earn', label: 'Min order to earn (₹)', type: 'num' }, { k: 'min_order_to_redeem', label: 'Min order to redeem (₹)', type: 'num' },
    { k: 'earn_on_discounted_orders', label: 'Earn coins on orders using coupon / first-order discount', type: 'bool' }, { k: 'expiry_days', label: 'Coins expire after (days, 0 = never)', type: 'num', int: true } ] },
  first_order: { title: 'First-order discount', perm: 'offers:write', fields: [
    { k: 'enabled', label: 'Enabled', type: 'bool' }, { k: 'type', label: 'Type', type: 'select', opts: [['percent', 'Percent'], ['fixed', 'Fixed ₹']] }, { k: 'value', label: 'Value', type: 'num', step: 0.5 }, { k: 'min_spend', label: 'Min spend (₹)', type: 'num' }, { k: 'max_discount', label: 'Max discount (₹, blank = none)', type: 'num', nullable: true } ] },
  notifications: { title: 'Notifications', perm: 'settings:write', fields: [{ k: 'order_updates', label: 'Order status notifications', type: 'bool' }, { k: 'promotions', label: 'Promotional notifications (only to customers who opted in)', type: 'bool' }] },
};

export function SettingsForm({ name, settings, onSaved }: { name: string; settings: any; onSaved: (all: any) => void }) {
  const { can } = useAdmin(); const run = useAction(); const spec = SPECS[name]; const [f, setF] = useState<any>({ ...settings[name] }); const [dirty, setDirty] = useState(false);
  const set = (k: string, v: any) => { setF((c: any) => ({ ...c, [k]: v })); setDirty(true); };
  const editable = can(spec.perm);
  return <div className="card"><h2>{spec.title}</h2>{spec.note ? <p className="muted">{spec.note}</p> : null}
    <fieldset disabled={!editable} style={{ border: 0, padding: 0, margin: 0 }}><div className="grid g2">{spec.fields.map((x) => x.type === 'bool'
      ? <Check key={x.k} label={x.label} checked={!!f[x.k]} onChange={(v) => set(x.k, v)} />
      : <Field key={x.k} label={x.label} hint={x.hint}>{x.type === 'num' ? <Num nullable={x.nullable} value={f[x.k]} step={x.step ?? 1} onChange={(v) => set(x.k, v)} />
        : x.type === 'select' ? <select value={f[x.k]} onChange={(e) => set(x.k, e.target.value)}>{x.opts!.map(([v, l]) => <option key={v} value={v}>{l}</option>)}</select>
        : x.type === 'time' ? <input type="time" value={f[x.k]} onChange={(e) => set(x.k, e.target.value)} /> : <input value={f[x.k] ?? ''} onChange={(e) => set(x.k, e.target.value)} />}</Field>)}</div></fieldset>
    {editable ? <button className="primary mt" disabled={!dirty} onClick={async () => { const r = await run(() => api.put(`/settings/${name}`, f), 'Saved'); if (r) { setDirty(false); onSaved(r.settings); } }}>Save</button> : <p className="muted">View only — your role cannot change this.</p>}</div>;
}

const POLICIES: [string, string][] = [['privacy', 'Privacy policy'], ['terms', 'Terms & conditions'], ['delivery', 'Delivery policy'], ['cancellation', 'Cancellation policy'], ['refund', 'Refund policy']];
function PolicyEditor({ settings, onSaved }: { settings: any; onSaved: (all: any) => void }) {
  const { can } = useAdmin(); const run = useAction(); const [f, setF] = useState<any>(JSON.parse(JSON.stringify(settings.policies))); const [k, setK] = useState('privacy'); const [dirty, setDirty] = useState(false);
  const set = (lang: 'en' | 'hi', v: string) => { setF((c: any) => ({ ...c, [k]: { ...c[k], [lang]: v } })); setDirty(true); };
  return <div className="card"><h2>Policies shown in the app</h2><p className="muted">These are starter drafts. Have them reviewed for your business (and by a lawyer for Terms / Privacy) before you publish the app.</p>
    <div className="tabs">{POLICIES.map(([id, l]) => <button key={id} className={k === id ? 'tab active' : 'tab'} onClick={() => setK(id)}>{l}</button>)}</div>
    <Field label="English"><textarea style={{ minHeight: 160 }} value={f[k].en} onChange={(e) => set('en', e.target.value)} disabled={!can('settings:write')} /></Field><Field label="हिन्दी"><textarea style={{ minHeight: 160 }} value={f[k].hi} onChange={(e) => set('hi', e.target.value)} disabled={!can('settings:write')} /></Field>
    {can('settings:write') ? <button className="primary" disabled={!dirty} onClick={async () => { const r = await run(() => api.put('/settings/policies', f), 'Policies saved'); if (r) { setDirty(false); onSaved(r.settings); } }}>Save all policies</button> : null}</div>;
}

export function useSettings() { const l = useLoad(() => api.get('/settings').then((r) => r.settings)); return l; }

export function SettingsPage() {
  const { data, error, reload, setData } = useSettings();
  if (!data) return <Loading error={error} retry={reload} />;
  return <><h1>Store & policies</h1>
    <SettingsForm name="store" settings={data} onSaved={setData} /><SettingsForm name="order" settings={data} onSaved={setData} /><SettingsForm name="notifications" settings={data} onSaved={setData} /><PolicyEditor settings={data} onSaved={setData} /></>;
}
