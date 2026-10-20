import React, { useState } from 'react';
import { Pressable, RefreshControl, ScrollView, Text, View } from 'react-native';
import { router } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { api } from '../../src/lib/api';
import { useAsync } from '../../src/lib/useAsync';
import { useI18n } from '../../src/i18n';
import { colors, radius, space } from '../../src/theme';
import { ErrorState, Skeleton, Thumb } from '../../src/ui/kit';
import { emojiFor } from './index';

interface Cat { id: string; name: string; name_hi: string | null; slug: string; image_url: string | null; children: Cat[] }

export default function CategoriesScreen() {
  const { t, pick } = useI18n(); const [open, setOpen] = useState<string | null>(null);
  const cats = useAsync((signal) => api<{ categories: Cat[] }>('/v1/categories', { auth: false, signal }), []);
  if (cats.loading && !cats.data) return <View style={{ padding: space.lg }}>{[0, 1, 2, 3, 4, 5].map((i) => <Skeleton key={i} h={64} style={{ marginBottom: 12 }} />)}</View>;
  if (cats.error && !cats.data) return <ErrorState error={cats.error} onRetry={cats.reload} />;
  return (
    <ScrollView contentContainerStyle={{ padding: space.lg, paddingBottom: 40 }} refreshControl={<RefreshControl refreshing={cats.loading} onRefresh={cats.reload} colors={[colors.primary]} />}>
      {cats.data?.categories.map((c) => {
        const expanded = open === c.id; const name = pick(c.name, c.name_hi);
        return (
          <View key={c.id} style={{ backgroundColor: '#fff', borderRadius: radius.lg, borderWidth: 1, borderColor: colors.border, marginBottom: space.md, overflow: 'hidden' }}>
            <Pressable accessibilityRole="button" accessibilityState={{ expanded }} accessibilityLabel={name} onPress={() => (c.children.length ? setOpen(expanded ? null : c.id) : router.push({ pathname: '/products', params: { category: c.slug, title: name } }))} style={{ flexDirection: 'row', alignItems: 'center', padding: space.md, minHeight: 64 }}>
              {c.image_url ? <Thumb uri={c.image_url} size={44} /> : <View style={{ width: 44, height: 44, borderRadius: 22, backgroundColor: colors.primarySoft, alignItems: 'center', justifyContent: 'center' }}><Text style={{ fontSize: 22 }}>{emojiFor(c.name)}</Text></View>}
              <Text style={{ flex: 1, marginLeft: 12, fontWeight: '700', fontSize: 16, color: colors.text }}>{name}</Text>
              <Ionicons name={expanded ? 'chevron-up' : 'chevron-down'} size={20} color={colors.muted} />
            </Pressable>
            {expanded ? (
              <View style={{ borderTopWidth: 1, borderTopColor: colors.border }}>
                <Pressable accessibilityRole="button" onPress={() => router.push({ pathname: '/products', params: { category: c.slug, title: name } })} style={{ padding: space.md, minHeight: 48, justifyContent: 'center' }}><Text style={{ color: colors.primary, fontWeight: '700' }}>{t('all')} · {name}</Text></Pressable>
                {c.children.map((s) => (
                  <Pressable key={s.id} accessibilityRole="button" onPress={() => router.push({ pathname: '/products', params: { category: s.slug, title: pick(s.name, s.name_hi) } })} style={{ paddingHorizontal: space.lg, minHeight: 48, justifyContent: 'center', borderTopWidth: 1, borderTopColor: '#EEF1EC' }}><Text style={{ color: colors.text }}>{pick(s.name, s.name_hi)}</Text></Pressable>))}
              </View>) : null}
          </View>);
      })}
    </ScrollView>
  );
}
