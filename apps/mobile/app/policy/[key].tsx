import React from 'react';
import { ScrollView, Text } from 'react-native';
import { Stack, useLocalSearchParams } from 'expo-router';
import { useI18n } from '../../src/i18n';
import { useStoreConfig } from '../../src/state/storeConfig';
import { colors, space } from '../../src/theme';
import { EmptyState } from '../../src/ui/kit';

export default function PolicyScreen() {
  const { key } = useLocalSearchParams<{ key: string }>(); const { t, pick } = useI18n(); const { config } = useStoreConfig();
  const p = (config?.policies as any)?.[key as string]; const titles: Record<string, any> = { privacy: 'privacy', terms: 'terms', delivery: 'deliveryPolicy', cancellation: 'cancellationPolicy', refund: 'refundPolicy' };
  if (!p) return <EmptyState title={t('errGeneric')} />;
  return (<ScrollView contentContainerStyle={{ padding: space.lg }}><Stack.Screen options={{ title: t(titles[key as string] ?? 'policies') }} /><Text style={{ color: colors.text, lineHeight: 22, fontSize: 15 }}>{pick(p.en, p.hi)}</Text></ScrollView>);
}
