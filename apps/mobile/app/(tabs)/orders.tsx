import React, { useCallback } from 'react';
import { FlatList, Pressable, RefreshControl, Text, View } from 'react-native';
import { router, useFocusEffect } from 'expo-router';
import { api } from '../../src/lib/api';
import { useAsync } from '../../src/lib/useAsync';
import { formatINR } from '../../src/lib/money';
import { useI18n } from '../../src/i18n';
import { useAuth } from '../../src/state/auth';
import { colors, radius, space } from '../../src/theme';
import { EmptyState, ErrorState, Skeleton } from '../../src/ui/kit';
import { fmtDate, STATUS_KEY, statusColor } from '../../src/ui/status';

interface O { id: string; order_no: string; status: string; fulfilment_type: string; payment_method: string; payment_status: string; total: string; placed_at: string; item_count: number; preview: string | null }
export default function OrdersScreen() {
  const { t, lang } = useI18n(); const { user, ready } = useAuth();
  const q = useAsync((signal) => api<{ orders: O[] }>('/v1/orders?limit=30', { signal }), [user?.id], !!user);
  useFocusEffect(useCallback(() => { if (user) void q.reload(); // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user?.id]));
  if (!ready) return null;
  if (!user) return <EmptyState icon="🔐" title={t('loginNeededOrders')} actionLabel={t('login')} onAction={() => router.push('/login')} />;
  if (q.loading && !q.data) return <View style={{ padding: space.lg }}>{[0, 1, 2].map((i) => <Skeleton key={i} h={96} style={{ marginBottom: 12 }} />)}</View>;
  if (q.error && !q.data) return <ErrorState error={q.error} onRetry={q.reload} />;
  return (
    <FlatList data={q.data?.orders ?? []} keyExtractor={(o) => o.id} contentContainerStyle={{ padding: space.lg, flexGrow: 1 }} refreshControl={<RefreshControl refreshing={q.loading} onRefresh={q.reload} colors={[colors.primary]} />}
      ListEmptyComponent={<EmptyState icon="🧾" title={t('noOrders')} hint={t('noOrdersHint')} actionLabel={t('startShopping')} onAction={() => router.push('/')} />}
      renderItem={({ item: o }) => (
        <Pressable accessibilityRole="button" accessibilityLabel={`${t('orderNo', { n: o.order_no })}, ${t(STATUS_KEY[o.status] ?? 'statusPlaced')}`} onPress={() => router.push({ pathname: '/order/[id]', params: { id: o.id } })} style={{ backgroundColor: '#fff', borderRadius: radius.lg, padding: space.lg, borderWidth: 1, borderColor: colors.border, marginBottom: space.md }}>
          <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}><Text style={{ fontWeight: '800' }}>{t('orderNo', { n: o.order_no })}</Text><Text style={{ fontWeight: '800', color: statusColor(o.status) }}>{t(STATUS_KEY[o.status] ?? 'statusPlaced')}</Text></View>
          <Text style={{ color: colors.muted, marginTop: 2 }}>{fmtDate(o.placed_at, lang)} · {t('items', { n: o.item_count })} · {o.fulfilment_type === 'pickup' ? t('storePickup') : t('homeDelivery')}</Text>
          {o.preview ? <Text numberOfLines={1} style={{ marginTop: 4, color: colors.text }}>{o.preview}</Text> : null}
          <Text style={{ marginTop: 6, fontWeight: '800', fontSize: 16 }}>{formatINR(o.total)}</Text>
        </Pressable>)} />
  );
}
