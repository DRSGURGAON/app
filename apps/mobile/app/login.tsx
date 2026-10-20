import React, { useEffect, useState } from 'react';
import { KeyboardAvoidingView, Platform, ScrollView, Text, View } from 'react-native';
import { router } from 'expo-router';
import { useI18n } from '../src/i18n';
import { useAuth } from '../src/state/auth';
import { ApiError } from '../src/lib/api';
import { colors, space } from '../src/theme';
import { Button, Field } from '../src/ui/kit';

export default function LoginScreen() {
  const { t } = useI18n(); const auth = useAuth();
  const [phone, setPhone] = useState(''); const [code, setCode] = useState(''); const [step, setStep] = useState<'phone' | 'otp'>('phone');
  const [busy, setBusy] = useState(false); const [err, setErr] = useState<string | null>(null); const [dev, setDev] = useState<string | null>(null); const [cool, setCool] = useState(0);
  useEffect(() => { if (cool <= 0) return; const id = setTimeout(() => setCool((c) => c - 1), 1000); return () => clearTimeout(id); }, [cool]);
  const valid = /^[6-9]\d{9}$/.test(phone);
  const send = async () => {
    if (!valid) { setErr(t('invalidPhone')); return; }
    setBusy(true); setErr(null);
    try { const r = await auth.requestOtp(phone); setDev(r.dev_code ?? null); setStep('otp'); setCode(''); setCool(30); }
    catch (e) { setErr(e instanceof ApiError ? e.message : t('errGeneric')); } finally { setBusy(false); }
  };
  const verify = async () => {
    if (!/^\d{6}$/.test(code)) { setErr(t('invalidOtp')); return; }
    setBusy(true); setErr(null);
    try { await auth.verifyOtp(phone, code); router.canGoBack() ? router.back() : router.replace('/'); }
    catch (e) { setErr(e instanceof ApiError ? e.message : t('errGeneric')); } finally { setBusy(false); }
  };
  return (
    <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <ScrollView contentContainerStyle={{ padding: space.xl }} keyboardShouldPersistTaps="handled">
        <Text style={{ fontSize: 56, textAlign: 'center' }}>🛒</Text>
        <Text accessibilityRole="header" style={{ fontSize: 24, fontWeight: '800', textAlign: 'center', color: colors.text, marginTop: space.md }}>{t('loginTitle')}</Text>
        <Text style={{ textAlign: 'center', color: colors.muted, marginBottom: space.xl, marginTop: 4 }}>{step === 'phone' ? t('loginSub') : t('otpSentTo', { p: phone })}</Text>
        {step === 'phone' ? (
          <>
            <Field label={t('mobile')} value={phone} onChangeText={(v) => setPhone(v.replace(/\D/g, '').slice(0, 10))} keyboardType="number-pad" maxLength={10} placeholder="98XXXXXXXX" autoFocus error={err} />
            <Button title={t('sendOtp')} onPress={send} loading={busy} disabled={!valid} />
          </>) : (
          <>
            <Field label={t('enterOtp')} value={code} onChangeText={(v) => setCode(v.replace(/\D/g, '').slice(0, 6))} keyboardType="number-pad" maxLength={6} autoFocus textContentType="oneTimeCode" autoComplete="sms-otp" error={err} />
            {dev ? <View style={{ padding: 10, backgroundColor: colors.accentSoft, borderRadius: 8, marginBottom: space.md }}><Text style={{ color: colors.warn, fontWeight: '700' }}>{t('devOtp', { c: dev })}</Text></View> : null}
            <Button title={t('verify')} onPress={verify} loading={busy} disabled={code.length !== 6} />
            <View style={{ flexDirection: 'row', justifyContent: 'space-between', marginTop: space.md }}>
              <Button variant="ghost" small title={t('changeNumber')} onPress={() => { setStep('phone'); setErr(null); }} />
              <Button variant="ghost" small title={cool > 0 ? t('resendIn', { s: cool }) : t('resend')} disabled={cool > 0} onPress={send} />
            </View>
          </>)}
      </ScrollView>
    </KeyboardAvoidingView>
  );
}
