import React, { useCallback, useEffect, useRef, useState } from 'react';
import { ActivityIndicator, FlatList, RefreshControl, ScrollView, Text, View } from 'react-native';
import { api, ApiError } from '../lib/api';
import { useI18n } from '../i18n';
import { colors, space } from '../theme';
import { Chip, EmptyState, ErrorState, ProductGridSkeleton } from './kit';
import { ProductCard, type ProductDto } from './ProductCard';

type Sort = 'relevance' | 'price_asc' | 'price_desc' | 'name' | 'newest' | 'discount';
const PAGE = 20;

export function ProductList({ q, category, header, emptyHint }: { q?: string; category?: string; header?: React.ReactNode; emptyHint?: string }) {
  const { t } = useI18n();
  const [sort, setSort] = useState<Sort>('relevance'); const [inStock, setInStock] = useState(false);
  const [items, setItems] = useState<ProductDto[]>([]); const [page, setPage] = useState(1); const [more, setMore] = useState(false);
  const [loading, setLoading] = useState(true); const [loadingMore, setLoadingMore] = useState(false); const [error, setError] = useState<ApiError | null>(null); const [refreshing, setRefreshing] = useState(false);
  const seq = useRef(0);

  const fetchPage = useCallback(async (p: number, replace: boolean) => {
    const id = ++seq.current;
    try {
      const qs = new URLSearchParams({ page: String(p), limit: String(PAGE), sort }); if (q) qs.set('q', q); if (category) qs.set('category', category); if (inStock) qs.set('in_stock', 'true');
      const r = await api<{ items: ProductDto[]; has_more: boolean }>(`/v1/products?${qs}`, { auth: false });
      if (id !== seq.current) return;
      setItems((cur) => (replace ? r.items : [...cur, ...r.items.filter((n) => !cur.some((c) => c.id === n.id))])); setMore(r.has_more); setPage(p); setError(null);
    } catch (e: any) { if (id === seq.current) setError(e instanceof ApiError ? e : new ApiError(0, 'UNKNOWN', e?.message)); }
    finally { if (id === seq.current) { setLoading(false); setLoadingMore(false); setRefreshing(false); } }
  }, [q, category, sort, inStock]);

  useEffect(() => { setLoading(true); setItems([]); void fetchPage(1, true); }, [fetchPage]);

  const head = (
    <View>
      {header}
      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ padding: space.md }}>
        <Chip label={t('inStockOnly')} selected={inStock} onPress={() => setInStock((v) => !v)} />
        {([['relevance', 'sortRelevance'], ['price_asc', 'sortPriceLow'], ['price_desc', 'sortPriceHigh'], ['discount', 'sortDiscount'], ['newest', 'sortNewest'], ['name', 'sortName']] as const).map(([k, lk]) => (
          <Chip key={k} label={t(lk)} selected={sort === k} onPress={() => setSort(k)} />))}
      </ScrollView>
    </View>
  );

  if (loading && items.length === 0) return (<View style={{ flex: 1 }}>{head}<ProductGridSkeleton /></View>);
  if (error && items.length === 0) return (<View style={{ flex: 1 }}>{head}<ErrorState error={error} onRetry={() => { setLoading(true); void fetchPage(1, true); }} /></View>);
  return (
    <FlatList data={items} keyExtractor={(i) => i.id} numColumns={2} renderItem={({ item }) => <ProductCard p={item} />} ListHeaderComponent={head}
      contentContainerStyle={{ paddingHorizontal: space.sm, paddingBottom: 100 }} keyboardShouldPersistTaps="handled"
      ListEmptyComponent={<EmptyState icon="🔍" title={t('noResults')} hint={emptyHint ?? t('noResultsHint')} />}
      ListFooterComponent={loadingMore ? <ActivityIndicator style={{ margin: space.lg }} color={colors.primary} /> : error ? <ErrorState error={error} onRetry={() => { setLoadingMore(true); void fetchPage(page + 1, false); }} /> : undefined}
      onEndReachedThreshold={0.5} onEndReached={() => { if (more && !loadingMore && !loading && !error) { setLoadingMore(true); void fetchPage(page + 1, false); } }}
      refreshControl={<RefreshControl refreshing={refreshing} onRefresh={() => { setRefreshing(true); void fetchPage(1, true); }} colors={[colors.primary]} />} />
  );
}
