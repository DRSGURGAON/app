import React, { useEffect, useRef } from 'react';
import { ActivityIndicator, Animated, Image, Pressable, StyleProp, StyleSheet, Text, TextInput, TextInputProps, View, ViewStyle } from 'react-native';
import { colors, MIN_TAP, radius, space } from '../theme';
import { useI18n } from '../i18n';
import { formatINR } from '../lib/money';
import type { ApiError } from '../lib/api';

export function Button({ title, onPress, variant = 'primary', loading, disabled, style, small, accessibilityLabel }: { title: string; onPress: () => void; variant?: 'primary' | 'secondary' | 'danger' | 'ghost'; loading?: boolean; disabled?: boolean; style?: StyleProp<ViewStyle>; small?: boolean; accessibilityLabel?: string }) {
  const off = disabled || loading;
  const bg = variant === 'primary' ? colors.primary : variant === 'danger' ? colors.danger : variant === 'secondary' ? colors.primarySoft : 'transparent';
  const fg = variant === 'primary' || variant === 'danger' ? '#fff' : colors.primary;
  return (
    <Pressable accessibilityRole="button" accessibilityLabel={accessibilityLabel ?? title} accessibilityState={{ disabled: !!off, busy: !!loading }} onPress={off ? undefined : onPress}
      style={({ pressed }) => [s.btn, small && { minHeight: 40, paddingHorizontal: space.md }, { backgroundColor: bg, opacity: off ? 0.5 : pressed ? 0.85 : 1 }, variant === 'ghost' && { borderWidth: 1, borderColor: colors.border }, style]}>
      {loading ? <ActivityIndicator color={fg} /> : <Text style={[s.btnText, { color: fg }]} numberOfLines={1}>{title}</Text>}
    </Pressable>
  );
}

export function Field({ label, error, style, ...p }: TextInputProps & { label: string; error?: string | null }) {
  return (
    <View style={[{ marginBottom: space.md }, style as any]}>
      <Text style={s.label}>{label}</Text>
      <TextInput accessibilityLabel={label} placeholderTextColor="#8A938A" {...p} style={[s.input, error ? { borderColor: colors.danger } : null]} />
      {error ? <Text style={s.fieldErr} accessibilityLiveRegion="polite">{error}</Text> : null}
    </View>
  );
}

export function Chip({ label, selected, onPress }: { label: string; selected?: boolean; onPress: () => void }) {
  return (
    <Pressable accessibilityRole="button" accessibilityState={{ selected: !!selected }} onPress={onPress} style={[s.chip, selected && { backgroundColor: colors.primary, borderColor: colors.primary }]}>
      <Text style={{ color: selected ? '#fff' : colors.text, fontWeight: '600' }}>{label}</Text>
    </Pressable>
  );
}

export function Card({ children, style }: { children: React.ReactNode; style?: StyleProp<ViewStyle> }) { return <View style={[s.card, style]}>{children}</View>; }
export function SectionTitle({ title, action, onAction }: { title: string; action?: string; onAction?: () => void }) {
  return (<View style={s.sectionRow}><Text accessibilityRole="header" style={s.sectionTitle}>{title}</Text>{action ? <Pressable onPress={onAction} accessibilityRole="link" hitSlop={10}><Text style={{ color: colors.primary, fontWeight: '700' }}>{action}</Text></Pressable> : null}</View>);
}

export function Skeleton({ w, h, style }: { w?: number | string; h: number; style?: StyleProp<ViewStyle> }) {
  const a = useRef(new Animated.Value(0.4)).current;
  useEffect(() => { const l = Animated.loop(Animated.sequence([Animated.timing(a, { toValue: 1, duration: 700, useNativeDriver: true }), Animated.timing(a, { toValue: 0.4, duration: 700, useNativeDriver: true })])); l.start(); return () => l.stop(); }, [a]);
  return <Animated.View accessibilityElementsHidden importantForAccessibility="no" style={[{ width: (w ?? '100%') as any, height: h, borderRadius: radius.sm, backgroundColor: '#E3E8E1', opacity: a }, style]} />;
}
export function ProductGridSkeleton({ n = 6 }: { n?: number }) {
  return (<View style={s.gridWrap}>{Array.from({ length: n }).map((_, i) => (<View key={i} style={s.gridCell}><View style={s.pCard}><Skeleton h={110} /><Skeleton h={14} style={{ marginTop: 10 }} /><Skeleton h={14} w="60%" style={{ marginTop: 6 }} /><Skeleton h={36} style={{ marginTop: 10 }} /></View></View>))}</View>);
}

export function EmptyState({ icon = '🛒', title, hint, actionLabel, onAction }: { icon?: string; title: string; hint?: string; actionLabel?: string; onAction?: () => void }) {
  return (
    <View style={s.center}><Text style={{ fontSize: 56 }} accessibilityElementsHidden>{icon}</Text><Text style={s.emptyTitle}>{title}</Text>{hint ? <Text style={s.emptyHint}>{hint}</Text> : null}
      {actionLabel && onAction ? <Button title={actionLabel} onPress={onAction} style={{ marginTop: space.lg, minWidth: 200 }} /> : null}</View>
  );
}
export function ErrorState({ error, onRetry }: { error: ApiError | { message: string; isNetwork?: boolean }; onRetry?: () => void }) {
  const { t } = useI18n(); const net = (error as any).isNetwork;
  return (
    <View style={s.center} accessibilityLiveRegion="polite"><Text style={{ fontSize: 48 }}>{net ? '📡' : '⚠️'}</Text><Text style={s.emptyTitle}>{net ? t('errNetwork') : error.message || t('errGeneric')}</Text>
      {onRetry ? <Button title={t('retry')} onPress={onRetry} style={{ marginTop: space.lg, minWidth: 160 }} /> : null}</View>
  );
}

export function Price({ price, mrp, size = 16 }: { price: string; mrp?: string | null; size?: number }) {
  const showMrp = mrp && Number(mrp) > Number(price);
  return (
    <View style={{ flexDirection: 'row', alignItems: 'baseline', flexWrap: 'wrap' }}>
      <Text style={{ fontSize: size, fontWeight: '800', color: colors.text }}>{formatINR(price)}</Text>
      {showMrp ? <Text style={{ marginLeft: 6, fontSize: size - 3, color: colors.muted, textDecorationLine: 'line-through' }} accessibilityLabel={`MRP ${formatINR(mrp)}`}>{formatINR(mrp)}</Text> : null}
    </View>
  );
}

export function QtyStepper({ qty, onChange, max }: { qty: number; onChange: (q: number) => void; max?: number | null }) {
  const { t } = useI18n();
  return (
    <View style={s.stepper}>
      <Pressable accessibilityRole="button" accessibilityLabel={t('decrease')} onPress={() => onChange(qty - 1)} style={s.stepBtn}><Text style={s.stepTxt}>−</Text></Pressable>
      <Text style={s.stepQty} accessibilityLabel={`${t('qty')} ${qty}`}>{qty}</Text>
      <Pressable accessibilityRole="button" accessibilityLabel={t('increase')} disabled={max != null && qty >= max} onPress={() => onChange(qty + 1)} style={[s.stepBtn, max != null && qty >= max && { opacity: 0.35 }]}><Text style={s.stepTxt}>+</Text></Pressable>
    </View>
  );
}

export function Thumb({ uri, size = 72, radiusPx = radius.md }: { uri?: string | null; size?: number | string; radiusPx?: number }) {
  const sz = size as number;
  return uri ? <Image source={{ uri }} style={{ width: sz, height: sz, borderRadius: radiusPx, backgroundColor: '#EEF1EC' }} resizeMode="contain" accessibilityIgnoresInvertColors />
    : <View style={{ width: sz, height: sz, borderRadius: radiusPx, backgroundColor: '#EEF1EC', alignItems: 'center', justifyContent: 'center' }}><Text style={{ fontSize: sz * 0.4 }}>🛍️</Text></View>;
}

export const Row = ({ label, value, bold, color }: { label: string; value: string; bold?: boolean; color?: string }) => (
  <View style={{ flexDirection: 'row', justifyContent: 'space-between', paddingVertical: 4 }}><Text style={{ color: color ?? (bold ? colors.text : colors.muted), fontWeight: bold ? '800' : '400', fontSize: bold ? 17 : 14, flexShrink: 1, paddingRight: 8 }}>{label}</Text><Text style={{ color: color ?? colors.text, fontWeight: bold ? '800' : '600', fontSize: bold ? 17 : 14 }}>{value}</Text></View>
);

export const s = StyleSheet.create({
  btn: { minHeight: MIN_TAP, borderRadius: radius.md, paddingHorizontal: space.lg, alignItems: 'center', justifyContent: 'center' },
  btnText: { fontSize: 16, fontWeight: '700' },
  label: { fontSize: 13, color: colors.muted, marginBottom: 4, fontWeight: '600' },
  input: { minHeight: MIN_TAP, borderWidth: 1, borderColor: colors.border, borderRadius: radius.md, paddingHorizontal: space.md, fontSize: 16, backgroundColor: '#fff', color: colors.text },
  fieldErr: { color: colors.danger, marginTop: 4, fontSize: 13 },
  chip: { minHeight: 40, paddingHorizontal: 14, borderRadius: 20, borderWidth: 1, borderColor: colors.border, backgroundColor: '#fff', justifyContent: 'center', marginRight: 8 },
  card: { backgroundColor: colors.card, borderRadius: radius.lg, padding: space.lg, borderWidth: 1, borderColor: colors.border, marginBottom: space.md },
  sectionRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginTop: space.lg, marginBottom: space.sm, paddingHorizontal: space.lg },
  sectionTitle: { fontSize: 18, fontWeight: '800', color: colors.text },
  center: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: space.xl },
  emptyTitle: { fontSize: 17, fontWeight: '700', color: colors.text, textAlign: 'center', marginTop: space.md },
  emptyHint: { fontSize: 14, color: colors.muted, textAlign: 'center', marginTop: 6 },
  stepper: { flexDirection: 'row', alignItems: 'center', backgroundColor: colors.primarySoft, borderRadius: radius.md },
  stepBtn: { width: MIN_TAP, height: 40, alignItems: 'center', justifyContent: 'center' },
  stepTxt: { fontSize: 22, fontWeight: '700', color: colors.primary },
  stepQty: { minWidth: 28, textAlign: 'center', fontWeight: '800', fontSize: 16, color: colors.text },
  gridWrap: { flexDirection: 'row', flexWrap: 'wrap', paddingHorizontal: space.sm },
  gridCell: { width: '50%', padding: space.xs },
  pCard: { backgroundColor: '#fff', borderRadius: radius.lg, padding: space.md, borderWidth: 1, borderColor: colors.border },
});
