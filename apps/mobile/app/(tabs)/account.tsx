import React from 'react';
import { Alert, Linking, Platform, Pressable, ScrollView, Text, View } from 'react-native';
import { router } from 'expo-router';
import Constants from 'expo-constants';
import { Ionicons } from '@expo/vector-icons';
import { useI18n } from '../../src/i18n';
import { useAuth } from '../../src/state/auth';
import { useStoreConfig } from '../../src/state/storeConfig';
import { colors, radius, space } from '../../src/theme';
import { Button, Chip, EmptyState } from '../../src/ui/kit';

function Item({ icon, label, onPress, danger }: { icon: React.ComponentProps<typeof Ionicons>['name']; label: string; onPress: () => void; danger?: boolean }) {
  return (<Pressable accessibilityRole="button" onPress={onPress} style={{ minHeight: 52, flexDirection: 'row', alignItems: 'center', paddingHorizontal: space.lg, borderBottomWidth: 1, borderBottomColor: '#EEF1EC', backgroundColor: '#fff' }}>
    <Ionicons name={icon} size={22} color={danger ? colors.danger : colors.primary} /><Text style={{ flex: 1, marginLeft: 14, fontSize: 16, color: danger ? colors.danger : colors.text }}>{label}</Text><Ionicons name="chevron-forward" size={18} color={colors.muted} /></Pressable>);
}
export default function AccountScreen() {
  const { t, lang, setLang } = useI18n(); const { user, ready, logout } = useAuth(); const { config } = useStoreConfig();
  const confirmLogout = () => { if (Platform.OS === 'web') { void logout(); return; } Alert.alert(t('logout'), t('logoutConfirm'), [{ text: t('cancel'), style: 'cancel' }, { text: t('logout'), style: 'destructive', onPress: () => void logout() }]); };
  if (!ready) return null;
  return (
    <ScrollView contentContainerStyle={{ paddingBottom: 40 }}>
      <View style={{ padding: space.lg, backgroundColor: colors.primarySoft }}>
        <Text style={{ fontSize: 20, fontWeight: '800', color: colors.text }}>{user ? t('hello', { n: user.name ?? `+91 ${user.phone}` }) : t('guest')}</Text>
        {user ? <Text style={{ color: colors.muted }}>+91 {user.phone}</Text> : <Button title={t('login')} style={{ marginTop: 10, alignSelf: 'flex-start', minWidth: 160 }} onPress={() => router.push('/login')} />}
      </View>
      <View style={{ flexDirection: 'row', alignItems: 'center', padding: space.lg }}><Text style={{ fontWeight: '700', marginRight: 12 }}>{t('language')}</Text><Chip label={t('hindi')} selected={lang === 'hi'} onPress={() => { setLang('hi'); }} /><Chip label={t('english')} selected={lang === 'en'} onPress={() => setLang('en')} /></View>
      <View style={{ borderTopWidth: 1, borderTopColor: colors.border }}>
        {user ? <>
          <Item icon="person-outline" label={t('profile')} onPress={() => router.push('/profile')} />
          <Item icon="location-outline" label={t('addresses')} onPress={() => router.push('/addresses')} />
          <Item icon="wallet-outline" label={t('wallet')} onPress={() => router.push('/wallet')} />
          <Item icon="notifications-outline" label={t('notifications')} onPress={() => router.push('/notifications')} />
        </> : null}
        <Item icon="pricetags-outline" label={t('offers')} onPress={() => router.push('/coupons')} />
        {config?.store.phone ? <Item icon="call-outline" label={`${t('contactStore')} · ${config.store.phone}`} onPress={() => void Linking.openURL(`tel:${config.store.phone}`)} /> : null}
        {(['privacy', 'terms', 'delivery', 'cancellation', 'refund'] as const).map((k) => <Item key={k} icon="document-text-outline" label={t(({ privacy: 'privacy', terms: 'terms', delivery: 'deliveryPolicy', cancellation: 'cancellationPolicy', refund: 'refundPolicy' } as const)[k])} onPress={() => router.push({ pathname: '/policy/[key]', params: { key: k } })} />)}
        {user ? <Item icon="log-out-outline" label={t('logout')} onPress={confirmLogout} danger /> : null}
      </View>
      {user ? (
        <View style={{ padding: space.lg }}>
          {user.deletion_requested_at ? <Text style={{ color: colors.warn, marginBottom: 8 }}>{t('deleteRequested')}</Text> : null}
          <Button variant="ghost" title={t('deleteAccount')} onPress={() => router.push({ pathname: '/profile', params: { delete: '1' } })} />
        </View>) : null}
      <Text style={{ textAlign: 'center', color: colors.muted, marginTop: space.lg }}>{t('version', { v: Constants.expoConfig?.version ?? '1.0.0' })}</Text>
    </ScrollView>
  );
}
void EmptyState; void radius;
