import React, { useState } from 'react';
import { Alert, Platform, ScrollView, Text } from 'react-native';
import { router, useLocalSearchParams } from 'expo-router';
import { api, ApiError } from '../src/lib/api';
import { useI18n } from '../src/i18n';
import { useAuth } from '../src/state/auth';
import { colors, space } from '../src/theme';
import { Button, Card, EmptyState, Field } from '../src/ui/kit';

export default function ProfileScreen() {
  const { t } = useI18n(); const { user, updateProfile, refreshUser, logout } = useAuth(); const { delete: del } = useLocalSearchParams<{ delete?: string }>();
  const [name, setName] = useState(user?.name ?? ''); const [email, setEmail] = useState(user?.email ?? ''); const [busy, setBusy] = useState(false); const [msg, setMsg] = useState<string | null>(null); const [err, setErr] = useState<string | null>(null);
  if (!user) return <EmptyState icon="🔐" title={t('loginNeeded')} actionLabel={t('login')} onAction={() => router.push('/login')} />;
  const save = async () => {
    setErr(null); setMsg(null);
    if (name.trim().length < 2) { setErr(t('name')); return; }
    setBusy(true);
    try { await updateProfile({ name: name.trim(), email: email.trim() || null }); setMsg(t('save') + ' ✓'); } catch (e) { setErr(e instanceof ApiError ? e.message : t('errGeneric')); } finally { setBusy(false); }
  };
  const requestDeletion = async () => {
    const run = async () => { try { const r = await api<{ message: string }>('/v1/me/delete-request', { method: 'POST' }); setMsg(r.message); await refreshUser(); } catch (e) { setErr(e instanceof ApiError ? e.message : t('errGeneric')); } };
    if (Platform.OS === 'web') return run();
    Alert.alert(t('deleteAccount'), t('deleteAccountHint'), [{ text: t('cancel'), style: 'cancel' }, { text: t('deleteAccount'), style: 'destructive', onPress: run }]);
  };
  const cancelDeletion = async () => { try { await api('/v1/me/delete-request', { method: 'DELETE' }); await refreshUser(); setMsg(t('cancelDeletion') + ' ✓'); } catch (e) { setErr(e instanceof ApiError ? e.message : t('errGeneric')); } };
  return (
    <ScrollView contentContainerStyle={{ padding: space.lg }} keyboardShouldPersistTaps="handled">
      <Field label={t('mobile')} value={`+91 ${user.phone}`} editable={false} />
      <Field label={t('name')} value={name} onChangeText={setName} maxLength={80} />
      <Field label={t('email')} value={email} onChangeText={setEmail} keyboardType="email-address" autoCapitalize="none" maxLength={120} />
      {err ? <Text style={{ color: colors.danger, marginBottom: 8 }}>{err}</Text> : null}{msg ? <Text style={{ color: colors.success, marginBottom: 8 }}>{msg}</Text> : null}
      <Button title={t('save')} onPress={save} loading={busy} />
      <Card style={{ marginTop: space.xl, borderColor: del ? colors.danger : colors.border }}>
        <Text style={{ fontWeight: '800', color: colors.danger }}>{t('deleteAccount')}</Text><Text style={{ color: colors.muted, marginVertical: 8 }}>{t('deleteAccountHint')}</Text>
        {user.deletion_requested_at ? <Button variant="ghost" title={t('cancelDeletion')} onPress={cancelDeletion} /> : <Button variant="danger" title={t('deleteAccount')} onPress={requestDeletion} />}
      </Card>
      <Button variant="ghost" title={t('logout')} style={{ marginTop: space.lg }} onPress={() => void logout().then(() => router.replace('/'))} />
    </ScrollView>
  );
}
