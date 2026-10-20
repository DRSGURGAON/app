import { describe, it, expect } from 'vitest';
import { toPaise, fromPaise, percentOf, inclusiveTax, allocate, formatINR } from '../src/lib/money.js';
import { normalizeIndianMobile } from '../src/lib/phone.js';

describe('money', () => {
  it('parses and prints exactly, no float drift', () => {
    expect(toPaise('0.10') + toPaise('0.20')).toBe(30); expect(toPaise('1234.5')).toBe(123450); expect(toPaise(19.99)).toBe(1999); expect(toPaise('1.005')).toBe(101);
    expect(fromPaise(5)).toBe('0.05'); expect(fromPaise(123456)).toBe('1234.56'); expect(() => toPaise('abc')).toThrow(); expect(() => fromPaise(1.5)).toThrow();
  });
  it('percentOf rounds half up', () => { expect(percentOf(10000, 10)).toBe(1000); expect(percentOf(999, '12.5')).toBe(125); expect(percentOf(1, 50)).toBe(1); expect(percentOf(0, 18)).toBe(0); });
  it('inclusiveTax extracts GST from a tax-inclusive price', () => {
    expect(inclusiveTax(11800, 18)).toBe(1800); expect(inclusiveTax(10500, 5)).toBe(500); expect(inclusiveTax(10000, 0)).toBe(0);
  });
  it('allocate always sums to the total (largest remainder)', () => {
    for (const [t, w] of [[100, [1, 1, 1]], [1, [3, 3]], [999, [1, 2, 3, 4]], [5, [0, 5, 0]], [7, [333, 333, 334]]] as const) {
      const parts = allocate(t, [...w]); expect(parts.reduce((a, b) => a + b, 0)).toBe(t); expect(parts.every((p) => p >= 0)).toBe(true);
    }
    expect(allocate(100, [1, 1, 1])).toEqual([34, 33, 33]); expect(allocate(0, [1, 2])).toEqual([0, 0]); expect(allocate(5, [0, 0])).toEqual([0, 0]);
  });
  it('formats Indian digit grouping', () => {
    expect(formatINR(99900)).toBe('₹999'); expect(formatINR(123456789)).toBe('₹12,34,567.89'); expect(formatINR(100000)).toBe('₹1,000'); expect(formatINR(-5050)).toBe('-₹50.50');
  });
});
describe('phone', () => {
  it('normalises Indian mobile formats and rejects junk', () => {
    expect(normalizeIndianMobile('+91 94855 19555')).toBe('9485519555'); expect(normalizeIndianMobile('09485519555')).toBe('9485519555'); expect(normalizeIndianMobile('919485519555')).toBe('9485519555');
    for (const bad of ['12345', '5485519555', '', 'abcdefghij', '94855195556']) expect(normalizeIndianMobile(bad)).toBeNull();
  });
});
