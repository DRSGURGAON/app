import { formatINR } from '../src/lib/money';
describe('formatINR', () => {
  it('formats whole rupees without decimals and uses Indian grouping', () => {
    expect(formatINR('999.00')).toBe('₹999'); expect(formatINR('1070.00')).toBe('₹1,070'); expect(formatINR(125000)).toBe('₹1,25,000');
  });
  it('keeps paise when present', () => { expect(formatINR('99.50')).toBe('₹99.50'); expect(formatINR('0.05')).toBe('₹0.05'); });
  it('handles missing / invalid values and negatives', () => { expect(formatINR(null)).toBe('—'); expect(formatINR('abc')).toBe('—'); expect(formatINR(-50)).toBe('−₹50'); });
});
