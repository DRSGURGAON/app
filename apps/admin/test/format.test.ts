import { describe, expect, it } from 'vitest';
import { inr, dt } from '../src/api';

describe('admin formatters', () => {
  it('formats rupees in Indian grouping', () => {
    expect(inr(999)).toBe('₹999');
    expect(inr('1250.5')).toBe('₹1,250.50');
    expect(inr(100000)).toBe('₹1,00,000');
  });
  it('shows a dash for empty values', () => { expect(inr(null)).toBe('—'); expect(inr(undefined)).toBe('—'); expect(dt(null)).toBe('—'); });
  it('formats dates in IST', () => { expect(dt('2026-10-20T00:00:00Z')).toMatch(/5:30/); });
});
