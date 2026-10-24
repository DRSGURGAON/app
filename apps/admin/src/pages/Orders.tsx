import { useState } from 'react';
import * as api from '../api';
import { dt, inr } from '../api';
import { useAdmin } from '../App';
import { Badge, Field, Modal, Pager, statusKind, useAction, useDebounced, useLoad, Loading } from '../ui';

const STATUSES = ['placed', 'accepted', 'packing', 'ready_for_dispatch', 'out_for_delivery', 'delivered', 'ready_for_pickup', 'collected', 'cancelled', 'rejected', 'refund_pending', 'refunded', 'pending_payment'];
const label = (s: string) => s.replace(/_/g, ' ').replace(/^./, (c) => c.toUpperCase());
const payLabel = (m: string) => (m === 'cod' ? 'COD' : m === 'upi' ? 'UPI' : 'Online');

/** Staff check the bank / UPI merchant app, then type the amount and UTR they SEE there (never copied from the customer). */
function UpiVerify({ o, onDone }: { o: any; onDone: (order: any) => void }) {
  const run = useAction();
  const [amount, setAmount] = useState(''); const [utr, setUtr] = useState(''); const [reason, setReason] = useState('');
  const pay = o.payments.find((p: any) => p.provider === 'upi_manual');
  const late = o.status !== 'pending_payment';
  const confirm = async () => {
    const body = { amount: amount.trim(), utr: utr.trim() };
    try { onDone((await api.post(`/orders/${o.id}/upi/confirm`, body)).order); }
    catch (e) {
      if (e instanceof api.ApiError && e.code === 'UTR_MISMATCH' && window.confirm(`${e.message}\n\nConfirm with the UTR from the bank app anyway?`)) {
        const r = await run(() => api.post(`/orders/${o.id}/upi/confirm`, { ...body, accept_utr_mismatch: true }), 'Payment confirmed');
        if (r) onDone(r.order);
      } else await run(async () => { throw e; });
    }
  };
  const reject = async () => {
    if (reason.trim().length < 3) { await run(async () => { throw new Error('Write a short reason first (shown to the customer).'); }); return; }
    const r = await run(() => api.post(`/orders/${o.id}/upi/reject`, { reason: reason.trim() }), 'Order cancelled: payment not received');
    if (r) onDone(r.order);
  };
  return <div className="card" style={{ background: '#fff8e6', borderColor: '#f0c36d' }}>
    <h3 style={{ marginTop: 0 }}>{late ? 'UPI money arrived after this order was cancelled?' : o.payment_status === 'verifying' ? '⏳ Verify UPI payment' : 'UPI payment not reported yet'}</h3>
    <p>Expected: <b>{inr(o.totals.total)}</b> for order <b>{o.order_no}</b>{pay?.claimed_utr ? <> · Customer says UTR <b>{pay.claimed_utr}</b> ({dt(pay.claimed_at)})</> : null}</p>
    <p className="muted">Open your bank / UPI merchant app. Confirm only if you can see a credit of exactly this amount. Type the amount and the 12-digit UTR from the bank app.
      {late ? ' Confirming here records the money and queues a refund to the customer.' : ''}</p>
    <div className="row"><div className="grow"><Field label="Amount received (₹)"><input inputMode="decimal" value={amount} onChange={(e) => setAmount(e.target.value)} placeholder={String(o.totals.total)} /></Field></div>
      <div className="grow"><Field label="UTR from bank app (12 digits)"><input inputMode="numeric" maxLength={12} value={utr} onChange={(e) => setUtr(e.target.value.replace(/\D/g, ''))} /></Field></div></div>
    <button className="primary" disabled={!amount || utr.length !== 12} onClick={confirm}>{late ? 'Record payment & queue refund' : '✔ Confirm payment'}</button>
    {!late ? <><Field label="Reason if no money came (shown to the customer)"><input value={reason} onChange={(e) => setReason(e.target.value)} placeholder="e.g. No credit found in the bank" /></Field>
      <button className="danger" onClick={reject}>Payment not received · cancel order</button></> : null}
  </div>;
}

function ManualRefundRow({ orderId, r, canWrite, onDone }: { orderId: string; r: any; canWrite: boolean; onDone: (order: any) => void }) {
  const run = useAction(); const [ref, setRef] = useState('');
  const open = canWrite && ['pending', 'processing', 'failed'].includes(r.status);
  return <tr><td>{dt(r.created_at)}</td><td>{inr(r.amount)}</td><td>{r.status}{open ? <><br /><small className="muted">Send by UPI / bank transfer yourself</small></> : null}</td><td>{r.reason}</td>
    <td>{open ? <div className="row"><input style={{ maxWidth: 200 }} value={ref} onChange={(e) => setRef(e.target.value)} placeholder="Refund UTR / reference" aria-label="Refund reference" />
      <button disabled={ref.trim().length < 4} onClick={async () => { const x = await run(() => api.post(`/orders/${orderId}/refunds/${r.id}/manual`, { reference: ref.trim() }), 'Refund recorded'); if (x) onDone(x.order); }}>Mark sent</button></div> : null}</td></tr>;
}

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
    {can('orders:write') && o.payment_method === 'upi' && (o.status === 'pending_payment' || (o.status === 'cancelled' && o.payment_status === 'failed'))
      ? <UpiVerify o={o} onDone={(order) => { setData(order); onChanged(); }} /> : null}
    <p className="muted">Payment: {o.payment_method === 'cod' ? 'Cash on delivery' : o.payment_method === 'upi' ? 'UPI (staff verified)' : 'Online'} · {o.payment_status}{o.fulfilment_type === 'delivery' ? ` · Delivery: ${o.delivery.distance_km ?? '—'} km (${o.delivery.method ?? '—'})${o.delivery.zone ? `, zone ${o.delivery.zone}` : ''}` : ''}{o.cancel_reason ? ` · Reason: ${o.cancel_reason}` : ''}</p>
    {can('orders:write') && o.admin_next.length ? <div className="card" style={{ background: '#fafbf8' }}><h3 style={{ marginTop: 0 }}>Update status</h3>
      <Field label="Reason (required for cancel / reject)"><input value={reason} onChange={(e) => setReason(e.target.value)} placeholder="e.g. Item out of stock" /></Field>
      <div className="row">{o.admin_next.map((s: string, i: number) => <button key={s} className={['cancelled', 'rejected'].includes(s) ? 'danger' : i === 0 ? 'primary' : ''} onClick={() => move(s)}>{['cancelled', 'rejected'].includes(s) ? label(s) : `→ ${label(s)}`}</button>)}</div></div> : null}
    {can('orders:write') && o.payment_method === 'cod' && o.payment_status === 'cod_pending' && ['delivered', 'collected'].includes(o.status) ? <button className="primary" onClick={async () => { const r = await run(() => api.post(`/orders/${id}/cod-collected`), 'Cash marked collected'); if (r) { setData(r.order); onChanged(); } }}>Mark cash collected</button> : null}
    {can('refunds:write') && o.payments.some((p: any) => p.status === 'paid' || p.status === 'partially_refunded') && !['refunded'].includes(o.status) ? <div className="card mt"><h3 style={{ marginTop: 0 }}>{o.payment_method === 'upi' ? 'Refund (UPI: you send the money back yourself, then mark it sent below)' : 'Refund (online payment)'}</h3><div className="row"><div className="grow"><Field label="Amount ₹ (blank = full remaining)"><input inputMode="decimal" value={refundAmt} onChange={(e) => setRefundAmt(e.target.value)} /></Field></div><div className="grow"><Field label="Reason"><input value={reason} onChange={(e) => setReason(e.target.value)} /></Field></div></div>
      <button className="danger" onClick={async () => { const r = await run(() => api.post(`/orders/${id}/refund`, { amount: refundAmt || undefined, reason }), 'Refund requested'); if (r) { setData(r.order); onChanged(); } }}>Issue refund</button></div> : null}
    {o.refunds.length ? <><h3>Refunds</h3><table><tbody>{o.refunds.map((r: any) => o.payment_method === 'upi'
      ? <ManualRefundRow key={r.id} orderId={o.id} r={r} canWrite={can('refunds:write')} onDone={(order) => { setData(order); onChanged(); }} />
      : <tr key={r.id}><td>{dt(r.created_at)}</td><td>{inr(r.amount)}</td><td>{r.status}</td><td>{r.reason}</td></tr>)}</tbody></table></> : null}
    <h3>History</h3><table><tbody>{o.history.map((h: any, i: number) => <tr key={i}><td>{dt(h.created_at)}</td><td>{h.label?.en ?? h.to_status}</td><td>{h.actor_type}</td><td>{h.note}</td></tr>)}</tbody></table>
    <div className="row mt"><button onClick={() => run(() => api.openHtml(`/orders/${id}/invoice`))}>🖨️ Print invoice</button><button onClick={onClose}>Close</button></div>
  </Modal>;
}

export default function Orders() {
  const [page, setPage] = useState(1); const [status, setStatus] = useState(''); const [ful, setFul] = useState(''); const [pm, setPm] = useState(''); const [pst, setPst] = useState(''); const [q, setQ] = useState(''); const [from, setFrom] = useState(''); const [to, setTo] = useState(''); const [open, setOpen] = useState<string | null>(null);
  const dq = useDebounced(q);
  const { data, error, reload } = useLoad(() => { const p = new URLSearchParams({ page: String(page), limit: '25' }); if (status) p.set('status', status); if (ful) p.set('fulfilment', ful); if (pm) p.set('payment_method', pm); if (pst) p.set('payment_status', pst); if (dq) p.set('q', dq); if (from) p.set('from', from); if (to) p.set('to', to); return api.get('/orders?' + p); }, [page, status, ful, pm, pst, dq, from, to]);
  const toVerify = useLoad(() => api.get('/orders?payment_status=verifying&limit=1').then((r) => r.total as number), [data]);
  return <>
    <div className="row"><h1>Orders</h1><button className="right" onClick={reload}>Refresh</button></div>
    {toVerify.data ? <div className="card row" style={{ background: '#fff8e6', borderColor: '#f0c36d' }}><b>⏳ {toVerify.data} UPI payment{toVerify.data > 1 ? 's' : ''} waiting for you to verify</b>
      <button className="right primary" onClick={() => { setPst('verifying'); setStatus(''); setPage(1); }}>Show</button></div> : null}
    {pst ? <p className="muted">Showing payment status “{label(pst)}” · <a href="#" onClick={(e) => { e.preventDefault(); setPst(''); setPage(1); }}>clear</a></p> : null}
    <div className="card"><div className="row">
      <input style={{ maxWidth: 220 }} placeholder="Search order no / phone / name" value={q} onChange={(e) => { setQ(e.target.value); setPage(1); }} aria-label="Search orders" />
      <select style={{ maxWidth: 170 }} value={status} onChange={(e) => { setStatus(e.target.value); setPage(1); }} aria-label="Status"><option value="">All statuses</option>{STATUSES.map((s) => <option key={s} value={s}>{label(s)}</option>)}</select>
      <select style={{ maxWidth: 150 }} value={ful} onChange={(e) => { setFul(e.target.value); setPage(1); }} aria-label="Fulfilment"><option value="">Delivery + pickup</option><option value="delivery">Delivery</option><option value="pickup">Pickup</option></select>
      <select style={{ maxWidth: 150 }} value={pm} onChange={(e) => { setPm(e.target.value); setPage(1); }} aria-label="Payment"><option value="">All payments</option><option value="cod">COD</option><option value="upi">UPI</option><option value="online">Online</option></select>
      <input type="date" style={{ maxWidth: 150 }} value={from} onChange={(e) => { setFrom(e.target.value); setPage(1); }} aria-label="From date" /><input type="date" style={{ maxWidth: 150 }} value={to} onChange={(e) => { setTo(e.target.value); setPage(1); }} aria-label="To date" /></div></div>
    {!data ? <Loading error={error} retry={reload} /> : <div className="card" style={{ overflowX: 'auto' }}>
      {data.items.length ? <table><thead><tr><th>Order</th><th>Customer</th><th>Type</th><th>Payment</th><th>Total</th><th>Status</th><th>Placed</th></tr></thead><tbody>
        {data.items.map((o: any) => <tr key={o.id} onClick={() => setOpen(o.id)} style={{ cursor: 'pointer' }}><td><b>{o.order_no}</b><br /><small className="muted">{o.item_count} items</small></td><td>{o.customer_name || '—'}<br /><small className="muted">{o.customer_phone}</small></td><td>{o.fulfilment_type}</td><td>{payLabel(o.payment_method)}<br /><small className="muted">{o.payment_status === 'verifying' ? '⏳ verify' : o.payment_status}</small></td><td>{inr(o.total)}</td><td><Badge kind={statusKind(o.status)}>{o.status_label.en}</Badge></td><td>{dt(o.placed_at)}</td></tr>)}</tbody></table> : <p className="muted">No orders match these filters.</p>}
      <Pager page={data.page} limit={data.limit} total={data.total} onPage={setPage} /></div>}
    {open ? <OrderModal id={open} onClose={() => setOpen(null)} onChanged={reload} /> : null}</>;
}
