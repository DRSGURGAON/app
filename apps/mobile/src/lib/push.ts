import { useEffect } from 'react';
import { Platform } from 'react-native';
import Constants from 'expo-constants';
import { api } from './api';
import { useAuth } from '../state/auth';

/**
 * Registers the device's FCM token with the backend after login. Only active when the build includes Firebase config
 * (google-services.json present at build time => extra.pushEnabled). Without it this is a no-op and the app works normally.
 */
export function usePushRegistration() {
  const { user } = useAuth();
  useEffect(() => {
    if (!user || Platform.OS !== 'android' || !(Constants.expoConfig?.extra as any)?.pushEnabled) return;
    let cancelled = false;
    (async () => {
      try {
        const N = require('expo-notifications');
        const perm = await N.requestPermissionsAsync(); if (perm.status !== 'granted' || cancelled) return;
        const tok = await N.getDevicePushTokenAsync(); // native FCM token
        if (!cancelled && tok?.data) await api('/v1/devices', { method: 'POST', body: { token: String(tok.data), platform: 'android' } });
      } catch { /* push is optional; never block the app */ }
    })();
    return () => { cancelled = true; };
  }, [user?.id]); // eslint-disable-line react-hooks/exhaustive-deps
}
