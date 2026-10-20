import React, { createContext, useContext, useEffect, useState } from 'react';
import { NavLink, Navigate, Route, Routes, useNavigate } from 'react-router-dom';
import * as api from './api';
import { Field, Loading, useAction, useToast } from './ui';
import Dashboard from './pages/Dashboard';
import Orders from './pages/Orders';
import Products from './pages/Products';
import { Categories, Inventory } from './pages/Catalog';
import ImportPage from './pages/Import';
import { Coupons, Banners } from './pages/Offers';
import Delivery from './pages/Delivery';
import { SettingsPage } from './pages/Settings';
import { Customers, Staff, AuditLog, System, Coins } from './pages/People';

export type Admin = { id: string; email: string; name: string; role: 'owner' | 'manager' | 'staff'; permissions: string[] };
const Ctx = createContext<{ admin: Admin; can: (p: string) => boolean; logout: () => void }>(null as any);
export const useAdmin = () => useContext(Ctx);

const NAV: { to: string; label: string; perm?: string }[] = [
  { to: '/', label: '📊 Dashboard', perm: 'orders:read' }, { to: '/orders', label: '🧾 Orders', perm: 'orders:read' },
  { to: '/products', label: '📦 Products', perm: 'catalog:read' }, { to: '/categories', label: '🗂️ Categories', perm: 'catalog:read' },
  { to: '/inventory', label: '🏷️ Inventory', perm: 'inventory:read' }, { to: '/import', label: '⬆️ Import products', perm: 'imports:write' },
  { to: '/coupons', label: '🎟️ Coupons', perm: 'catalog:read' }, { to: '/banners', label: '🖼️ Banners & offers', perm: 'catalog:read' },
  { to: '/delivery', label: '🚚 Delivery', perm: 'delivery:write' }, { to: '/coins', label: '🪙 Coins & first order', perm: 'customers:read' },
  { to: '/customers', label: '👥 Customers', perm: 'customers:read' }, { to: '/settings', label: '⚙️ Store & policies' },
  { to: '/staff', label: '🔐 Staff', perm: 'staff:write' }, { to: '/audit', label: '📜 Audit log', perm: 'audit:read' }, { to: '/system', label: '🔌 Payments & system', perm: 'settings:write' },
];

function Login({ onDone }: { onDone: (a: Admin) => void }) {
  const [email, setEmail] = useState(''); const [password, setPassword] = useState(''); const [err, setErr] = useState(''); const [busy, setBusy] = useState(false);
  const submit = async (e: React.FormEvent) => { e.preventDefault(); setBusy(true); setErr(''); try { const r = await api.post('/login', { email, password }); api.setToken(r.token); onDone(r.admin); } catch (x: any) { setErr(x.message); } finally { setBusy(false); } };
  return <form className="card login" onSubmit={submit}><h1>Ardh Sainik Canteen</h1><p className="muted">Store admin sign-in</p>
    <Field label="Email"><input type="email" autoComplete="username" value={email} onChange={(e) => setEmail(e.target.value)} required /></Field>
    <Field label="Password"><input type="password" autoComplete="current-password" value={password} onChange={(e) => setPassword(e.target.value)} required /></Field>
    {err ? <div className="err" role="alert">{err}</div> : null}<button className="primary" disabled={busy} style={{ width: '100%' }}>{busy ? 'Signing in…' : 'Sign in'}</button></form>;
}

function ChangePassword({ onClose }: { onClose: () => void }) {
  const run = useAction(); const [cur, setCur] = useState(''); const [nxt, setNxt] = useState('');
  return <div className="card"><h2>Change password</h2><div className="row"><div className="grow"><Field label="Current password"><input type="password" value={cur} onChange={(e) => setCur(e.target.value)} /></Field></div>
    <div className="grow"><Field label="New password (10+ characters)"><input type="password" value={nxt} onChange={(e) => setNxt(e.target.value)} /></Field></div></div>
    <div className="row"><button className="primary" onClick={async () => { if (await run(() => api.post('/me/password', { current: cur, next: nxt }), 'Password changed')) onClose(); }}>Save</button><button onClick={onClose}>Cancel</button></div></div>;
}

export function App() {
  const [admin, setAdmin] = useState<Admin | null>(null); const [booting, setBooting] = useState(!!api.getToken()); const [menu, setMenu] = useState(false); const [pw, setPw] = useState(false);
  const toast = useToast(); const nav = useNavigate();
  useEffect(() => { api.setAuthLostHandler(() => { setAdmin(null); toast('Please sign in again', 'bad'); }); }, [toast]);
  useEffect(() => { if (!api.getToken()) return; api.get('/me').then((r) => setAdmin(r.admin)).catch(() => api.setToken(null)).finally(() => setBooting(false)); }, []);
  if (booting) return <Loading />;
  if (!admin) return <Login onDone={setAdmin} />;
  const can = (p: string) => admin.permissions.includes(p);
  const logout = () => { api.setToken(null); setAdmin(null); nav('/'); };
  const items = NAV.filter((n) => !n.perm || can(n.perm));
  const guard = (perm: string | undefined, el: React.ReactElement) => (!perm || can(perm) ? el : <div className="card">You do not have access to this page.</div>);
  return <Ctx.Provider value={{ admin, can, logout }}><div className="layout">
    <nav className={`side ${menu ? 'open' : ''}`} onClick={() => setMenu(false)} aria-label="Main"><div className="brand">🛒 Ardh Sainik Canteen<br /><small style={{ fontWeight: 400 }}>Admin</small></div>
      {items.map((n) => <NavLink key={n.to} to={n.to} end={n.to === '/'} className={({ isActive }) => (isActive ? 'active' : '')}>{n.label}</NavLink>)}</nav>
    <div className="main"><div className="topbar no-print"><button className="menu-btn" onClick={() => setMenu(!menu)} aria-label="Menu">☰</button><span className="sp" />
      <span className="muted">{admin.name} · {admin.role}</span><button onClick={() => setPw(!pw)}>Password</button><button onClick={logout}>Sign out</button></div>
      <div className="content">{pw ? <ChangePassword onClose={() => setPw(false)} /> : null}
        <Routes>
          <Route path="/" element={can('orders:read') ? <Dashboard /> : <Navigate to="/settings" />} />
          <Route path="/orders" element={guard('orders:read', <Orders />)} />
          <Route path="/products" element={guard('catalog:read', <Products />)} />
          <Route path="/categories" element={guard('catalog:read', <Categories />)} />
          <Route path="/inventory" element={guard('inventory:read', <Inventory />)} />
          <Route path="/import" element={guard('imports:write', <ImportPage />)} />
          <Route path="/coupons" element={guard('catalog:read', <Coupons />)} />
          <Route path="/banners" element={guard('catalog:read', <Banners />)} />
          <Route path="/delivery" element={guard('delivery:write', <Delivery />)} />
          <Route path="/coins" element={guard('customers:read', <Coins />)} />
          <Route path="/customers" element={guard('customers:read', <Customers />)} />
          <Route path="/settings" element={<SettingsPage />} />
          <Route path="/staff" element={guard('staff:write', <Staff />)} />
          <Route path="/audit" element={guard('audit:read', <AuditLog />)} />
          <Route path="/system" element={guard('settings:write', <System />)} />
          <Route path="*" element={<div className="card">Page not found.</div>} />
        </Routes></div></div></div></Ctx.Provider>;
}
