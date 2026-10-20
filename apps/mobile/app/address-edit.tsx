import React, { useEffect, useState } from 'react';
import { KeyboardAvoidingView, Platform, ScrollView, Text, View } from 'react-native';
import { router, useLocalSearchParams } from 'expo-router';
import * as Location from 'expo-location';
import { api, ApiError } from '../src/lib/api';
import { useAsync } from '../src/lib/useAsync';
import { useI18n } from '../src/i18n';
import { useAuth } from '../src/state/auth';
import { colors, space } from '../src/theme';
import { Button, Chip, EmptyState, Field } from '../src/ui/kit';

export default function AddressEditScreen() {
  const { t, pick } = useI18n(); const { user } = useAuth(); const { id } = useLocalSearchParams<{ id?: string }>();
  const zones = useAsync((signal) => api<{ zones: { id: string; name: string; name_hi: string | null }[] }>('/v1/delivery/zones', { auth: false, signal }), []);
  const [f, setF] = useState({ label: 'Home', full_name: user?.name ?? '', phone: user?.phone ?? '', line1: '', line2: '', landmark: '', city: 'Loharu', pincode: '127308', is_default: false });
  const [coords, setCoords] = useState<{ latitude: number; longitude: number } | null>(null); const [zoneId, setZoneId] = useState<string | null>(null);
  const [errs, setErrs] = useState<Record<string, string>>({}); const [busy, setBusy] = useState(false); const [locBusy, setLocBusy] = useState(false); const [note, setNote] = useState<string | null>(null);
  useEffect(() => { if (!id) return; api<{ addresses: any[] }>('/v1/addresses').then((r) => { const a = r.addresses.find((x) => x.id === id); if (a) { setF({ label: a.label, full_name: a.full_name, phone: a.phone, line1: a.line1, line2: a.line2 ?? '', landmark: a.landmark ?? '', city: a.city, pincode: a.pincode, is_default: a.is_default }); setZoneId(a.zone_id); if (a.latitude != null) setCoords({ latitude: Number(a.latitude), longitude: Number(a.longitude) }); } }).catch(() => {}); }, [id]);
  if (!user) return <EmptyState icon="🔐" title={t('loginNeeded')} actionLabel={t('login')} onAction={() => router.push('/login')} />;
  const set = (k: keyof typeof f) => (v: string) => setF((p) => ({ ...p, [k]: v }));
  const useLoc = async () => {
    setLocBusy(true); setNote(t('locating'));
    try {
      const perm = await Location.requestForegroundPermissionsAsync(); if (perm.status !== 'granted') { setNote(t('locationDenied')); return; }
      const pos = await Location.getCurrentPositionAsync({ accuracy: Location.Accuracy.Balanced }); setCoords({ latitude: pos.coords.latitude, longitude: pos.coords.longitude }); setNote(t('locationSaved'));
    } catch { setNote(t('locationDenied')); } finally { setLocBusy(false); }
  };
  const save = async () => {
    const e: Record<string, string> = {};
    if (f.full_name.trim().length < 2) e.full_name = t('fullName'); if (!/^[6-9]\d{9}$/.test(f.phone)) e.phone = t('invalidPhone'); if (f.line1.trim().length < 3) e.line1 = t('line1'); if (!/^[1-9]\d{5}$/.test(f.pincode)) e.pincode = t('pincode');
    setErrs(e); if (Object.keys(e).length) return;
    setBusy(true);
    try {
      const body = { ...f, line2: f.line2.trim() || null, landmark: f.landmark.trim() || null, label: f.label.trim() || 'Home', latitude: coords?.latitude ?? null, longitude: coords?.longitude ?? null, zone_id: zoneId };
      await api(id ? `/v1/addresses/${id}` : '/v1/addresses', { method: id ? 'PUT' : 'POST', body }); router.back();
    } catch (er) { setNote(er instanceof ApiError ? er.message : t('errGeneric')); } finally { setBusy(false); }
  };
  return (
    <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <ScrollView contentContainerStyle={{ padding: space.lg, paddingBottom: 40 }} keyboardShouldPersistTaps="handled">
        <Field label={t('label')} value={f.label} onChangeText={set('label')} maxLength={30} />
        <Field label={t('fullName')} value={f.full_name} onChangeText={set('full_name')} error={errs.full_name} maxLength={80} />
        <Field label={t('phone')} value={f.phone} onChangeText={(v) => set('phone')(v.replace(/\D/g, '').slice(0, 10))} keyboardType="number-pad" error={errs.phone} />
        <Field label={t('line1')} value={f.line1} onChangeText={set('line1')} error={errs.line1} maxLength={200} />
        <Field label={t('line2')} value={f.line2} onChangeText={set('line2')} maxLength={200} />
        <Field label={t('landmark')} value={f.landmark} onChangeText={set('landmark')} maxLength={120} />
        <Field label={t('city')} value={f.city} onChangeText={set('city')} maxLength={60} />
        <Field label={t('pincode')} value={f.pincode} onChangeText={(v) => set('pincode')(v.replace(/\D/g, '').slice(0, 6))} keyboardType="number-pad" error={errs.pincode} />
        <Button variant="secondary" title={t('useLocation')} loading={locBusy} onPress={useLoc} />
        {note ? <Text style={{ color: coords ? colors.success : colors.warn, marginTop: 6 }}>{note}</Text> : null}
        {zones.data?.zones.length ? (<View style={{ marginTop: space.lg }}><Text style={{ fontWeight: '700', marginBottom: 6 }}>{t('deliveryArea')}</Text><View style={{ flexDirection: 'row', flexWrap: 'wrap' }}>{zones.data.zones.map((z) => <Chip key={z.id} label={pick(z.name, z.name_hi)} selected={zoneId === z.id} onPress={() => setZoneId(zoneId === z.id ? null : z.id)} />)}</View></View>) : null}
        <Chip label={`${f.is_default ? '✓ ' : ''}${t('makeDefault')}`} selected={f.is_default} onPress={() => setF((p) => ({ ...p, is_default: !p.is_default }))} />
        <Button title={t('save')} loading={busy} onPress={save} style={{ marginTop: space.xl }} />
      </ScrollView>
    </KeyboardAvoidingView>
  );
}
