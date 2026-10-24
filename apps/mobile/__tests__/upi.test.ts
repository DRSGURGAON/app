import { isValidUtr, upiChoices } from '../src/lib/upi';

const info = {
  link: 'upi://pay?pa=shop@sbi&pn=Shop&am=999.00&cu=INR&tn=Order%20ASM1',
  ios_app_links: [{ app: 'PhonePe', link: 'phonepe://pay?pa=shop@sbi' }, { app: 'Google Pay', link: 'tez://upi/pay?pa=shop@sbi' }],
};

describe('UPI helpers', () => {
  it('Android gets one link for the system chooser; iPhone gets one button per app', () => {
    expect(upiChoices(info, 'android')).toEqual([{ app: null, link: info.link }]);
    expect(upiChoices(info, 'ios').map((c) => c.app)).toEqual(['PhonePe', 'Google Pay']);
  });
  it('offers nothing when the order is not payable', () => {
    expect(upiChoices({ link: null, ios_app_links: [] }, 'android')).toEqual([]);
  });
  it('accepts only 12-digit UTRs', () => {
    expect(isValidUtr('412345678901')).toBe(true);
    expect(isValidUtr(' 412345678901 ')).toBe(true);
    expect(isValidUtr('41234567890')).toBe(false);
    expect(isValidUtr('41234567890a')).toBe(false);
  });
});
