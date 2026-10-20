import { Platform } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import * as SecureStore from 'expo-secure-store';

/** Tokens go in the OS keystore on devices (SecureStore); web (dev/preview only) falls back to localStorage. */
export const secure = {
  async get(k: string): Promise<string | null> { try { return Platform.OS === 'web' ? globalThis.localStorage?.getItem(k) ?? null : await SecureStore.getItemAsync(k); } catch { return null; } },
  async set(k: string, v: string) { try { if (Platform.OS === 'web') globalThis.localStorage?.setItem(k, v); else await SecureStore.setItemAsync(k, v); } catch { /* ignore */ } },
  async del(k: string) { try { if (Platform.OS === 'web') globalThis.localStorage?.removeItem(k); else await SecureStore.deleteItemAsync(k); } catch { /* ignore */ } },
};
export const kv = {
  async get<T>(k: string, fallback: T): Promise<T> { try { const v = await AsyncStorage.getItem(k); return v ? (JSON.parse(v) as T) : fallback; } catch { return fallback; } },
  async set(k: string, v: unknown) { try { await AsyncStorage.setItem(k, JSON.stringify(v)); } catch { /* ignore */ } },
  async del(k: string) { try { await AsyncStorage.removeItem(k); } catch { /* ignore */ } },
};
