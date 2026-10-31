import type { ExpoConfig } from 'expo/config';
import { existsSync } from 'node:fs';

// API base URL is baked in at build time. It is a PUBLIC value (no secrets ever go in the app).
const API_URL = process.env.EXPO_PUBLIC_API_URL ?? 'http://10.0.2.2:4000'; // 10.0.2.2 = host machine from the Android emulator
// Google Maps SDK key for the ANDROID APP (public by nature; restrict it in Google Cloud to this package + signing SHA-1, Maps SDK only).
// Distance/search keys live on the server and are never put here.
const MAPS_KEY = process.env.GOOGLE_MAPS_ANDROID_KEY ?? '';
const hasGoogleServices = existsSync('./google-services.json'); // Firebase file, needed only for push notifications

const config: ExpoConfig = {
  name: 'Ardh Sainik Canteen',
  slug: 'ardh-sainik-canteen',
  version: '1.0.0',
  orientation: 'portrait',
  scheme: 'ardhsainik',
  icon: './assets/icon.png',
  userInterfaceStyle: 'light',
  android: {
    package: 'in.ardhsainik.canteen', // CHANGE before first Play Store upload if you want a different ID; it can never change afterwards
    versionCode: 1,
    adaptiveIcon: { foregroundImage: './assets/adaptive-icon.png', backgroundColor: '#1B5E20' },
    permissions: ['ACCESS_COARSE_LOCATION', 'ACCESS_FINE_LOCATION', 'POST_NOTIFICATIONS'],
    blockedPermissions: ['RECORD_AUDIO', 'READ_EXTERNAL_STORAGE', 'WRITE_EXTERNAL_STORAGE', 'SYSTEM_ALERT_WINDOW'],
    ...(hasGoogleServices ? { googleServicesFile: './google-services.json' } : {}),
    ...(MAPS_KEY ? { config: { googleMaps: { apiKey: MAPS_KEY } } } : {}),
  },
  web: { bundler: 'metro', output: 'single', favicon: './assets/favicon.png' },
  plugins: [
    'expo-router',
    ['expo-splash-screen', { image: './assets/splash-icon.png', imageWidth: 200, resizeMode: 'contain', backgroundColor: '#FFFFFF' }],
    'expo-secure-store',
    ['expo-location', { locationWhenInUsePermission: 'Allow location to calculate your delivery distance and fill your address.' }],
    ['expo-build-properties', { android: { usesCleartextTraffic: API_URL.startsWith('http://'), compileSdkVersion: 36, targetSdkVersion: 36, minSdkVersion: 24 } }],
    ...(hasGoogleServices ? [['expo-notifications', { color: '#1B5E20' }] as [string, object]] : []),
  ],
  extra: { apiUrl: API_URL, pushEnabled: hasGoogleServices, mapsEnabled: !!MAPS_KEY },
};
export default config;
