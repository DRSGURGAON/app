import React, { useEffect, useRef } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import MapView, { Circle, Marker, PROVIDER_GOOGLE, type Region } from 'react-native-maps';
import type { Coords } from '../lib/maps';
import { colors, radius } from '../theme';

export const MAP_SUPPORTED = true;
export interface MapPickerProps { value: Coords | null; store: Coords | null; nearKm: number; maxKm: number; onPick: (c: Coords) => void; label: string }

// Initial view only (not a delivery decision): the shop's area, used when neither a pin nor the configured store point exists yet.
const FALLBACK: Coords = { latitude: 28.4325, longitude: 75.8165 };
const close = (a: Coords, b: Coords) => Math.abs(a.latitude - b.latitude) < 0.00004 && Math.abs(a.longitude - b.longitude) < 0.00004; // ~4 m

/** Centre-pin picker: the pin stays in the middle of the screen and the map moves under it. */
export function MapPicker({ value, store, nearKm, maxKm, onPick, label }: MapPickerProps) {
  const ref = useRef<MapView>(null); const last = useRef<Coords | null>(value);
  const start = value ?? store ?? FALLBACK;
  // Move the map when the pin is set from outside (search result / "use my location").
  useEffect(() => {
    if (!value || (last.current && close(value, last.current))) return;
    last.current = value; ref.current?.animateToRegion({ ...value, latitudeDelta: 0.01, longitudeDelta: 0.01 }, 400);
  }, [value]);
  const settle = (r: Region, d?: { isGesture?: boolean }) => {
    const c = { latitude: r.latitude, longitude: r.longitude };
    if (d && d.isGesture === false) return; // programmatic move, not the customer
    if (last.current && close(c, last.current)) return;
    last.current = c; onPick(c);
  };
  return (
    <View style={s.wrap} accessible accessibilityLabel={label}>
      <MapView ref={ref} style={StyleSheet.absoluteFill} provider={PROVIDER_GOOGLE} initialRegion={{ ...start, latitudeDelta: 0.02, longitudeDelta: 0.02 }} onRegionChangeComplete={settle}
        rotateEnabled={false} pitchEnabled={false} toolbarEnabled={false} showsUserLocation={false}>
        {store ? <Marker coordinate={store} title="Store" pinColor="green" tracksViewChanges={false} /> : null}
        {store && nearKm > 0 ? <Circle center={store} radius={nearKm * 1000} strokeColor={colors.primary} fillColor="rgba(27,94,32,0.08)" strokeWidth={2} /> : null}
        {store && maxKm > 0 ? <Circle center={store} radius={maxKm * 1000} strokeColor="#F9A825" fillColor="rgba(249,168,37,0.04)" strokeWidth={2} /> : null}
      </MapView>
      <View pointerEvents="none" style={s.pinBox}><Text style={s.pin}>📍</Text></View>
    </View>
  );
}
const s = StyleSheet.create({
  wrap: { height: 280, borderRadius: radius.md, overflow: 'hidden', borderWidth: 1, borderColor: colors.border, marginVertical: 8, backgroundColor: '#E8EDE6' },
  pinBox: { position: 'absolute', left: 0, right: 0, top: 0, bottom: 0, alignItems: 'center', justifyContent: 'center' },
  pin: { fontSize: 34, marginBottom: 34 }, // tip of the pin sits on the map centre
});
