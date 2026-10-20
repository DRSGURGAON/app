import React from 'react';
import { Tabs } from 'expo-router';
import { Ionicons } from '@expo/vector-icons';
import { useI18n } from '../../src/i18n';
import { useCart } from '../../src/state/cart';
import { colors } from '../../src/theme';

export default function TabsLayout() {
  const { t } = useI18n(); const { count } = useCart();
  const icon = (name: React.ComponentProps<typeof Ionicons>['name']) => ({ color, size }: { color: any; size: number }) => <Ionicons name={name} size={size} color={color} />;
  return (
    <Tabs screenOptions={{ tabBarActiveTintColor: colors.primary, tabBarInactiveTintColor: colors.muted, headerStyle: { backgroundColor: colors.primary }, headerTintColor: '#fff', tabBarLabelStyle: { fontSize: 12, fontWeight: '600' }, tabBarStyle: { height: 68, paddingBottom: 10, paddingTop: 6 }, sceneStyle: { backgroundColor: colors.bg } }}>
      <Tabs.Screen name="index" options={{ title: t('tabHome'), headerShown: false, tabBarIcon: icon('home') }} />
      <Tabs.Screen name="categories" options={{ title: t('tabCategories'), tabBarIcon: icon('grid') }} />
      <Tabs.Screen name="cart" options={{ title: t('tabCart'), headerTitle: t('cartTitle'), tabBarIcon: icon('cart'), tabBarBadge: count > 0 ? count : undefined, tabBarAccessibilityLabel: t('accessibleCart', { n: count }) }} />
      <Tabs.Screen name="orders" options={{ title: t('tabOrders'), headerTitle: t('myOrders'), tabBarIcon: icon('receipt') }} />
      <Tabs.Screen name="account" options={{ title: t('tabAccount'), headerTitle: t('account'), tabBarIcon: icon('person') }} />
    </Tabs>
  );
}
