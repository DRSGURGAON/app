import { describeEstimate, newSession, type Estimate } from '../src/lib/maps';
import { translate } from '../src/i18n';

const base: Estimate = { serviceable: true, fee: '30.00', rule: 'near_base', distance_km: 1.8, method: 'road_google', zone: null, max_radius_km: 15, error: null, zones_to_choose: null };

describe('map helpers', () => {
  it('session tokens are URL-safe, 24 chars and unique', () => {
    const a = newSession(), b = newSession();
    expect(a).toMatch(/^[a-z0-9]{24}$/); expect(a).not.toBe(b);
  });
  it('shows the server fee and road distance as-is', () => {
    const d = describeEstimate(base); expect(d.ok).toBe(true); expect(d.key).toBe('estRoad');
    expect(translate('en', d.key, d.vars)).toBe('1.8 km by road · Delivery ₹30');
    const far = describeEstimate({ ...base, fee: '70.00', distance_km: 2.4, rule: 'far_fixed' });
    expect(translate('en', far.key, far.vars)).toBe('2.4 km by road · Delivery ₹70');
  });
  it('labels straight-line distances as estimates and zone fees by area', () => {
    expect(describeEstimate({ ...base, method: 'straight_line' }).key).toBe('estApprox');
    const z = describeEstimate({ ...base, method: 'zone', distance_km: null, zone: { id: 'z', name: 'Nearby villages' }, fee: '70.00' });
    expect(z.key).toBe('estZone'); expect(translate('en', z.key, z.vars)).toContain('Nearby villages');
  });
  it('outside the 15 km area is a warning with the distance, never a fee', () => {
    const d = describeEstimate({ ...base, serviceable: false, fee: null, distance_km: 18.4, error: { code: 'DELIVERY_NOT_SERVICEABLE', message: 'x' } });
    expect(d.ok).toBe(false); expect(translate('en', d.key, d.vars)).toContain('18.4 km away'); expect(translate('en', d.key, d.vars)).toContain('15 km');
    expect(describeEstimate({ ...base, serviceable: false, fee: null, distance_km: null, error: { code: 'DELIVERY_NOT_SERVICEABLE', message: 'x' } }).key).toBe('estOutsideNoDist');
  });
  it('unknown distance asks for a zone instead of guessing', () => {
    expect(describeEstimate({ ...base, serviceable: false, fee: null, distance_km: null, error: { code: 'DELIVERY_ZONE_REQUIRED', message: 'x' } }).key).toBe('estNeedZone');
    expect(describeEstimate({ ...base, serviceable: false, fee: null, error: { code: 'WHATEVER', message: 'x' } }).key).toBe('estFailed');
  });
  it('every new string exists in Hindi too', () => {
    for (const k of ['mapSearchLabel', 'mapHint', 'estRoad', 'estOutside', 'estNeedZone', 'fillFromPin'] as const) expect(translate('hi', k, { km: 1, fee: 2, max: 3, zone: 'x' })).not.toBe(translate('en', k, { km: 1, fee: 2, max: 3, zone: 'x' }));
  });
});
