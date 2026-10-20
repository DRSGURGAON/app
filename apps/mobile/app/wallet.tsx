import React from 'react';
import { FlatList, Text, View } from 'react-native';
import { router } from 'expo-router';
import { api } from '../src/lib/api';
import { useAsync } from '../src/lib/useAsync';
import { formatINR } from '../src/lib/money';
import { useI18n } from '../src/i18n';
import { useAuth } from '../src/state/auth';
import { colors, space } from '../src/theme';
import { Card, EmptyState, ErrorState, Skeleton } from '../src/ui/kit';
import { fmtDate } from '../src/ui/status';

export default function WalletScreen() {
  const { t, lang } = useI18n(); const { user } = useAuth();
  const w = useAsync((signal) => api<{ wallet: any; rules: any }>('/v1/wallet', { signal }), [user?.id], !!user);
  const tx = useAsync((signal) => api<{ transactions: any[] }>('/v1/wallet/transactions?limit=50', { signal }), [user?.id], !!user);
  if (!user) return <EmptyState icon="🔐" title={t('loginNeeded')} actionLabel={t('login')} onAction={() => router.push('/login')} />;
  if (w.error && !w.data) return <ErrorState error={w.error} onRetry={() => { void w.reload(); void tx.reload(); }} />;
  const label = (ty: string) => (ty === 'earn' ? t('coinEarned') : ty === 'redeem' ? t('coinRedeemed') : ty === 'expire' ? t('coinExpired') : ty === 'redeem_refund' ? t('coinEarned') : ty === 'earn_reversal' ? t('coinAdjust') : t('coinAdjust'));
  const wal = w.data?.wallet; const rules = w.data?.rules;
  return (
    <FlatList data={tx.data?.transactions ?? []} keyExtractor={(x) => String(x.id)} contentContainerStyle={{ padding: space.lg, flexGrow: 1 }}
      ListHeaderComponent={w.loading && !wal ? <Skeleton h={120} /> : wal ? (
        <Card style={{ backgroundColor: colors.primary, borderColor: colors.primary }}>
          <Text style={{ color: '#CFE6D1' }}>{t('coins')}</Text><Text style={{ color: '#fff', fontSize: 40, fontWeight: '800' }}>🪙 {wal.balance}</Text>
          {rules ? <Text style={{ color: '#E8F3E9' }}>{t('coinValueNote', { amt: formatINR(rules.coin_value) })}</Text> : null}
          {wal.expiring_soon?.coins ? <Text style={{ color: colors.accent, marginTop: 6 }}>{t('coinsExpireSoon', { n: wal.expiring_soon.coins, d: fmtDate(wal.expiring_soon.at, lang) })}</Text> : null}
          {rules ? <Text style={{ color: '#CFE6D1', marginTop: 8, fontSize: 12 }}>{t('coinRules', { e: rules.earn_coins_per_unit, u: formatINR(rules.earn_spend_unit) })}</Text> : null}
        </Card>) : undefined}
      ListEmptyComponent={tx.loading ? undefined : <EmptyState icon="🪙" title={t('noCoinHistory')} />}
      renderItem={({ item: x }) => (<View style={{ flexDirection: 'row', justifyContent: 'space-between', paddingVertical: 12, borderBottomWidth: 1, borderBottomColor: colors.border }}><View style={{ flex: 1 }}><Text style={{ fontWeight: '700' }}>{label(x.type)}</Text><Text style={{ color: colors.muted, fontSize: 12 }}>{fmtDate(x.created_at, lang)}{x.note ? ` · ${x.note}` : ''}</Text></View><Text style={{ fontWeight: '800', color: x.coins > 0 ? colors.success : colors.danger }}>{x.coins > 0 ? '+' : ''}{x.coins}</Text></View>)} />
  );
}
