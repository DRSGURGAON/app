import React, { useCallback, useRef, useState } from 'react';
import { Alert, KeyboardAvoidingView, Platform, Pressable, ScrollView, Text, View } from 'react-native';
import { router, useFocusEffect } from 'expo-router';
import { api, ApiError, newKey } from '../src/lib/api';
import { useAsync } from '../src/lib/useAsync';
import { useQuote } from '../src/lib/quote';
import { payOrder } from '../src/lib/pay';
import { formatINR } from '../src/lib/money';
import { useI18n } from '../src/i18n';
import { useAuth } from '../src/state/auth';
import { useCart } from '../src/state/cart';
import { useStoreConfig } from '../src/state/storeConfig';
import { colors, radius, space } from '../src/theme';
import { Button, Card, Chip, EmptyState, Field, Row, SectionTitle } from '../src/ui/kit';

interface Address { id: string; label: string; full_name: string; phone: string; line1: string; line2: string | null; landmark: string | null; city: string; pincode: string; is_default: boolean; zone_id: string | null }
const Option = ({ selected, title, hint, onPress, disabled }: { selected: boolean; title: string; hint?: string; onPress: () => void; disabled?: boolean }) => (
  <Pressable accessibilityRole="radio" accessibilityState={{ selected, disabled }} onPress={disabled ? undefined : onPress} style={{ minHeight: 56, flexDirection: 'row', alignItems: 'center', padding: space.md, borderRadius: radius.md, borderWidth: 2, borderColor: selected ? colors.primary : colors.border, backgroundColor: selected ? colors.primarySoft : '#fff', marginBottom: space.sm, opacity: disabled ? 0.45 : 1 }}>
    <View style={{ width: 22, height: 22, borderRadius: 11, borderWidth: 2, borderColor: selected ? colors.primary : colors.muted, alignItems: 'center', justifyContent: 'center' }}>{selected ? <View style={{ width: 10, height: 10, borderRadius: 5, backgroundColor: colors.primary }} /> : null}</View>
    <View style={{ marginLeft: 12, flex: 1 }}><Text style={{ fontWeight: '700', color: colors.text }}>{title}</Text>{hint ? <Text style={{ color: colors.muted, fontSize: 12, marginTop: 2 }}>{hint}</Text> : null}</View>
  </Pressable>
);

export default function CheckoutScreen() {
  const { t, pick } = useI18n(); const { user, ready } = useAuth(); const cart = useCart(); const { config } = useStoreConfig();
  const [fulfilment, setFulfilment] = useState<'delivery' | 'pickup'>('delivery');
  const [addressId, setAddressId] = useState<string | null>(null); const [zoneId, setZoneId] = useState<string | null>(null);
  const [payment, setPayment] = useState<'cod' | 'online'>('cod');
  const [couponInput, setCouponInput] = useState(''); const [coupon, setCoupon] = useState<string | null>(null);
  const [useCoins, setUseCoins] = useState(false); const [note, setNote] = useState('');
  const [placing, setPlacing] = useState(false); const [msg, setMsg] = useState<string | null>(null);
  const keyRef = useRef<{ sig: string; key: string } | null>(null);

  const addrs = useAsync((signal) => api<{ addresses: Address[] }>('/v1/addresses', { signal }), [user?.id], !!user);
  const zones = useAsync((signal) => api<{ zones: { id: string; name: string; name_hi: string | null }[] }>('/v1/delivery/zones', { auth: false, signal }), []);
  useFocusEffect(useCallback(() => { if (user) void addrs.reload(); // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user?.id]));
  const list = addrs.data?.addresses ?? [];
  const selected = list.find((a) => a.id === addressId) ?? (list.find((a) => a.is_default) ?? list[0]);
  const effAddressId = fulfilment === 'delivery' ? selected?.id ?? null : null;

  const items = cart.items.map((i) => ({ product_id: i.product_id, qty: i.qty }));
  const base = { items, fulfilment, address_id: effAddressId, zone_id: fulfilment === 'delivery' ? zoneId : null, coupon_code: coupon, payment_method: payment };
  // coins: first ask for max usable, the server clamps to what is allowed
  const probe = useQuote({ ...base, use_coins: 0 }, !!user && cart.ready && cart.items.length > 0 && (fulfilment === 'pickup' || !!effAddressId));
  const wantCoins = useCoins ? probe.quote?.coins.max_usable ?? 0 : 0;
  const { quote, loading, error, reload } = useQuote({ ...base, use_coins: wantCoins }, !!user && cart.ready && cart.items.length > 0 && (fulfilment === 'pickup' || !!effAddressId));

  if (ready && !user) return <EmptyState icon="🔐" title={t('loginNeeded')} actionLabel={t('login')} onAction={() => router.push('/login')} />;
  if (cart.ready && cart.items.length === 0 && !placing) return <EmptyState title={t('cartEmpty')} actionLabel={t('startShopping')} onAction={() => router.replace('/')} />;

  const needZone = quote?.delivery.error?.code === 'DELIVERY_ZONE_REQUIRED';
  const zoneChoices = quote?.delivery.zones_to_choose?.length ? quote.delivery.zones_to_choose : zones.data?.zones ?? [];
  const codOk = config?.order.cod_enabled !== false; const onlineOk = config?.order.online_enabled !== false;
  const deliveryOk = config?.store.delivery_enabled !== false; const pickupOk = config?.store.pickup_enabled !== false;
  const nonBlocking = new Set(['DELIVERY_ZONE_REQUIRED']);
  const hardBlockers = (quote?.blockers ?? []).filter((b) => !nonBlocking.has(b.code) && !b.details?.coupon);
  const canPlace = !!quote && quote.can_checkout && !placing && !loading;

  const applyCoupon = () => { const c = couponInput.trim().toUpperCase(); if (c) { setCoupon(c); setMsg(null); } };

  const place = async () => {
    if (!quote || !quote.totals.total) return;
    setPlacing(true); setMsg(null);
    const body = { items, fulfilment, address_id: effAddressId, zone_id: fulfilment === 'delivery' ? zoneId : null, payment_method: payment, coupon_code: quote.coupon?.applied ? quote.coupon.code : null, use_coins: quote.coins.applied, expected_total: quote.totals.total, note: note.trim() || null };
    const sig = JSON.stringify(body);
    if (!keyRef.current || keyRef.current.sig !== sig) keyRef.current = { sig, key: newKey() }; // same inputs retried (e.g. after a timeout) => same key => never a duplicate order
    try {
      const r = await api<{ order: { id: string; status: string } }>('/v1/orders', { method: 'POST', body, idempotencyKey: keyRef.current.key, timeoutMs: 30000 });
      keyRef.current = null; cart.clear();
      if (payment === 'online' && r.order.status === 'pending_payment') {
        const res = await payOrder(r.order.id, user?.name);
        router.replace({ pathname: '/order/[id]', params: { id: r.order.id, placed: res.status === 'paid' ? '1' : '0', pay: res.status, ...(res.message ? { payMsg: res.message } : {}) } });
      } else router.replace({ pathname: '/order/[id]', params: { id: r.order.id, placed: '1' } });
    } catch (e: any) {
      const m = e instanceof ApiError ? e.message : t('errGeneric');
      setMsg(e instanceof ApiError && e.isNetwork ? `${t('errNetwork')} ${t('retry')}` : e?.code === 'PRICE_CHANGED' ? t('priceChanged') : m);
      reload();
    } finally { setPlacing(false); }
  };

  const feeText = !quote ? '—' : fulfilment === 'pickup' ? t('free') : quote.delivery.fee === null ? '—' : formatINR(quote.delivery.fee);
  return (
    <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <ScrollView contentContainerStyle={{ padding: space.lg, paddingBottom: 32 }} keyboardShouldPersistTaps="handled">
        {config && !config.store.open_now ? <Card style={{ backgroundColor: colors.dangerSoft }}><Text style={{ color: colors.danger, fontWeight: '700' }}>{config.store.closed_message}</Text></Card> : null}
        <Text style={{ fontWeight: '800', fontSize: 16, marginBottom: space.sm }}>{t('deliveryMethod')}</Text>
        <Option selected={fulfilment === 'delivery'} title={t('homeDelivery')} hint={config ? `≤ ${config.delivery.near_radius_km} km ${formatINR(config.delivery.base_fee)} · > ${config.delivery.near_radius_km} km ${formatINR(config.delivery.far_fee)}` : undefined} disabled={!deliveryOk} onPress={() => { setFulfilment('delivery'); setMsg(null); }} />
        <Option selected={fulfilment === 'pickup'} title={t('storePickup')} hint={t('pickupFree')} disabled={!pickupOk} onPress={() => { setFulfilment('pickup'); setMsg(null); }} />

        {fulfilment === 'delivery' ? (
          <Card>
            <Text style={{ fontWeight: '800', marginBottom: 6 }}>{t('deliveryAddress')}</Text>
            {selected ? (
              <View><Text style={{ fontWeight: '700' }}>{selected.label} · {selected.full_name}</Text><Text style={{ color: colors.text }}>{[selected.line1, selected.line2, selected.landmark, `${selected.city} ${selected.pincode}`].filter(Boolean).join(', ')}</Text><Text style={{ color: colors.muted }}>{selected.phone}</Text></View>
            ) : addrs.loading ? <Text style={{ color: colors.muted }}>{t('loading')}</Text> : <Text style={{ color: colors.warn }}>{t('noAddress')}</Text>}
            {list.length > 1 ? <ScrollView horizontal showsHorizontalScrollIndicator={false} style={{ marginTop: 10 }}>{list.map((a) => <Chip key={a.id} label={a.label} selected={a.id === selected?.id} onPress={() => { setAddressId(a.id); setZoneId(null); }} />)}</ScrollView> : null}
            <Button variant="secondary" small style={{ marginTop: 10, alignSelf: 'flex-start' }} title={t('addAddress')} onPress={() => router.push('/address-edit')} />
            {needZone || !!zoneId || quote?.delivery.method === 'zone' ? (
              <View style={{ marginTop: space.md }}>
                <Text style={{ fontWeight: '800', color: needZone ? colors.warn : colors.text }}>{needZone ? t('zoneRequired') : t('deliveryArea')}</Text>{needZone ? <Text style={{ color: colors.muted, marginBottom: 8 }}>{t('zoneRequiredHint')}</Text> : null}
                <View style={{ flexDirection: 'row', flexWrap: 'wrap' }}>{zoneChoices.map((z) => <Chip key={z.id} label={pick(z.name, z.name_hi)} selected={(zoneId ?? quote?.delivery.zone?.id) === z.id} onPress={() => setZoneId(z.id)} />)}</View>
              </View>) : null}
          </Card>) : (
          <Card><Text style={{ fontWeight: '800' }}>{t('pickupFrom')}</Text><Text style={{ color: colors.text, marginTop: 4 }}>{pick(config?.store.address_en, config?.store.address_hi)}</Text>{config?.store.pickup_instructions ? <Text style={{ color: colors.muted, marginTop: 4 }}>{config.store.pickup_instructions}</Text> : null}</Card>)}

        <Text style={{ fontWeight: '800', fontSize: 16, marginVertical: space.sm }}>{t('paymentMethod')}</Text>
        <Option selected={payment === 'cod'} title={fulfilment === 'pickup' ? t('codPickup') : t('cod')} disabled={!codOk} hint={!codOk ? t('codDisabled') : undefined} onPress={() => setPayment('cod')} />
        <Option selected={payment === 'online'} title={t('online')} hint={!onlineOk ? t('onlineDisabled') : config?.payments.provider === 'mock' ? `${t('onlineHint')} (TEST MODE)` : t('onlineHint')} disabled={!onlineOk} onPress={() => setPayment('online')} />

        <Card>
          <Text style={{ fontWeight: '800', marginBottom: 6 }}>{t('couponTitle')}</Text>
          {coupon && quote?.coupon?.applied ? (
            <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' }}><Text style={{ color: colors.success, fontWeight: '700', flex: 1 }}>✅ {quote.coupon.code} {t('applied')}</Text><Button variant="ghost" small title={t('remove')} onPress={() => { setCoupon(null); setCouponInput(''); }} /></View>
          ) : (
            <View><View style={{ flexDirection: 'row', alignItems: 'flex-start' }}><Field label="" style={{ flex: 1, marginBottom: 0 } as any} value={couponInput} onChangeText={(v) => setCouponInput(v.toUpperCase())} placeholder={t('couponHint')} autoCapitalize="characters" /><Button title={t('apply')} small style={{ marginLeft: 8, marginTop: 22 }} onPress={applyCoupon} disabled={!couponInput.trim()} /></View>
              {coupon && quote?.coupon?.error ? <Text style={{ color: colors.danger, marginTop: 6 }}>{quote.coupon.error.message}</Text> : null}
              <Pressable onPress={() => router.push('/coupons')} accessibilityRole="link" style={{ minHeight: 40, justifyContent: 'center' }}><Text style={{ color: colors.primary, fontWeight: '700' }}>{t('availableCoupons')} →</Text></Pressable></View>)}
          {quote?.first_order.applied ? <Text style={{ color: colors.success, marginTop: 6, fontWeight: '700' }}>🎉 {t('firstOrder')}: −{formatINR(quote.first_order.discount)}</Text> : null}
        </Card>

        {quote?.coins.enabled ? (
          <Card>
            <Pressable accessibilityRole="switch" accessibilityState={{ checked: useCoins }} onPress={() => setUseCoins((v) => !v)} disabled={!probe.quote || probe.quote.coins.max_usable <= 0} style={{ flexDirection: 'row', alignItems: 'center', minHeight: 48 }}>
              <View style={{ width: 24, height: 24, borderRadius: 6, borderWidth: 2, borderColor: colors.primary, backgroundColor: useCoins ? colors.primary : '#fff', alignItems: 'center', justifyContent: 'center', opacity: (probe.quote?.coins.max_usable ?? 0) > 0 ? 1 : 0.4 }}>{useCoins ? <Text style={{ color: '#fff', fontWeight: '800' }}>✓</Text> : null}</View>
              <View style={{ marginLeft: 12, flex: 1 }}>
                <Text style={{ fontWeight: '800' }}>{t('coinsTitle')} · {t('coinsBalance', { n: quote.coins.balance })}</Text>
                <Text style={{ color: colors.muted, fontSize: 12 }}>{(probe.quote?.coins.max_usable ?? 0) > 0 ? t('coinsUse', { n: probe.quote!.coins.max_usable, amt: formatINR(String(probe.quote!.coins.max_usable * Number(quote.coins.coin_value))) }) : quote.coins.earn_note ?? t('coinsNone')}</Text>
              </View>
            </Pressable>
          </Card>) : null}

        <Field label={t('orderNote')} value={note} onChangeText={setNote} maxLength={300} multiline style={{ marginTop: space.sm } as any} />

        <SectionTitle title={t('billDetails')} />
        <Card>
          {quote ? (
            <>
              <Row label={t('itemsTotal')} value={formatINR(quote.totals.subtotal)} />
              {Number(quote.totals.coupon_discount) > 0 ? <Row label={`${t('couponDiscount')} (${quote.coupon?.code})`} value={`−${formatINR(quote.totals.coupon_discount)}`} color={colors.success} /> : null}
              {Number(quote.totals.first_order_discount) > 0 ? <Row label={t('firstOrder')} value={`−${formatINR(quote.totals.first_order_discount)}`} color={colors.success} /> : null}
              {Number(quote.totals.coin_discount) > 0 ? <Row label={`${t('coinDiscount')} (${quote.coins.applied})`} value={`−${formatINR(quote.totals.coin_discount)}`} color={colors.success} /> : null}
              <Row label={t('deliveryFee')} value={feeText} />
              {fulfilment === 'delivery' && quote.delivery.distance_km !== null ? <Text style={{ color: colors.muted, fontSize: 12 }}>{t('deliveryDistance', { km: quote.delivery.distance_km })}{quote.delivery.method === 'straight_line' ? ` (${t('distanceApprox')})` : ''}{quote.delivery.zone ? ` · ${quote.delivery.zone.name}` : ''}</Text> : null}
              <View style={{ height: 1, backgroundColor: colors.border, marginVertical: 8 }} />
              <Row bold label={t('toPay')} value={quote.totals.total ? formatINR(quote.totals.total) : '—'} />
              {Number(quote.totals.savings) > 0 ? <Text style={{ color: colors.success, fontWeight: '700' }}>{t('savings')} {formatINR(quote.totals.savings)}</Text> : null}
              {quote.coins.will_earn > 0 ? <Text style={{ color: colors.muted, fontSize: 12, marginTop: 4 }}>🪙 {t('coinsWillEarn', { n: quote.coins.will_earn })}</Text> : null}
              <Text style={{ color: colors.muted, fontSize: 12, marginTop: 4 }}>{t('minOrderNote')}</Text>
            </>) : loading ? <Text style={{ color: colors.muted }}>{t('loading')}</Text> : error ? <Text style={{ color: colors.danger }}>{error.isNetwork ? t('errNetwork') : error.message}</Text> : <Text style={{ color: colors.muted }}>{fulfilment === 'delivery' && !effAddressId ? t('noAddress') : ''}</Text>}
        </Card>
        {hardBlockers.map((b, i) => <Text key={i} style={{ color: colors.danger, marginBottom: 6 }}>• {b.message}</Text>)}
        {msg ? <Text accessibilityLiveRegion="assertive" style={{ color: colors.danger, fontWeight: '700', marginTop: 6 }}>{msg}</Text> : null}
      </ScrollView>
      <View style={{ padding: space.md, backgroundColor: '#fff', borderTopWidth: 1, borderTopColor: colors.border }}>
        <Button title={placing ? t('placing') : payment === 'online' && quote?.totals.total ? t('payNow', { amt: formatINR(quote.totals.total) }) : t('placeOrder')} loading={placing} disabled={!canPlace} onPress={() => { if (payment === 'cod' && fulfilment === 'delivery' && Platform.OS !== 'web') Alert.alert(t('placeOrder'), `${t('toPay')}: ${formatINR(quote?.totals.total)}`, [{ text: t('cancel'), style: 'cancel' }, { text: t('placeOrder'), onPress: place }]); else void place(); }} />
      </View>
    </KeyboardAvoidingView>
  );
}
