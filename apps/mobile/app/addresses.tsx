import React, { useCallback } from 'react';
import { Alert, FlatList, Platform, Text, View } from 'react-native';
import { router, useFocusEffect } from 'expo-router';
import { api, ApiError } from '../src/lib/api';
import { useAsync } from '../src/lib/useAsync';
import { useI18n } from '../src/i18n';
import { useAuth } from '../src/state/auth';
import { colors, space } from '../src/theme';
import { Button, Card, EmptyState, ErrorState } from '../src/ui/kit';

export default function AddressesScreen() {
  const { t } = useI18n(); const { user } = useAuth();
  const q = useAsync((signal) => api<{ addresses: any[] }>('/v1/addresses', { signal }), [user?.id], !!user);
  useFocusEffect(useCallback(() => { if (user) void q.reload(); // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user?.id]));
  if (!user) return <EmptyState icon="🔐" title={t('loginNeeded')} actionLabel={t('login')} onAction={() => router.push('/login')} />;
  if (q.error && !q.data) return <ErrorState error={q.error} onRetry={q.reload} />;
  const del = (id: string) => { const run = async () => { try { await api(`/v1/addresses/${id}`, { method: 'DELETE' }); await q.reload(); } catch (e) { Alert.alert(e instanceof ApiError ? e.message : t('errGeneric')); } }; if (Platform.OS === 'web') void run(); else Alert.alert(t('deleteAddressConfirm'), '', [{ text: t('cancel'), style: 'cancel' }, { text: t('delete'), style: 'destructive', onPress: run }]); };
  return (
    <View style={{ flex: 1 }}>
      <FlatList data={q.data?.addresses ?? []} keyExtractor={(a) => a.id} contentContainerStyle={{ padding: space.lg, flexGrow: 1 }} ListEmptyComponent={q.loading ? undefined : <EmptyState icon="📍" title={t('noAddresses')} />}
        renderItem={({ item: a }) => (
          <Card>
            <Text style={{ fontWeight: '800' }}>{a.label}{a.is_default ? ` · ${t('default')}` : ''}</Text><Text style={{ marginTop: 2 }}>{a.full_name} · {a.phone}</Text>
            <Text style={{ color: colors.text }}>{[a.line1, a.line2, a.landmark, `${a.city} ${a.pincode}`].filter(Boolean).join(', ')}</Text>
            <View style={{ flexDirection: 'row', marginTop: 10 }}><Button small variant="secondary" title={t('edit')} onPress={() => router.push({ pathname: '/address-edit', params: { id: a.id } })} /><Button small variant="ghost" title={t('delete')} style={{ marginLeft: 8 }} onPress={() => del(a.id)} /></View>
          </Card>)} />
      <View style={{ padding: space.md, backgroundColor: '#fff', borderTopWidth: 1, borderTopColor: colors.border }}><Button title={t('addAddress')} onPress={() => router.push('/address-edit')} /></View>
    </View>
  );
}
