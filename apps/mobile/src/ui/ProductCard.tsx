import React from 'react';
import { Pressable, Text, View } from 'react-native';
import { router } from 'expo-router';
import { colors, radius, space } from '../theme';
import { useI18n } from '../i18n';
import { useCart } from '../state/cart';
import { Button, Price, QtyStepper, Thumb, s } from './kit';

export interface ProductDto { id: string; name: string; name_hi: string | null; brand: string | null; unit: string; pack_size: string | null; mrp: string; price: string; discount_percent: number; stock_status: 'in_stock' | 'low_stock' | 'out_of_stock'; available: number; max_per_order: number | null; image_url: string | null; thumb_url: string | null }

export function toCartSnapshot(p: ProductDto) { return { product_id: p.id, name: p.name, name_hi: p.name_hi, price: p.price, unit: p.unit, pack_size: p.pack_size, image_url: p.thumb_url ?? p.image_url, max_per_order: Math.min(p.max_per_order ?? 99, Math.max(p.available, 0)) || null }; }

export function ProductCard({ p }: { p: ProductDto }) {
  const { t, pick } = useI18n(); const cart = useCart(); const qty = cart.qtyOf(p.id); const out = p.stock_status === 'out_of_stock';
  const name = pick(p.name, p.name_hi); const cap = Math.min(p.max_per_order ?? 99, p.available);
  return (
    <View style={s.gridCell}>
      <View style={s.pCard}>
        <Pressable accessibilityRole="button" accessibilityLabel={`${name}, ${p.price} rupees`} onPress={() => router.push({ pathname: '/product/[id]', params: { id: p.id } })}>
          <View style={{ alignItems: 'center', opacity: out ? 0.5 : 1 }}>
            <Thumb uri={p.thumb_url ?? p.image_url} size={110} />
            {p.discount_percent > 0 && !out ? <View style={{ position: 'absolute', top: 0, left: 0, backgroundColor: colors.accent, paddingHorizontal: 6, paddingVertical: 2, borderRadius: radius.sm }}><Text style={{ fontWeight: '800', fontSize: 11 }}>{t('off', { n: p.discount_percent })}</Text></View> : null}
          </View>
          <Text numberOfLines={2} style={{ marginTop: space.sm, fontWeight: '600', color: colors.text, minHeight: 38 }}>{name}</Text>
          <Text style={{ color: colors.muted, fontSize: 12, marginBottom: 4 }} numberOfLines={1}>{p.pack_size ?? p.unit}</Text>
          <Price price={p.price} mrp={p.mrp} />
          {p.stock_status === 'low_stock' ? <Text style={{ color: colors.warn, fontSize: 12, marginTop: 2 }}>{t('lowStock', { n: p.available })}</Text> : null}
        </Pressable>
        <View style={{ marginTop: space.sm, alignItems: 'stretch' }}>
          {out ? <Text style={{ color: colors.danger, fontWeight: '700', textAlign: 'center', paddingVertical: 10 }}>{t('outOfStock')}</Text>
            : qty > 0 ? <View style={{ alignItems: 'center' }}><QtyStepper qty={qty} max={cap} onChange={(q) => cart.setQty(p.id, q)} /></View>
            : <Button small variant="secondary" title={t('add')} accessibilityLabel={`${t('add')} ${name}`} onPress={() => cart.add(toCartSnapshot(p))} />}
        </View>
      </View>
    </View>
  );
}
