import { en } from '../src/i18n/en';
import { hi } from '../src/i18n/hi';
import { translate } from '../src/i18n';
describe('translations', () => {
  it('Hindi has exactly the same keys as English, none empty', () => {
    expect(Object.keys(hi).sort()).toEqual(Object.keys(en).sort());
    for (const [k, v] of Object.entries(hi)) expect(v.trim().length).toBeGreaterThan(0);
  });
  it('placeholders match between languages', () => {
    const ph = (s: string) => (s.match(/\{\{\w+\}\}/g) ?? []).sort().join();
    for (const k of Object.keys(en) as (keyof typeof en)[]) expect(ph(hi[k])).toBe(ph(en[k]));
  });
  it('interpolates variables', () => { expect(translate('en', 'minOrderMore', { amt: '₹120' })).toContain('₹120'); expect(translate('hi', 'lowStock', { n: 3 })).toContain('3'); });
});
