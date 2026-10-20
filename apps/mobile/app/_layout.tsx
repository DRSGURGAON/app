import React from 'react';
import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { I18nProvider, useI18n } from '../src/i18n';
import { AuthProvider } from '../src/state/auth';
import { CartProvider } from '../src/state/cart';
import { StoreConfigProvider } from '../src/state/storeConfig';
import { colors } from '../src/theme';
import { usePushRegistration } from '../src/lib/push';

function Shell() {
  const { t } = useI18n(); usePushRegistration();
  const opts = { headerStyle: { backgroundColor: colors.primary }, headerTintColor: '#fff', headerTitleStyle: { fontWeight: '700' as const }, contentStyle: { backgroundColor: colors.bg } };
  return (
    <Stack screenOptions={opts}>
      <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
      <Stack.Screen name="products" options={{ title: t('tabCategories') }} />
      <Stack.Screen name="search" options={{ title: t('search') }} />
      <Stack.Screen name="product/[id]" options={{ title: '' }} />
      <Stack.Screen name="checkout" options={{ title: t('checkout') }} />
      <Stack.Screen name="login" options={{ title: t('login'), presentation: 'modal' }} />
      <Stack.Screen name="order/[id]" options={{ title: t('orderDetails') }} />
      <Stack.Screen name="addresses" options={{ title: t('addresses') }} />
      <Stack.Screen name="address-edit" options={{ title: t('addressForm') }} />
      <Stack.Screen name="wallet" options={{ title: t('coinsWalletTitle') }} />
      <Stack.Screen name="coupons" options={{ title: t('offers') }} />
      <Stack.Screen name="notifications" options={{ title: t('notifications') }} />
      <Stack.Screen name="profile" options={{ title: t('profile') }} />
      <Stack.Screen name="policy/[key]" options={{ title: t('policies') }} />
    </Stack>
  );
}

export default function RootLayout() {
  return (
    <SafeAreaProvider>
      <StatusBar style="light" />
      <I18nProvider><StoreConfigProvider><AuthProvider><CartProvider><Shell /></CartProvider></AuthProvider></StoreConfigProvider></I18nProvider>
    </SafeAreaProvider>
  );
}
