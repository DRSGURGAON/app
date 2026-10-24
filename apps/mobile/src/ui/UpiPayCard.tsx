import React, { useState } from 'react';
import { Text, View } from 'react-native';
import * as Clipboard from 'expo-clipboard';
import { api, ApiError } from '../lib/api';
import { useAsync } from '../lib/useAsync';
import { formatINR } from '../lib/money';
import { isValidUtr, openUpiApp, upiChoices, type UpiInfo } from '../lib/upi';
import { useI18n } from '../i18n';
import { colors, space } from '../theme';
import { Button, Card, Field } from './kit';
import { fmtDate } from './status';

/** Pay-by-UPI panel for an unpaid UPI order. The app never marks anything paid: the store confirms in its bank app. */
export function UpiPayCard({ orderId, paymentStatus, onChanged }: { orderId: string; paymentStatus: string; onChanged: () => void }) {
  const { t, lang } = useI18n();
  const q = useAsync((signal) => api<{ upi: UpiInfo }>(`/v1/orders/${orderId}/upi`, { signal }), [orderId, paymentStatus]);
  const [utr, setUtr] = useState(''); const [busy, setBusy] = useState(false); const [msg, setMsg] = useState<string | null>(null); const [opened, setOpened] = useState(false);

  if (!q.data) return q.error ? <Card><Text style={{ color: colors.danger }}>{q.error.isNetwork ? t('errNetwork') : q.error.message}</Text></Card> : null;
  const u = q.data.upi;

  const report = async () => {
    const v = utr.trim();
    if (v && !isValidUtr(v)) { setMsg(t('upiUtrInvalid')); return; }
    setBusy(true); setMsg(null);
    try {
      await api(`/v1/orders/${orderId}/upi/report`, { method: 'POST', body: { utr: v || null } });
      setMsg(t('upiReported')); setUtr(''); onChanged(); await q.reload();
    } catch (e) { setMsg(e instanceof ApiError ? (e.isNetwork ? t('errNetwork') : e.message) : t('errGeneric')); }
    finally { setBusy(false); }
  };
  const open = async (link: string) => { if (await openUpiApp(link)) setOpened(true); else setMsg(t('upiNoApp')); };
  const utrField = <Field label={t('upiUtrLabel')} value={utr} onChangeText={(v) => setUtr(v.replace(/\D/g, '').slice(0, 12))} keyboardType="number-pad" maxLength={12} placeholder="123456789012" style={{ marginTop: space.md, marginBottom: 4 } as any} />;
  const note = msg ? <Text accessibilityLiveRegion="polite" style={{ marginTop: 8, fontWeight: '700', color: colors.text }}>{msg}</Text> : null;

  if (u.payment_status === 'verifying') {
    return <Card style={{ backgroundColor: colors.accentSoft }}>
      <Text style={{ fontWeight: '800', color: colors.warn }}>⏳ {t('upiVerifying')}</Text>
      <Text style={{ color: colors.text, marginTop: 4 }}>{t('upiVerifyingHint')}</Text>
      {u.claimed_utr ? <Text style={{ color: colors.muted, marginTop: 6 }}>UTR: {u.claimed_utr}</Text>
        : <>{utrField}<Button variant="secondary" small title={t('upiAddUtr')} loading={busy} disabled={!utr} onPress={report} style={{ alignSelf: 'flex-start' }} /></>}
      {note}
    </Card>;
  }
  if (!u.payable) return <Card style={{ backgroundColor: colors.accentSoft }}><Text style={{ color: colors.warn, fontWeight: '700' }}>{t('upiExpired')}</Text></Card>;

  return <Card style={{ backgroundColor: colors.accentSoft }}>
    <Text style={{ fontWeight: '800', fontSize: 17, color: colors.text }}>{t('upiPayTitle', { amt: formatINR(u.amount) })}</Text>
    {u.expires_at ? <Text style={{ color: colors.warn, marginTop: 2 }}>{t('upiPayBefore', { t: fmtDate(u.expires_at, lang) })}</Text> : null}
    <Text style={{ color: colors.muted, marginTop: 6 }}>{t('upiPayHint')}</Text>
    {upiChoices(u).map((c) => <Button key={c.link} title={c.app ? t('upiPayWith', { app: c.app }) : t('upiPayApp')} onPress={() => void open(c.link)} style={{ marginTop: 10 }} />)}

    <View style={{ marginTop: space.md, flexDirection: 'row', alignItems: 'center' }}>
      <View style={{ flex: 1 }}><Text style={{ color: colors.muted, fontSize: 12 }}>{t('upiId')}</Text><Text selectable style={{ fontWeight: '800', color: colors.text }}>{u.vpa}</Text></View>
      <Button variant="ghost" small title={t('upiCopy')} onPress={() => { void Clipboard.setStringAsync(u.vpa ?? ''); setMsg(t('upiCopied')); }} />
    </View>
    <Text style={{ color: colors.muted, fontSize: 12, marginTop: 4 }}>{t('upiManualHint', { amt: formatINR(u.amount), n: u.order_no })}</Text>
    {!u.merchant_mode ? <Text style={{ color: colors.muted, fontSize: 12, marginTop: 4 }}>{t('upiPersonalNote')}</Text> : null}

    {utrField}
    <Text style={{ color: colors.muted, fontSize: 12, marginBottom: 8 }}>{t('upiUtrHelp')}</Text>
    <Button variant={opened ? 'primary' : 'secondary'} title={t('upiIHavePaid')} loading={busy} onPress={report} />
    {note}
  </Card>;
}
