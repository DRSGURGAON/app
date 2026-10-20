import React from 'react';
import { Image, Linking, Pressable, RefreshControl, ScrollView, Text, View, useWindowDimensions } from 'react-native';
import { router } from 'expo-router';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';
import { api } from '../../src/lib/api';
import { useAsync } from '../../src/lib/useAsync';
import { useI18n } from '../../src/i18n';
import { useStoreConfig } from '../../src/state/storeConfig';
import { colors, radius, space } from '../../src/theme';
import { EmptyState, ErrorState, SectionTitle, Skeleton, Thumb } from '../../src/ui/kit';
import { ProductCard, type ProductDto } from '../../src/ui/ProductCard';

interface Banner { id: string; title: string; subtitle: string | null; image_url: string | null; festival: string | null; link_type: 'none' | 'category' | 'product' | 'coupon'; link_ref: string | null }
interface Cat { id: string; name: string; name_hi: string | null; slug: string; image_url: string | null }
interface Home { banners: Banner[]; categories: Cat[]; featured: ProductDto[]; best_sellers: ProductDto[] }

function openBanner(b: Banner) {
  if (b.link_type === 'category' && b.link_ref) router.push({ pathname: '/products', params: { category: b.link_ref, title: b.title } });
  else if (b.link_type === 'product' && b.link_ref) router.push({ pathname: '/product/[id]', params: { id: b.link_ref } });
  else if (b.link_type === 'coupon') router.push('/coupons');
}

export default function HomeScreen() {
  const { t, pick } = useI18n(); const { config } = useStoreConfig(); const { width } = useWindowDimensions();
  const home = useAsync((signal) => api<Home>('/v1/home', { auth: false, signal }), []);
  const h = home.data;
  const closed = config && !config.store.open_now;
  return (
    <SafeAreaView edges={['top']} style={{ flex: 1, backgroundColor: colors.primary }}>
      <View style={{ backgroundColor: colors.primary, paddingHorizontal: space.lg, paddingBottom: space.md }}>
        <Text accessibilityRole="header" style={{ color: '#fff', fontSize: 20, fontWeight: '800' }} numberOfLines={1}>{pick(config?.store.name_en ?? t('appName'), config?.store.name_hi)}</Text>
        <View style={{ flexDirection: 'row', alignItems: 'center', marginTop: 2 }}>
          <View style={{ width: 8, height: 8, borderRadius: 4, backgroundColor: closed ? '#FFB4AB' : '#7CE38B', marginRight: 6 }} />
          <Text style={{ color: '#E8F3E9', fontSize: 13 }}>{closed ? t('storeClosed') : t('storeOpen')}{config ? ` · ${config.store.open_time}–${config.store.close_time}` : ''}</Text>
        </View>
        <Pressable accessibilityRole="search" accessibilityLabel={t('search')} onPress={() => router.push('/search')} style={{ marginTop: space.md, minHeight: 48, backgroundColor: '#fff', borderRadius: radius.md, flexDirection: 'row', alignItems: 'center', paddingHorizontal: space.md }}>
          <Ionicons name="search" size={20} color={colors.muted} /><Text style={{ marginLeft: 8, color: colors.muted, fontSize: 15 }}>{t('searchHint')}</Text>
        </Pressable>
      </View>
      <View style={{ flex: 1, backgroundColor: colors.bg }}>
        {home.loading && !h ? (
          <View style={{ padding: space.lg }}><Skeleton h={140} /><View style={{ flexDirection: 'row', marginTop: space.lg }}>{[0, 1, 2, 3].map((i) => <Skeleton key={i} h={72} w={72} style={{ marginRight: 12, borderRadius: 36 }} />)}</View><Skeleton h={180} style={{ marginTop: space.lg }} /></View>
        ) : home.error && !h ? <ErrorState error={home.error} onRetry={home.reload} /> : h ? (
          <ScrollView contentContainerStyle={{ paddingBottom: 40 }} refreshControl={<RefreshControl refreshing={home.loading} onRefresh={home.reload} colors={[colors.primary]} />}>
            {closed ? <View style={{ margin: space.lg, padding: space.md, backgroundColor: colors.dangerSoft, borderRadius: radius.md }}><Text style={{ color: colors.danger, fontWeight: '700' }}>{config!.store.closed_message}</Text></View> : null}
            {h.banners.length ? (
              <ScrollView horizontal pagingEnabled={false} showsHorizontalScrollIndicator={false} contentContainerStyle={{ padding: space.lg }} snapToInterval={width - 40} decelerationRate="fast">
                {h.banners.map((b) => (
                  <Pressable key={b.id} accessibilityRole="button" accessibilityLabel={b.title} onPress={() => openBanner(b)} style={{ width: width - 56, marginRight: 12, borderRadius: radius.lg, overflow: 'hidden', backgroundColor: colors.primary, minHeight: 130 }}>
                    {b.image_url ? <Image source={{ uri: b.image_url }} style={{ position: 'absolute', width: '100%', height: '100%' }} resizeMode="cover" /> : null}
                    <View style={{ padding: space.lg, flex: 1, justifyContent: 'flex-end', backgroundColor: b.image_url ? 'rgba(0,0,0,0.30)' : 'transparent' }}>
                      {b.festival ? <Text style={{ color: colors.accent, fontWeight: '800', fontSize: 12 }}>{b.festival}</Text> : null}
                      <Text style={{ color: '#fff', fontSize: 20, fontWeight: '800' }}>{b.title}</Text>
                      {b.subtitle ? <Text style={{ color: '#F1F5F1', marginTop: 2 }}>{b.subtitle}</Text> : null}
                    </View>
                  </Pressable>))}
              </ScrollView>) : null}

            <SectionTitle title={t('shopByCategory')} action={t('viewAll')} onAction={() => router.push('/categories')} />
            <View style={{ flexDirection: 'row', flexWrap: 'wrap', paddingHorizontal: space.sm }}>
              {h.categories.map((c) => (
                <Pressable key={c.id} accessibilityRole="button" accessibilityLabel={pick(c.name, c.name_hi)} onPress={() => router.push({ pathname: '/products', params: { category: c.slug, title: pick(c.name, c.name_hi) } })} style={{ width: '33.33%', alignItems: 'center', padding: space.sm }}>
                  <View style={{ width: 68, height: 68, borderRadius: 34, backgroundColor: colors.primarySoft, alignItems: 'center', justifyContent: 'center', overflow: 'hidden' }}>{c.image_url ? <Thumb uri={c.image_url} size={68} radiusPx={34} /> : <Text style={{ fontSize: 28 }}>{emojiFor(c.name)}</Text>}</View>
                  <Text numberOfLines={2} style={{ textAlign: 'center', fontSize: 12, marginTop: 6, fontWeight: '600', color: colors.text }}>{pick(c.name, c.name_hi)}</Text>
                </Pressable>))}
            </View>

            <Pressable accessibilityRole="button" onPress={() => router.push('/coupons')} style={{ marginHorizontal: space.lg, marginTop: space.md, padding: space.lg, borderRadius: radius.lg, backgroundColor: colors.accentSoft, flexDirection: 'row', alignItems: 'center' }}>
              <Text style={{ fontSize: 26 }}>🎟️</Text><Text style={{ marginLeft: 12, fontWeight: '800', fontSize: 16, flex: 1 }}>{t('offers')}</Text><Ionicons name="chevron-forward" size={20} color={colors.text} />
            </Pressable>

            {h.featured.length ? <><SectionTitle title={t('featured')} /><Rail items={h.featured} /></> : null}
            <SectionTitle title={t('bestSellers')} />
            {h.best_sellers.length ? <Rail items={h.best_sellers} /> : <Text style={{ paddingHorizontal: space.lg, color: colors.muted }}>{t('noBestSellers')}</Text>}
            {!h.featured.length && !h.best_sellers.length && !h.categories.length ? <EmptyState title={t('noResults')} /> : null}
          </ScrollView>) : null}
      </View>
    </SafeAreaView>
  );
}

function Rail({ items }: { items: ProductDto[] }) {
  return (<ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ paddingHorizontal: space.sm }}>{items.map((p) => <View key={p.id} style={{ width: 170 }}><ProductCard p={p} /></View>)}</ScrollView>);
}
export function emojiFor(name: string): string {
  const n = name.toLowerCase();
  if (n.includes('dry')) return '🥜';
  if (n.includes('grocery')) return '🌾'; if (n.includes('bakery') || n.includes('snack')) return '🍪'; if (n.includes('drink') || n.includes('chocolate')) return '🥤'; if (n.includes('cosmetic') || n.includes('care') && !n.includes('baby')) return '🧴';
  if (n.includes('baby')) return '🍼'; if (n.includes('house') || n.includes('clean')) return '🧹'; if (n.includes('electric')) return '💡'; if (n.includes('dry')) return '🥜'; if (n.includes('stationery') || n.includes('school')) return '✏️'; return '🛍️';
}
void Linking;
