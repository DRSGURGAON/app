/** Normalise Indian mobile numbers to the 10-digit national form. Returns null if invalid. */
export function normalizeIndianMobile(input: string): string | null {
  const digits = (input ?? '').replace(/[^\d]/g, '');
  let n = digits;
  if (n.length === 12 && n.startsWith('91')) n = n.slice(2);
  else if (n.length === 11 && n.startsWith('0')) n = n.slice(1);
  return /^[6-9]\d{9}$/.test(n) ? n : null;
}
export const maskPhone = (p: string) => p.replace(/^(\d{2})\d{6}(\d{2})$/, '$1XXXXXX$2');
