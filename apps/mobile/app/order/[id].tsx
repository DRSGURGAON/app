import React, { useCallback, useState } from 'react';
import { Alert, Linking, Platform, RefreshControl, ScrollView, Text, View } from 'react-native';
import { router, useFocusEffect, useLocalSearchParams } from 'expo-router';
import { api, ApiError } from '../../src/lib/api';
import { useAsync } from '../../src/lib/useAsync';
import { payOrder } from '../../src/lib/pay';
import { formatINR } from '../../src/lib/money';
import { useI18n } from '../../src/i18n';
import { useAuth } from '../../src/state/auth';
import { useCart } from '../../src/state/cart';
import { useStoreConfig } from '../../src/state/storeConfig';
import { colors, radius, space } from '../../src/theme';
import { Button, Card, ErrorState, Field, Row, SectionTitle, Skeleton, Thumb } from '../../src/ui/kit';
import { fmtDate, STATUS_KEY, statusColor } from '../../src/ui/status';

export default function OrderScreen() {
  const p = useLocalSearchParams<{ id: string; placed?: string; pay?: string; payMsg?: string }>(); const { t, lang, pick } = useI18n(); const { user } = useAuth(); const cart = useCart(); const { config } = useStoreConfig();
  const q = useAsync((signal) => api<{ order: any }>(`/v1/orders/${p.id}`, { signal }), [p.id], !!user);
  const [busy, setBusy] = useState(false); const [msg, setMsg] = useState<string | null>(p.payMsg ?? null); const [reason, setReason] = useState(''); const [cancelling, setCancelling] = useState(false);
  // light polling while a payment is being settled or the order is moving
  useFocusEffect(useCallback(() => { const id = setInterval(() => { if (q.data && ['pending_payment', 'placed', 'accepted', 'packing', 'ready_for_dispatch', 'out_for_delivery', 'ready_for_pickup'].includes(q.data.order.status)) void q.reload(); }, 20000); return () => clearInterval(id); // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [q.data?.order?.status]));
  if (q.loading && !q.data) return <View style={{ padding: space.lg }}><Skeleton h={120} /><Skeleton h={200} style={{ marginTop: 12 }} /></View>;
  if (q.error || !q.data) return <ErrorState error={q.error ?? { message: t('errGeneric') }} onRetry={q.reload} />;
  const o = q.data.order; const unpaid = o.status === 'pending_payment'; const canPay = unpaid && o.payment_method === 'online' && new Date(o.payment_expires_at) > new Date();
  const doPay = async () => { setBusy(true); setMsg(null); const r = await payOrder(o.id, user?.name); setBusy(false); if (r.status !== 'paid') setMsg(r.status === 'cancelled' ? t('paymentFailed') : r.message ?? (r.status === 'pending' ? t('paymentVerifying') : t('paymentFailed'))); await q.reload(); };
  const doCancel = async () => {
    if (reason.trim().length < 3) { setMsg(t('cancelReason')); return; }
    setBusy(true);
    try { const r = await api<{ order: any }>(`/v1/orders/${o.id}/cancel`, { method: 'POST', body: { reason: reason.trim() } }); q.setData({ order: r.order }); setCancelling(false); setMsg(t('orderCancelled')); }
    catch (e) { setMsg(e instanceof ApiError ? e.message : t('errGeneric')); } finally { setBusy(false); }
  };
  const reorder = async () => {
    try {
      const r = await api<{ items: { product_id: string; qty: number }[] }>(`/v1/orders/${o.id}/reorder`, { auth: true });
      const snaps: Record<string, any> = {}; for (const i of o.items) if (i.product_id) snaps[i.product_id] = { name: i.name, price: i.unit_price, unit: i.unit, pack_size: i.pack_size, image_url: i.image_url };
      cart.replaceAll(r.items, snaps); router.push('/cart');
    } catch (e) { setMsg(e instanceof ApiError ? e.message : t('errGeneric')); }
  };
  const addr = o.address as any;
  return (
    <ScrollView contentContainerStyle={{ padding: space.lg, paddingBottom: 40 }} refreshControl={<RefreshControl refreshing={q.loading} onRefresh={q.reload} colors={[colors.primary]} />}>
      {p.placed === '1' ? <Card style={{ backgroundColor: colors.primarySoft, alignItems: 'center' }}><Text style={{ fontSize: 40 }}>🎉</Text><Text style={{ fontWeight: '800', fontSize: 20, color: colors.primary }}>{t('orderPlaced')}</Text><Text style={{ color: colors.muted, textAlign: 'center' }}>{o.payment_status === 'paid' ? t('paymentSuccess') : t('orderPlacedHint')}</Text></Card> : null}
      {unpaid ? <Card style={{ backgroundColor: colors.accentSoft }}><Text style={{ fontWeight: '800', color: colors.warn }}>{t('paymentPending')}</Text>{msg ? <Text style={{ marginTop: 4 }}>{msg}</Text> : null}{canPay ? <Button title={t('payNow', { amt: formatINR(o.totals.total) })} loading={busy} onPress={doPay} style={{ marginTop: 10 }} /> : null}</Card> : msg ? <Card><Text accessibilityLiveRegion="polite">{msg}</Text></Card> : null}
      <Card>
        <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}><Text style={{ fontWeight: '800', fontSize: 17 }}>{t('orderNo', { n: o.order_no })}</Text><Text style={{ fontWeight: '800', color: statusColor(o.status) }}>{t(STATUS_KEY[o.status] ?? 'statusPlaced')}</Text></View>
        <Text style={{ color: colors.muted }}>{t('placedOn', { d: fmtDate(o.placed_at, lang) })}</Text>
        {o.cancel_reason ? <Text style={{ color: colors.danger, marginTop: 4 }}>{o.cancel_reason}</Text> : null}
        <Text style={{ fontWeight: '800', marginTop: space.md, marginBottom: 6 }}>{t('orderTimeline')}</Text>
        {o.timeline.map((s: any) => (
          <View key={s.status} style={{ flexDirection: 'row', alignItems: 'center', minHeight: 32 }}>
            <View style={{ width: 18, height: 18, borderRadius: 9, backgroundColor: s.done ? colors.primary : '#fff', borderWidth: 2, borderColor: s.done ? colors.primary : colors.border, marginRight: 10 }} />
            <Text style={{ fontWeight: s.current ? '800' : '400', color: s.done ? colors.text : colors.muted }}>{t(STATUS_KEY[s.status] ?? 'statusPlaced')}{s.current ? '  ←' : ''}</Text>
          </View>))}
      </Card>
      <Card>
        <Text style={{ fontWeight: '800', marginBottom: 6 }}>{o.fulfilment_type === 'pickup' ? t('pickupFrom') : t('deliveredTo')}</Text>
        {o.fulfilment_type === 'pickup' ? <Text>{pick(config?.store.address_en, config?.store.address_hi)}</Text> : addr ? <Text>{[addr.full_name, addr.line1, addr.line2, addr.landmark, `${addr.city ?? ''} ${addr.pincode ?? ''}`].filter(Boolean).join(', ')}</Text> : null}
        <Text style={{ color: colors.muted, marginTop: 6 }}>{t('paymentLabel')}: {o.payment_method === 'cod' ? t('cod') : t('online')} · {o.payment_status}</Text>
      </Card>
      <SectionTitle title={t('items', { n: o.items.length })} />
      <Card style={{ padding: space.md }}>
        {o.items.map((i: any) => (<View key={i.id} style={{ flexDirection: 'row', alignItems: 'center', paddingVertical: 6 }}><Thumb uri={i.image_url} size={48} /><View style={{ flex: 1, marginHorizontal: 10 }}><Text numberOfLines={2} style={{ fontWeight: '600' }}>{i.name}</Text><Text style={{ color: colors.muted, fontSize: 12 }}>{formatINR(i.unit_price)} × {i.qty}</Text></View><Text style={{ fontWeight: '700' }}>{formatINR(i.line_total)}</Text></View>))}
      </Card>
      <SectionTitle title={t('billDetails')} />
      <Card>
        <Row label={t('itemsTotal')} value={formatINR(o.totals.subtotal)} />
        {Number(o.totals.coupon_discount) > 0 ? <Row label={`${t('couponDiscount')} (${o.totals.coupon_code})`} value={`−${formatINR(o.totals.coupon_discount)}`} color={colors.success} /> : null}
        {Number(o.totals.first_order_discount) > 0 ? <Row label={t('firstOrder')} value={`−${formatINR(o.totals.first_order_discount)}`} color={colors.success} /> : null}
        {Number(o.totals.coin_discount) > 0 ? <Row label={`${t('coinDiscount')} (${o.totals.coins_redeemed})`} value={`−${formatINR(o.totals.coin_discount)}`} color={colors.success} /> : null}
        <Row label={t('deliveryFee')} value={o.fulfilment_type === 'pickup' ? t('free') : formatINR(o.totals.delivery_fee)} />
        {o.fulfilment_type === 'delivery' && o.delivery.distance_km != null ? <Text style={{ color: colors.muted, fontSize: 12 }}>{t('deliveryDistance', { km: o.delivery.distance_km })}{o.delivery.zone ? ` · ${o.delivery.zone}` : ''}</Text> : null}
        <View style={{ height: 1, backgroundColor: colors.border, marginVertical: 8 }} /><Row bold label={t('total')} value={formatINR(o.totals.total)} />
        {o.coins.to_earn > 0 && !['cancelled', 'rejected'].includes(o.status) ? <Text style={{ color: colors.muted, fontSize: 12 }}>🪙 {t('coinsWillEarn', { n: o.coins.to_earn })}</Text> : null}
      </Card>
      {o.refunds?.length ? <Card><Text style={{ fontWeight: '800' }}>{t('refunds')}</Text>{o.refunds.map((r: any) => <Text key={r.id} style={{ marginTop: 4 }}>{formatINR(r.amount)} · {r.status}</Text>)}</Card> : null}
      {cancelling ? <Card><Field label={t('cancelReason')} value={reason} onChangeText={setReason} maxLength={200} /><View style={{ flexDirection: 'row' }}><Button variant="danger" title={t('cancelOrder')} loading={busy} onPress={doCancel} style={{ flex: 1 }} /><Button variant="ghost" title={t('close')} onPress={() => setCancelling(false)} style={{ marginLeft: 8 }} /></View></Card> : null}
      <View style={{ marginTop: space.sm }}>
        <Button variant="secondary" title={t('reorder')} onPress={reorder} />
        {o.can_cancel && !cancelling ? <Button variant="ghost" title={t('cancelOrder')} style={{ marginTop: 8 }} onPress={() => setCancelling(true)} /> : null}
        {config?.store.phone ? <Button variant="ghost" title={`${t('helpCall')} · ${config.store.phone}`} style={{ marginTop: 8 }} onPress={() => void Linking.openURL(`tel:${config.store.phone}`)} /> : null}
      </View>
    </ScrollView>
  );
}
void Alert; void Platform;
