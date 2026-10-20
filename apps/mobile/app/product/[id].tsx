import React, { useState } from 'react';
import { Image, Pressable, ScrollView, Text, View, useWindowDimensions } from 'react-native';
import { Stack, useLocalSearchParams, router } from 'expo-router';
import { SafeAreaView } from 'react-native-safe-area-context';
import { api } from '../../src/lib/api';
import { useAsync } from '../../src/lib/useAsync';
import { useI18n } from '../../src/i18n';
import { useCart } from '../../src/state/cart';
import { colors, radius, space } from '../../src/theme';
import { Button, Card, ErrorState, Price, QtyStepper, SectionTitle, Skeleton, Thumb } from '../../src/ui/kit';
import { ProductCard, toCartSnapshot, type ProductDto } from '../../src/ui/ProductCard';

interface Detail extends ProductDto { description: string | null; sku: string; tax_rate: string; images: { id: string; url: string }[]; category: { slug: string; name: string } }

export default function ProductScreen() {
  const { id } = useLocalSearchParams<{ id: string }>(); const { t, pick } = useI18n(); const cart = useCart(); const { width } = useWindowDimensions();
  const p = useAsync((signal) => api<{ product: Detail }>(`/v1/products/${id}`, { auth: false, signal }), [id]);
  const sim = useAsync((signal) => api<{ items: ProductDto[] }>(`/v1/products/${id}/similar`, { auth: false, signal }), [id]);
  const [idx, setIdx] = useState(0); const [justAdded, setJustAdded] = useState(false);
  if (p.loading && !p.data) return <View style={{ padding: space.lg }}><Skeleton h={260} /><Skeleton h={24} style={{ marginTop: 16 }} /><Skeleton h={24} w="40%" style={{ marginTop: 8 }} /></View>;
  if (p.error || !p.data) return <ErrorState error={p.error ?? { message: t('noResults') }} onRetry={p.reload} />;
  const d = p.data.product; const name = pick(d.name, d.name_hi); const qty = cart.qtyOf(d.id); const out = d.stock_status === 'out_of_stock'; const cap = Math.min(d.max_per_order ?? 99, d.available);
  const imgs = d.images.length ? d.images : d.image_url ? [{ id: 'x', url: d.image_url }] : [];
  return (
    <SafeAreaView edges={['bottom']} style={{ flex: 1 }}>
      <Stack.Screen options={{ title: pick(d.category?.name, null) }} />
      <ScrollView contentContainerStyle={{ paddingBottom: 24 }}>
        <View style={{ backgroundColor: '#fff' }}>
          {imgs.length ? (
            <>
              <ScrollView horizontal pagingEnabled showsHorizontalScrollIndicator={false} onMomentumScrollEnd={(e) => setIdx(Math.round(e.nativeEvent.contentOffset.x / width))}>
                {imgs.map((im) => <Image key={im.id} source={{ uri: im.url }} accessibilityLabel={name} style={{ width, height: 300 }} resizeMode="contain" />)}
              </ScrollView>
              {imgs.length > 1 ? <View style={{ flexDirection: 'row', justifyContent: 'center', paddingBottom: 8 }}>{imgs.map((_, i) => <View key={i} style={{ width: 8, height: 8, borderRadius: 4, margin: 3, backgroundColor: i === idx ? colors.primary : colors.border }} />)}</View> : null}
            </>) : <View style={{ alignItems: 'center', padding: space.xl }}><Thumb size={200} /></View>}
        </View>
        <View style={{ padding: space.lg }}>
          {d.brand ? <Text style={{ color: colors.primary, fontWeight: '700' }}>{d.brand}</Text> : null}
          <Text accessibilityRole="header" style={{ fontSize: 22, fontWeight: '800', color: colors.text, marginTop: 2 }}>{name}</Text>
          <Text style={{ color: colors.muted, marginTop: 2 }}>{d.pack_size ?? d.unit}</Text>
          <View style={{ marginTop: space.md, flexDirection: 'row', alignItems: 'center' }}>
            <Price price={d.price} mrp={d.mrp} size={26} />
            {d.discount_percent > 0 ? <View style={{ marginLeft: 10, backgroundColor: colors.accent, borderRadius: radius.sm, paddingHorizontal: 8, paddingVertical: 2 }}><Text style={{ fontWeight: '800' }}>{t('off', { n: d.discount_percent })}</Text></View> : null}
          </View>
          <Text style={{ color: colors.muted, fontSize: 12, marginTop: 2 }}>{t('inclTax')}</Text>
          <Text style={{ marginTop: space.md, fontWeight: '700', color: out ? colors.danger : d.stock_status === 'low_stock' ? colors.warn : colors.success }}>{out ? t('outOfStock') : d.stock_status === 'low_stock' ? t('lowStock', { n: d.available }) : t('inStock')}</Text>
          {d.max_per_order ? <Text style={{ color: colors.muted, fontSize: 12 }}>{t('maxPerOrder', { n: d.max_per_order })}</Text> : null}
          {d.description ? <Card style={{ marginTop: space.lg }}><Text style={{ fontWeight: '800', marginBottom: 6 }}>{t('description')}</Text><Text style={{ color: colors.text, lineHeight: 21 }}>{d.description}</Text></Card> : null}
        </View>
        {sim.data?.items.length ? <><SectionTitle title={t('similar')} /><ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ paddingHorizontal: space.sm }}>{sim.data.items.map((s) => <View key={s.id} style={{ width: 170 }}><ProductCard p={s} /></View>)}</ScrollView></> : null}
      </ScrollView>
      <View style={{ padding: space.md, backgroundColor: '#fff', borderTopWidth: 1, borderTopColor: colors.border, flexDirection: 'row', alignItems: 'center' }}>
        {out ? <Text style={{ flex: 1, textAlign: 'center', color: colors.danger, fontWeight: '800', fontSize: 16 }}>{t('outOfStock')}</Text> : qty > 0 ? (
          <><QtyStepper qty={qty} max={cap} onChange={(q) => cart.setQty(d.id, q)} /><Button title={t('tabCart')} style={{ flex: 1, marginLeft: space.md }} onPress={() => router.push('/cart')} /></>
        ) : <Button title={justAdded ? t('added') : t('add')} style={{ flex: 1 }} onPress={() => { cart.add(toCartSnapshot(d)); setJustAdded(true); setTimeout(() => setJustAdded(false), 1200); }} />}
      </View>
    </SafeAreaView>
  );
}
