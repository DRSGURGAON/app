import { useState } from 'react';
import * as api from '../api';
import { dt, inr } from '../api';
import { useAdmin } from '../App';
import { Badge, Check, Confirm, Field, Loading, Modal, Num, Pager, useAction, useDebounced, useLoad } from '../ui';
import { SettingsForm, useSettings } from './Settings';

export function Coins() {
  const s = useSettings(); const ov = useLoad(() => api.get('/coins/overview'));
  if (!s.data) return <Loading error={s.error} retry={s.reload} />;
  return <><h1>Coins & first-order offer</h1>
    {ov.data ? <div className="grid g2" style={{ gridTemplateColumns: 'repeat(auto-fit,minmax(150px,1fr))' }}>{[['Earned (all time)', ov.data.earned], ['Redeemed', ov.data.redeemed], ['Expired', ov.data.expired], ['Outstanding balance', ov.data.outstanding]].map(([l, v]) => <div className="stat" key={String(l)}><b>🪙 {v}</b><span>{l}</span></div>)}</div> : null}
    <div className="mt"><SettingsForm name="coins" settings={s.data} onSaved={s.setData} /><SettingsForm name="first_order" settings={s.data} onSaved={s.setData} /></div>
    <p className="muted">To adjust one customer's coins, open them in Customers.</p></>;
}

function Wallet({ c, onClose }: { c: any; onClose: () => void }) {
  const { can } = useAdmin(); const run = useAction(); const [n, setN] = useState(0); const [reason, setReason] = useState('');
  const { data, reload } = useLoad(() => api.get(`/customers/${c.id}/wallet`), [c.id]);
  return <Modal title={`Wallet · ${c.name || c.phone}`} onClose={onClose}>{data ? <><p>Balance <b>🪙 {data.wallet.balance}</b></p>
    {can('coins:write') ? <div className="card"><h3 style={{ marginTop: 0 }}>Manual adjustment</h3><div className="row"><div className="grow"><Field label="Coins (+ add / − remove)"><Num value={n} onChange={setN} /></Field></div><div className="grow"><Field label="Reason *"><input value={reason} onChange={(e) => setReason(e.target.value)} /></Field></div></div>
      <button className="primary" onClick={async () => { if (await run(() => api.post(`/customers/${c.id}/coins`, { coins: n, reason }), 'Wallet updated')) { setN(0); setReason(''); reload(); } }}>Apply</button></div> : null}
    <table><thead><tr><th>When</th><th>Type</th><th>Coins</th><th>Note</th></tr></thead><tbody>{(data.transactions.items ?? data.transactions).map((t: any) => <tr key={t.id}><td>{dt(t.created_at)}</td><td>{t.type}</td><td>{t.coins > 0 ? '+' : ''}{t.coins}</td><td>{t.note ?? ''}</td></tr>)}</tbody></table></> : <Loading />}</Modal>;
}

export function Customers() {
  const { can } = useAdmin(); const run = useAction(); const [page, setPage] = useState(1); const [q, setQ] = useState(''); const [del, setDel] = useState(false); const [wallet, setWallet] = useState<any>(null); const [block, setBlock] = useState<any>(null); const [reason, setReason] = useState(''); const [proc, setProc] = useState<any>(null); const dq = useDebounced(q);
  const { data, error, reload } = useLoad(() => { const p = new URLSearchParams({ page: String(page), limit: '25' }); if (dq) p.set('q', dq); if (del) p.set('deletion', 'true'); return api.get('/customers?' + p); }, [page, dq, del]);
  return <><h1>Customers</h1><div className="card"><div className="row"><input style={{ maxWidth: 260 }} placeholder="Search phone / name" value={q} onChange={(e) => { setQ(e.target.value); setPage(1); }} aria-label="Search" /><Check label="Only deletion requests" checked={del} onChange={(v) => { setDel(v); setPage(1); }} /></div></div>
    {!data ? <Loading error={error} retry={reload} /> : <div className="card" style={{ overflowX: 'auto' }}><table><thead><tr><th>Customer</th><th>Orders</th><th>Spent</th><th>Coins</th><th>Status</th><th></th></tr></thead><tbody>
      {data.items.map((c: any) => <tr key={c.id}><td><b>{c.name || '—'}</b><br /><small className="muted">{c.phone} · joined {dt(c.created_at)}</small></td><td>{c.orders}</td><td>{inr(c.spent)}</td><td>🪙 {c.coins}</td><td>{c.status === 'blocked' ? <Badge kind="bad">Blocked</Badge> : 'Active'}{c.deletion_requested_at ? <><br /><Badge kind="warn">Deletion requested</Badge></> : null}</td>
        <td><div className="row"><button onClick={() => setWallet(c)}>Wallet</button>{can('customers:write') ? <button onClick={() => { setBlock(c); setReason(''); }}>{c.status === 'blocked' ? 'Unblock' : 'Block'}</button> : null}{can('customers:write') && c.deletion_requested_at ? <button className="danger" onClick={() => setProc(c)}>Process deletion</button> : null}</div></td></tr>)}</tbody></table>
      {!data.items.length ? <p className="muted">No customers.</p> : null}<Pager page={data.page} limit={data.limit} total={data.total} onPage={setPage} /></div>}
    {wallet ? <Wallet c={wallet} onClose={() => setWallet(null)} /> : null}
    {block ? <Modal title={block.status === 'blocked' ? 'Unblock customer' : 'Block customer'} onClose={() => setBlock(null)} small><Field label="Reason *"><input value={reason} onChange={(e) => setReason(e.target.value)} /></Field><div className="row"><button className="primary" onClick={async () => { if (await run(() => api.post(`/customers/${block.id}/block`, { blocked: block.status !== 'blocked', reason }), 'Updated')) { setBlock(null); reload(); } }}>Confirm</button><button onClick={() => setBlock(null)}>Cancel</button></div></Modal> : null}
    {proc ? <Confirm danger title="Process account deletion?" text={`Remove ${proc.phone}'s personal data (name, phone, addresses, devices). Order records are kept for accounting. This cannot be undone.`} confirmLabel="Delete personal data" onConfirm={async () => { await run(() => api.post(`/customers/${proc.id}/delete`), 'Customer data deleted'); reload(); }} onClose={() => setProc(null)} /> : null}</>;
}

const PERMS = ['catalog:read', 'catalog:write', 'inventory:read', 'inventory:write', 'orders:read', 'orders:write', 'refunds:write', 'offers:write', 'coins:write', 'delivery:write', 'settings:write', 'staff:write', 'customers:read', 'customers:write', 'reports:read', 'audit:read', 'imports:write'];
export function Staff() {
  const run = useAction(); const { data, error, reload } = useLoad(() => api.get('/staff').then((r) => r.staff)); const [edit, setEdit] = useState<any>(null);
  const [f, setF] = useState<any>({}); const open = (s: any) => { setF({ email: '', name: '', role: 'staff', status: 'active', extra_permissions: [], password: '', ...s, password_: '' }); setEdit(s); };
  const save = async () => { const body: any = { email: f.email, name: f.name, role: f.role, status: f.status, extra_permissions: f.extra_permissions }; if (f.password) body.password = f.password; const r = await run(() => (edit.id ? api.put(`/staff/${edit.id}`, body) : api.post('/staff', body)), 'Saved'); if (r) { setEdit(null); reload(); } };
  return <><div className="row"><h1>Staff</h1><button className="primary right" onClick={() => open({})}>＋ Add staff</button></div>
    <p className="muted">Owner: everything. Manager: day-to-day operations. Staff: orders and stock. You can grant a person extra permissions below.</p>
    {!data ? <Loading error={error} retry={reload} /> : <div className="card" style={{ overflowX: 'auto' }}><table><thead><tr><th>Name</th><th>Role</th><th>Status</th><th>Last login</th><th></th></tr></thead><tbody>{data.map((s: any) => <tr key={s.id}><td><b>{s.name}</b><br /><small className="muted">{s.email}</small></td><td>{s.role}{s.extra_permissions.length ? <small className="muted"> +{s.extra_permissions.length}</small> : null}</td><td>{s.status === 'active' ? 'Active' : <Badge kind="grey">Disabled</Badge>}</td><td>{dt(s.last_login_at)}</td><td><button onClick={() => open(s)}>Edit</button></td></tr>)}</tbody></table></div>}
    {edit ? <Modal title={edit.id ? 'Edit staff' : 'New staff member'} onClose={() => setEdit(null)}>
      <Field label="Name"><input value={f.name} onChange={(e) => setF({ ...f, name: e.target.value })} /></Field><Field label="Email (sign-in)"><input type="email" value={f.email} onChange={(e) => setF({ ...f, email: e.target.value })} /></Field>
      <div className="row"><div className="grow"><Field label="Role"><select value={f.role} onChange={(e) => setF({ ...f, role: e.target.value })}><option value="owner">Owner</option><option value="manager">Manager</option><option value="staff">Staff</option></select></Field></div><div className="grow"><Field label="Status"><select value={f.status} onChange={(e) => setF({ ...f, status: e.target.value })}><option value="active">Active</option><option value="disabled">Disabled</option></select></Field></div></div>
      <Field label={edit.id ? 'New password (leave blank to keep)' : 'Starting password (10+ characters)'}><input type="password" autoComplete="new-password" value={f.password} onChange={(e) => setF({ ...f, password: e.target.value })} /></Field>
      {f.role !== 'owner' ? <><h3>Extra permissions</h3><div className="grid g2" style={{ gridTemplateColumns: 'repeat(auto-fit,minmax(170px,1fr))' }}>{PERMS.map((p) => <Check key={p} label={p} checked={f.extra_permissions.includes(p)} onChange={(v) => setF({ ...f, extra_permissions: v ? [...f.extra_permissions, p] : f.extra_permissions.filter((x: string) => x !== p) })} />)}</div></> : null}
      <div className="row mt"><button className="primary" onClick={save}>Save</button><button onClick={() => setEdit(null)}>Cancel</button></div></Modal> : null}</>;
}

export function AuditLog() {
  const [action, setAction] = useState(''); const da = useDebounced(action); const [open, setOpen] = useState<number | null>(null);
  const { data, error, reload } = useLoad(() => api.get('/audit-logs?limit=100' + (da ? `&action=${encodeURIComponent(da)}` : '')).then((r) => r.logs), [da]);
  return <><h1>Audit log</h1><div className="card"><input style={{ maxWidth: 280 }} placeholder="Filter by action, e.g. product, settings, stock" value={action} onChange={(e) => setAction(e.target.value)} aria-label="Filter" /></div>
    {!data ? <Loading error={error} retry={reload} /> : <div className="card" style={{ overflowX: 'auto' }}><table><thead><tr><th>When</th><th>Who</th><th>Action</th><th>Target</th></tr></thead><tbody>{data.map((l: any) => <><tr key={l.id} onClick={() => setOpen(open === l.id ? null : l.id)} style={{ cursor: 'pointer' }}><td>{dt(l.created_at)}</td><td>{l.actor_name ?? l.actor_type}</td><td>{l.action}</td><td><small className="muted">{l.entity} {String(l.entity_id ?? '').slice(0, 8)}</small></td></tr>
      {open === l.id ? <tr key={l.id + 'd'}><td colSpan={4}><pre style={{ whiteSpace: 'pre-wrap', margin: 0, fontSize: 12 }}>{JSON.stringify({ before: l.before, after: l.after, ip: l.ip }, null, 2)}</pre></td></tr> : null}</>)}</tbody></table>{!data.length ? <p className="muted">Nothing logged.</p> : null}</div>}</>;
}

export function System() {
  const { data, error, reload } = useLoad(() => api.get('/system'));
  if (!data) return <Loading error={error} retry={reload} />;
  const Row = ({ t, ok, note }: { t: string; ok: boolean; note: string }) => <div className="card"><div className="row"><h2 style={{ margin: 0 }}>{t}</h2><Badge kind={ok ? undefined : 'warn'}>{ok ? 'Configured' : 'Not live'}</Badge></div><p>{note}</p></div>;
  return <><h1>Payments & system</h1><p className="muted">Environment: <b>{data.environment}</b>. {data.note}</p>
    <Row t={`Payments · ${data.payments.provider} (${data.payments.mode})`} ok={data.payments.live || data.payments.mode === 'sandbox'} note={data.payments.note + (data.payments.provider === 'razorpay' ? ` Keys: ${data.payments.keys_configured ? 'set' : 'MISSING'}. Webhook secret: ${data.payments.webhook_secret_configured ? 'set' : 'MISSING'}.` : '')} />
    <Row t={`OTP · ${data.otp.provider}`} ok={data.otp.provider !== 'mock'} note={data.otp.note} />
    <Row t={`Distance routing · ${data.routing.provider}`} ok={data.routing.configured} note={data.routing.configured ? 'Road distance is calculated for delivery fees.' : 'No routing provider — customers are asked to pick a delivery area (or the fallback you configured is used).'} />
    <Row t="Push notifications (FCM)" ok={data.push.configured} note={data.push.configured ? 'Configured.' : 'Not configured — order updates appear in the app but no phone notifications are sent.'} />
    <Row t={`Image storage · ${data.storage.driver}`} ok note={data.storage.driver === 'local' ? 'Images are stored on the server disk. Use S3-compatible storage for production and back it up.' : 'S3-compatible storage.'} /></>;
}
