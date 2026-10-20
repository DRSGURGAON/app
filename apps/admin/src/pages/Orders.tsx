import { useState } from 'react';
import * as api from '../api';
import { dt, inr } from '../api';
import { useAdmin } from '../App';
import { Badge, Field, Modal, Pager, statusKind, useAction, useDebounced, useLoad, Loading } from '../ui';

const STATUSES = ['placed', 'accepted', 'packing', 'ready_for_dispatch', 'out_for_delivery', 'delivered', 'ready_for_pickup', 'collected', 'cancelled', 'rejected', 'refund_pending', 'refunded', 'pending_payment'];
const label = (s: string) => s.replace(/_/g, ' ').replace(/^./, (c) => c.toUpperCase());

function OrderModal({ id, onClose, onChanged }: { id: string; onClose: () => void; onChanged: () => void }) {
  const { can } = useAdmin(); const run = useAction();
  const { data, error, reload, setData } = useLoad(() => api.get(`/orders/${id}`).then((r) => r.order), [id]);
  const [reason, setReason] = useState(''); const [refundAmt, setRefundAmt] = useState('');
  if (!data) return <Modal title="Order" onClose={onClose}><Loading error={error} retry={reload} /></Modal>;
  const o = data; const a = o.address ?? {}; const t = o.totals;
  const move = async (status: string) => {
    const needReason = status === 'cancelled' || status === 'rejected';
    if (needReason && reason.trim().length < 3) { await run(async () => { throw new Error('Write a short reason first (shown to the customer).'); }); return; }
    const r = await run(() => api.post(`/orders/${id}/status`, { status, reason: needReason ? reason : undefined }), `Marked ${label(status)}`);
    if (r) { setData(r.order); setReason(''); onChanged(); }
  };
  return <Modal title={`Order ${o.order_no}`} onClose={onClose}>
    <div className="row"><Badge kind={statusKind(o.status)}>{o.status_label.en}</Badge><span className="muted">{dt(o.placed_at)}</span><span className="right">{o.fulfilment_type === 'pickup' ? '🏪 Store pickup' : '🚚 Home delivery'}</span></div>
    <p><b>{o.customer_name || 'Customer'}</b> · <a href={`tel:${o.customer_phone}`}>{o.customer_phone}</a>{o.fulfilment_type === 'delivery' ? <><br />{[a.line1, a.line2, a.landmark, a.city, a.pincode].filter(Boolean).join(', ')}</> : null}{o.customer_note ? <><br /><i>Note: {o.customer_note}</i></> : null}</p>
    <table><thead><tr><th>Item</th><th>Rate</th><th>Qty</th><th>Amount</th></tr></thead><tbody>{o.items.map((i: any) => <tr key={i.id}><td>{i.name}<br /><small className="muted">{i.sku}{i.pack_size ? ` · ${i.pack_size}` : ''}</small></td><td>{inr(i.unit_price)}</td><td>{i.qty}</td><td>{inr(i.line_total)}</td></tr>)}</tbody></table>
    <table style={{ maxWidth: 360, marginLeft: 'auto' }}><tbody>
      <tr><td>Items</td><td>{inr(t.subtotal)}</td></tr>
      {Number(t.coupon_discount) > 0 && <tr><td>Coupon {t.coupon_code}</td><td>−{inr(t.coupon_discount)}</td></tr>}
      {Number(t.first_order_discount) > 0 && <tr><td>First-order discount</td><td>−{inr(t.first_order_discount)}</td></tr>}
      {Number(t.coin_discount) > 0 && <tr><td>Coins ({t.coins_redeemed})</td><td>−{inr(t.coin_discount)}</td></tr>}
      <tr><td>Delivery fee</td><td>{inr(t.delivery_fee)}</td></tr><tr><td><b>Total</b></td><td><b>{inr(t.total)}</b></td></tr></tbody></table>
    <p className="muted">Payment: {o.payment_method === 'cod' ? 'Cash on delivery' : 'Online'} · {o.payment_status}{o.fulfilment_type === 'delivery' ? ` · Delivery: ${o.delivery.distance_km ?? '—'} km (${o.delivery.method ?? '—'})${o.delivery.zone ? `, zone ${o.delivery.zone}` : ''}` : ''}{o.cancel_reason ? ` · Reason: ${o.cancel_reason}` : ''}</p>
    {can('orders:write') && o.admin_next.length ? <div className="card" style={{ background: '#fafbf8' }}><h3 style={{ marginTop: 0 }}>Update status</h3>
      <Field label="Reason (required for cancel / reject)"><input value={reason} onChange={(e) => setReason(e.target.value)} placeholder="e.g. Item out of stock" /></Field>
      <div className="row">{o.admin_next.map((s: string, i: number) => <button key={s} className={['cancelled', 'rejected'].includes(s) ? 'danger' : i === 0 ? 'primary' : ''} onClick={() => move(s)}>{['cancelled', 'rejected'].includes(s) ? label(s) : `→ ${label(s)}`}</button>)}</div></div> : null}
    {can('orders:write') && o.payment_method === 'cod' && o.payment_status === 'cod_pending' && ['delivered', 'collected'].includes(o.status) ? <button className="primary" onClick={async () => { const r = await run(() => api.post(`/orders/${id}/cod-collected`), 'Cash marked collected'); if (r) { setData(r.order); onChanged(); } }}>Mark cash collected</button> : null}
    {can('refunds:write') && o.payments.some((p: any) => p.status === 'captured') && !['refunded'].includes(o.status) ? <div className="card mt"><h3 style={{ marginTop: 0 }}>Refund (online payment)</h3><div className="row"><div className="grow"><Field label="Amount ₹ (blank = full remaining)"><input inputMode="decimal" value={refundAmt} onChange={(e) => setRefundAmt(e.target.value)} /></Field></div><div className="grow"><Field label="Reason"><input value={reason} onChange={(e) => setReason(e.target.value)} /></Field></div></div>
      <button className="danger" onClick={async () => { const r = await run(() => api.post(`/orders/${id}/refund`, { amount: refundAmt || undefined, reason }), 'Refund requested'); if (r) { setData(r.order); onChanged(); } }}>Issue refund</button></div> : null}
    {o.refunds.length ? <><h3>Refunds</h3><table><tbody>{o.refunds.map((r: any) => <tr key={r.id}><td>{dt(r.created_at)}</td><td>{inr(r.amount)}</td><td>{r.status}</td><td>{r.reason}</td></tr>)}</tbody></table></> : null}
    <h3>History</h3><table><tbody>{o.history.map((h: any, i: number) => <tr key={i}><td>{dt(h.created_at)}</td><td>{h.label?.en ?? h.to_status}</td><td>{h.actor_type}</td><td>{h.note}</td></tr>)}</tbody></table>
    <div className="row mt"><button onClick={() => run(() => api.openHtml(`/orders/${id}/invoice`))}>🖨️ Print invoice</button><button onClick={onClose}>Close</button></div>
  </Modal>;
}

export default function Orders() {
  const [page, setPage] = useState(1); const [status, setStatus] = useState(''); const [ful, setFul] = useState(''); const [pm, setPm] = useState(''); const [q, setQ] = useState(''); const [from, setFrom] = useState(''); const [to, setTo] = useState(''); const [open, setOpen] = useState<string | null>(null);
  const dq = useDebounced(q);
  const { data, error, reload } = useLoad(() => { const p = new URLSearchParams({ page: String(page), limit: '25' }); if (status) p.set('status', status); if (ful) p.set('fulfilment', ful); if (pm) p.set('payment_method', pm); if (dq) p.set('q', dq); if (from) p.set('from', from); if (to) p.set('to', to); return api.get('/orders?' + p); }, [page, status, ful, pm, dq, from, to]);
  return <>
    <div className="row"><h1>Orders</h1><button className="right" onClick={reload}>Refresh</button></div>
    <div className="card"><div className="row">
      <input style={{ maxWidth: 220 }} placeholder="Search order no / phone / name" value={q} onChange={(e) => { setQ(e.target.value); setPage(1); }} aria-label="Search orders" />
      <select style={{ maxWidth: 170 }} value={status} onChange={(e) => { setStatus(e.target.value); setPage(1); }} aria-label="Status"><option value="">All statuses</option>{STATUSES.map((s) => <option key={s} value={s}>{label(s)}</option>)}</select>
      <select style={{ maxWidth: 150 }} value={ful} onChange={(e) => { setFul(e.target.value); setPage(1); }} aria-label="Fulfilment"><option value="">Delivery + pickup</option><option value="delivery">Delivery</option><option value="pickup">Pickup</option></select>
      <select style={{ maxWidth: 150 }} value={pm} onChange={(e) => { setPm(e.target.value); setPage(1); }} aria-label="Payment"><option value="">COD + online</option><option value="cod">COD</option><option value="online">Online</option></select>
      <input type="date" style={{ maxWidth: 150 }} value={from} onChange={(e) => { setFrom(e.target.value); setPage(1); }} aria-label="From date" /><input type="date" style={{ maxWidth: 150 }} value={to} onChange={(e) => { setTo(e.target.value); setPage(1); }} aria-label="To date" /></div></div>
    {!data ? <Loading error={error} retry={reload} /> : <div className="card" style={{ overflowX: 'auto' }}>
      {data.items.length ? <table><thead><tr><th>Order</th><th>Customer</th><th>Type</th><th>Payment</th><th>Total</th><th>Status</th><th>Placed</th></tr></thead><tbody>
        {data.items.map((o: any) => <tr key={o.id} onClick={() => setOpen(o.id)} style={{ cursor: 'pointer' }}><td><b>{o.order_no}</b><br /><small className="muted">{o.item_count} items</small></td><td>{o.customer_name || '—'}<br /><small className="muted">{o.customer_phone}</small></td><td>{o.fulfilment_type}</td><td>{o.payment_method === 'cod' ? 'COD' : 'Online'}<br /><small className="muted">{o.payment_status}</small></td><td>{inr(o.total)}</td><td><Badge kind={statusKind(o.status)}>{o.status_label.en}</Badge></td><td>{dt(o.placed_at)}</td></tr>)}</tbody></table> : <p className="muted">No orders match these filters.</p>}
      <Pager page={data.page} limit={data.limit} total={data.total} onPage={setPage} /></div>}
    {open ? <OrderModal id={open} onClose={() => setOpen(null)} onChanged={reload} /> : null}</>;
}
