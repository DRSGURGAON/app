import React, { useCallback } from 'react';
import { FlatList, Pressable, Text, View } from 'react-native';
import { router, useFocusEffect } from 'expo-router';
import { api } from '../src/lib/api';
import { useAsync } from '../src/lib/useAsync';
import { useI18n } from '../src/i18n';
import { useAuth } from '../src/state/auth';
import { colors, space } from '../src/theme';
import { Button, EmptyState, ErrorState } from '../src/ui/kit';
import { fmtDate } from '../src/ui/status';

export default function NotificationsScreen() {
  const { t, lang } = useI18n(); const { user } = useAuth();
  const q = useAsync((signal) => api<{ notifications: any[]; unread: number }>('/v1/notifications', { signal }), [user?.id], !!user);
  useFocusEffect(useCallback(() => { if (user) void q.reload(); // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user?.id]));
  if (!user) return <EmptyState icon="🔐" title={t('loginNeeded')} actionLabel={t('login')} onAction={() => router.push('/login')} />;
  if (q.error && !q.data) return <ErrorState error={q.error} onRetry={q.reload} />;
  const open = async (n: any) => { if (!n.read_at) void api(`/v1/notifications/${n.id}/read`, { method: 'POST' }).then(q.reload); if (n.data?.order_id) router.push({ pathname: '/order/[id]', params: { id: n.data.order_id } }); };
  return (
    <FlatList data={q.data?.notifications ?? []} keyExtractor={(n) => n.id} contentContainerStyle={{ padding: space.lg, flexGrow: 1 }} ListEmptyComponent={q.loading ? undefined : <EmptyState icon="🔔" title={t('noNotifications')} />}
      ListHeaderComponent={q.data?.unread ? <Button small variant="ghost" title={t('markAllRead')} onPress={() => api('/v1/notifications/read-all', { method: 'POST' }).then(q.reload)} style={{ marginBottom: 8, alignSelf: 'flex-end' }} /> : undefined}
      renderItem={({ item: n }) => (<Pressable accessibilityRole="button" onPress={() => open(n)} style={{ padding: space.md, backgroundColor: n.read_at ? '#fff' : colors.primarySoft, borderRadius: 12, marginBottom: 8, borderWidth: 1, borderColor: colors.border }}><Text style={{ fontWeight: '800' }}>{n.title}</Text><Text style={{ color: colors.text, marginTop: 2 }}>{n.body}</Text><Text style={{ color: colors.muted, fontSize: 12, marginTop: 4 }}>{fmtDate(n.created_at, lang)}</Text></Pressable>)} />
  );
}
void View;
