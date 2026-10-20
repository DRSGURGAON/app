import React from 'react';
import { Stack, useLocalSearchParams } from 'expo-router';
import { View } from 'react-native';
import { ProductList } from '../src/ui/ProductList';

export default function ProductsScreen() {
  const { category, title } = useLocalSearchParams<{ category?: string; title?: string }>();
  return (<View style={{ flex: 1 }}><Stack.Screen options={{ title: title ?? '' }} /><ProductList category={category} /></View>);
}
