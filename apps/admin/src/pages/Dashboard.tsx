import { Link } from 'react-router-dom';
import * as api from '../api';
import { inr } from '../api';
import { Loading, useLoad } from '../ui';

export default function Dashboard() {
  const { data, error, reload } = useLoad(() => api.get('/dashboard'));
  const { data: st } = useLoad(() => api.get('/store-status'));
  if (!data) return <Loading error={error} retry={reload} />;
  const t = data.today; const c = data.counts; const max = Math.max(1, ...data.last_7_days.map((d: any) => Number(d.sales)));
  const Stat = ({ label, value, to }: { label: string; value: React.ReactNode; to?: string }) => { const inner = <><b>{value}</b><span>{label}</span></>; return to ? <Link to={to} className="stat" style={{ textDecoration: 'none', color: 'inherit' }}>{inner}</Link> : <div className="stat">{inner}</div>; };
  return <>
    <div className="row"><h1>Dashboard</h1><span className="right muted">{st ? (st.open ? '🟢 Store is open for orders' : `🔴 ${st.reason}`) : ''}</span><button onClick={reload}>Refresh</button></div>
    <div className="grid g2" style={{ gridTemplateColumns: 'repeat(auto-fit,minmax(160px,1fr))' }}>
      <Stat label="New orders (to accept)" value={c.new} to="/orders" /><Stat label="In progress" value={c.in_progress} to="/orders" /><Stat label="Completed today" value={c.completed_today} />
      <Stat label="Orders today" value={t.orders} /><Stat label="Net sales today" value={inr(t.net_sales)} /><Stat label="Discounts given" value={inr(t.discounts)} /><Stat label="New customers" value={t.new_customers} />
    </div>
    <p className="muted" style={{ fontSize: 12 }} title={t.definitions?.net_sales}>Net sales = {t.definitions?.net_sales}</p>
    <div className="grid g2">
      <div className="card"><h2>Last 7 days (sales)</h2><div className="bars" style={{ marginBottom: 22 }}>{data.last_7_days.map((d: any) => <div key={d.day} style={{ height: `${Math.max(2, (Number(d.sales) / max) * 100)}%` }} title={`${d.day}: ${inr(d.sales)} · ${d.orders} orders`}><small>{d.day.slice(8)}</small></div>)}</div></div>
      <div className="card"><h2>Payments today</h2>{data.payment_breakdown.length ? <table><tbody>{data.payment_breakdown.map((p: any, i: number) => <tr key={i}><td>{p.payment_method === 'cod' ? 'Cash on delivery' : 'Online'}</td><td>{p.payment_status}</td><td>{p.n}</td><td>{inr(p.amount)}</td></tr>)}</tbody></table> : <p className="muted">No orders yet today.</p>}</div>
    </div>
    <div className="grid g2">
      <div className="card"><h2>Low / out of stock</h2>{data.low_stock.length ? <table><thead><tr><th>Item</th><th>Available</th></tr></thead><tbody>{data.low_stock.map((p: any) => <tr key={p.id}><td>{p.name}<br /><small className="muted">{p.sku}</small></td><td><span className={`badge ${p.available <= 0 ? 'bad' : 'warn'}`}>{p.available}</span></td></tr>)}</tbody></table> : <p className="muted">Nothing is running low.</p>}<Link to="/inventory">Open inventory →</Link></div>
      <div className="card"><h2>Top products (30 days)</h2>{data.top_products.length ? <table><tbody>{data.top_products.map((p: any) => <tr key={p.product_id}><td>{p.name}</td><td>{p.qty}</td><td>{inr(p.revenue)}</td></tr>)}</tbody></table> : <p className="muted">Appears after the first delivered orders.</p>}</div>
    </div></>;
}
