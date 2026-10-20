import React from 'react';
import { FlatList, Pressable, Text, View } from 'react-native';
import { router } from 'expo-router';
import * as Clipboard from 'expo-clipboard';
import { api } from '../src/lib/api';
import { useAsync } from '../src/lib/useAsync';
import { formatINR } from '../src/lib/money';
import { useI18n } from '../src/i18n';
import { useStoreConfig } from '../src/state/storeConfig';
import { colors, radius, space } from '../src/theme';
import { Card, EmptyState, ErrorState } from '../src/ui/kit';

export default function CouponsScreen() {
  const { t, lang } = useI18n(); const { config } = useStoreConfig(); const [copied, setCopied] = React.useState<string | null>(null);
  const q = useAsync((signal) => api<{ coupons: any[] }>('/v1/coupons', { auth: false, signal }), []);
  const bn = useAsync((signal) => api<{ banners: any[] }>('/v1/banners', { auth: false, signal }), []);
  if (q.error && !q.data) return <ErrorState error={q.error} onRetry={q.reload} />;
  const fo = config?.first_order?.enabled ? (config.first_order as any) : null;
  return (
    <FlatList data={q.data?.coupons ?? []} keyExtractor={(c) => c.code} contentContainerStyle={{ padding: space.lg, flexGrow: 1 }}
      ListHeaderComponent={<View>
        {fo ? <Card style={{ backgroundColor: colors.accentSoft }}><Text style={{ fontWeight: '800' }}>🎉 {t('firstOrder')}</Text><Text style={{ color: colors.text }}>{fo.type === 'percent' ? `${fo.value}%` : formatINR(fo.value)}{fo.min_spend ? ` · ${t('minSpend', { amt: formatINR(fo.min_spend) })}` : ''}</Text></Card> : null}
        {bn.data?.banners.filter((b) => b.terms).map((b) => <Card key={b.id}><Text style={{ fontWeight: '800' }}>{b.festival ? `${b.festival} · ` : ''}{b.title}</Text><Text style={{ color: colors.muted, marginTop: 2 }}>{b.terms}</Text></Card>)}
      </View>}
      ListEmptyComponent={q.loading ? undefined : <EmptyState icon="🎟️" title={t('noCoupons')} />}
      renderItem={({ item: c }) => (
        <Card>
          <View style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' }}>
            <View style={{ flex: 1 }}><Text style={{ fontWeight: '800', fontSize: 16 }}>{c.title}</Text>{c.description ? <Text style={{ color: colors.muted }}>{c.description}</Text> : null}</View>
            <Pressable accessibilityRole="button" accessibilityLabel={`Copy code ${c.code}`} onPress={async () => { await Clipboard.setStringAsync(c.code); setCopied(c.code); }} style={{ borderWidth: 2, borderStyle: 'dashed', borderColor: colors.primary, borderRadius: radius.md, paddingHorizontal: 12, minHeight: 44, justifyContent: 'center' }}><Text style={{ fontWeight: '800', color: colors.primary }}>{copied === c.code ? '✓ ' : ''}{c.code}</Text></Pressable>
          </View>
          <Text style={{ color: colors.text, marginTop: 6 }}>{c.discount_type === 'percent' ? `${Number(c.discount_value)}% off` : `${formatINR(c.discount_value)} off`}{Number(c.min_spend) > 0 ? ` · ${t('minSpend', { amt: formatINR(c.min_spend) })}` : ''}{c.max_discount ? ` · max ${formatINR(c.max_discount)}` : ''}</Text>
          <Text style={{ color: colors.muted, fontSize: 12 }}>{t('validTill', { d: new Date(c.ends_at).toLocaleDateString(lang === 'hi' ? 'hi-IN' : 'en-IN', { day: 'numeric', month: 'short', year: 'numeric' }) })}</Text>
        </Card>)}
      ListFooterComponent={<Pressable onPress={() => router.push('/cart')} style={{ minHeight: 48, justifyContent: 'center', alignItems: 'center' }}><Text style={{ color: colors.primary, fontWeight: '700' }}>{t('tabCart')} →</Text></Pressable>} />
  );
}
