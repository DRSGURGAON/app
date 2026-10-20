import React from 'react';
import { Alert, Platform, ScrollView, Text, View } from 'react-native';
import { router } from 'expo-router';
import { useI18n } from '../../src/i18n';
import { useCart } from '../../src/state/cart';
import { useQuote } from '../../src/lib/quote';
import { formatINR } from '../../src/lib/money';
import { colors, radius, space } from '../../src/theme';
import { Button, Card, EmptyState, ErrorState, QtyStepper, Row, Skeleton, Thumb } from '../../src/ui/kit';
import { Pressable } from 'react-native';

export default function CartScreen() {
  const { t, pick } = useI18n(); const cart = useCart();
  // Cart review uses pickup pricing (no delivery fee) so it never depends on an address; delivery is priced in checkout.
  const { quote, loading, error, reload } = useQuote({ items: cart.items.map((i) => ({ product_id: i.product_id, qty: i.qty })), fulfilment: 'pickup' }, cart.ready);
  if (!cart.ready) return null;
  if (cart.items.length === 0) return <EmptyState title={t('cartEmpty')} hint={t('cartEmptyHint')} actionLabel={t('startShopping')} onAction={() => router.push('/')} />;
  const lineIssues = quote?.lines.filter((l) => l.issue) ?? [];
  const shortfall = quote && !quote.min_order.met ? quote.min_order.shortfall : null;
  const blocked = !quote || lineIssues.length > 0 || !!shortfall;
  const pct = quote ? Math.min(100, Math.round((Number(quote.min_order.current) / Math.max(Number(quote.min_order.required), 1)) * 100)) : 0;
  return (
    <View style={{ flex: 1 }}>
      <ScrollView contentContainerStyle={{ padding: space.lg, paddingBottom: 24 }}>
        {quote ? (
          <Card style={{ backgroundColor: quote.min_order.met ? colors.primarySoft : colors.accentSoft }}>
            <Text style={{ fontWeight: '800', color: colors.text }}>{quote.min_order.met ? `✅ ${t('minOrderMet')}` : t('minOrderMore', { amt: formatINR(quote.min_order.shortfall) })}</Text>
            <View style={{ height: 8, backgroundColor: '#fff', borderRadius: 4, marginTop: 8, overflow: 'hidden' }} accessibilityRole="progressbar" accessibilityValue={{ min: 0, max: 100, now: pct }}><View style={{ width: `${pct}%`, height: 8, backgroundColor: quote.min_order.met ? colors.primary : colors.accent }} /></View>
            <Text style={{ color: colors.muted, fontSize: 12, marginTop: 6 }}>{t('minOrderTitle', { amt: formatINR(quote.min_order.required) })} · {t('minOrderNote')}</Text>
          </Card>) : loading ? <Skeleton h={80} style={{ marginBottom: 12 }} /> : null}
        {error && !quote ? <ErrorState error={error} onRetry={reload} /> : null}
        {cart.items.map((it) => {
          const line = quote?.lines.find((l) => l.product_id === it.product_id);
          const price = line?.unit_price ?? it.price; const name = pick(line?.name ?? it.name, line?.name_hi ?? it.name_hi);
          return (
            <Card key={it.product_id} style={{ padding: space.md }}>
              <View style={{ flexDirection: 'row' }}>
                <Thumb uri={line?.image_url ?? it.image_url} size={64} />
                <View style={{ flex: 1, marginLeft: space.md }}>
                  <Text style={{ fontWeight: '700', color: colors.text }} numberOfLines={2}>{name}</Text>
                  <Text style={{ color: colors.muted, fontSize: 12 }}>{it.pack_size ?? (it.unit && it.unit !== 'pc' ? it.unit : '')}</Text>
                  <Text style={{ fontWeight: '800', marginTop: 4 }}>{formatINR(price)} × {it.qty} = {formatINR(line ? line.line_total : String(Number(price) * it.qty))}</Text>
                </View>
              </View>
              {line?.issue ? <View style={{ marginTop: 8, padding: 8, borderRadius: radius.sm, backgroundColor: colors.dangerSoft }}><Text style={{ color: colors.danger }}>{line.issue.message}</Text></View> : null}
              <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginTop: space.sm }}>
                <QtyStepper qty={it.qty} max={it.max_per_order ?? undefined} onChange={(q) => cart.setQty(it.product_id, q)} />
                <Pressable accessibilityRole="button" accessibilityLabel={`${t('remove')} ${name}`} onPress={() => cart.remove(it.product_id)} style={{ minHeight: 48, justifyContent: 'center', paddingHorizontal: 8 }}><Text style={{ color: colors.danger, fontWeight: '700' }}>{t('remove')}</Text></Pressable>
              </View>
            </Card>);
        })}
        {quote ? (
          <Card>
            <Row label={t('itemsTotal')} value={formatINR(quote.totals.subtotal)} />
            {Number(quote.totals.savings) > 0 ? <Row label={t('savings')} value={formatINR(quote.totals.savings)} color={colors.success} /> : null}
            <Text style={{ color: colors.muted, fontSize: 12, marginTop: 4 }}>{t('deliveryAtCheckout')}</Text>
          </Card>) : null}
        <Pressable accessibilityRole="button" onPress={() => (Platform.OS === 'web' ? cart.clear() : Alert.alert(t('clearCart'), t('clearCartConfirm'), [{ text: t('cancel'), style: 'cancel' }, { text: t('clearCart'), style: 'destructive', onPress: cart.clear }]))} style={{ minHeight: 48, alignItems: 'center', justifyContent: 'center' }}><Text style={{ color: colors.muted }}>{t('clearCart')}</Text></Pressable>
      </ScrollView>
      <View style={{ padding: space.md, backgroundColor: '#fff', borderTopWidth: 1, borderTopColor: colors.border }}>
        {shortfall ? <Text style={{ color: colors.warn, textAlign: 'center', marginBottom: 6, fontWeight: '600' }}>{t('minOrderMore', { amt: formatINR(shortfall) })}</Text> : null}
        <Button title={quote ? `${t('proceed')} · ${formatINR(quote.totals.subtotal)}` : t('proceed')} disabled={blocked} loading={loading && !quote} onPress={() => router.push('/checkout')} />
      </View>
    </View>
  );
}
