import React, { useEffect, useState } from 'react';
import { TextInput, View } from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useI18n } from '../src/i18n';
import { ProductList } from '../src/ui/ProductList';
import { EmptyState } from '../src/ui/kit';
import { colors, radius, space } from '../src/theme';

export default function SearchScreen() {
  const { t } = useI18n(); const [text, setText] = useState(''); const [q, setQ] = useState('');
  useEffect(() => { const id = setTimeout(() => setQ(text.trim()), 350); return () => clearTimeout(id); }, [text]);
  const box = (
    <View style={{ margin: space.md, minHeight: 48, flexDirection: 'row', alignItems: 'center', backgroundColor: '#fff', borderRadius: radius.md, borderWidth: 1, borderColor: colors.border, paddingHorizontal: space.md }}>
      <Ionicons name="search" size={20} color={colors.muted} />
      <TextInput autoFocus value={text} onChangeText={setText} placeholder={t('searchHint')} accessibilityLabel={t('search')} returnKeyType="search" style={{ flex: 1, fontSize: 16, marginLeft: 8, color: colors.text }} />
    </View>);
  if (q.length < 2) return (<View style={{ flex: 1 }}>{box}<EmptyState icon="🔍" title={t('search')} hint={t('searchHint')} /></View>);
  return <ProductList q={q} header={box} />;
}
