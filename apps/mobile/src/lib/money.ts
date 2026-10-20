/** Format a rupee amount (string from the API, e.g. "1070.00") for display. Display only; the server owns all calculations. */
export function formatINR(v: string | number | null | undefined, opts: { hideZeroDecimals?: boolean } = { hideZeroDecimals: true }): string {
  if (v === null || v === undefined || v === '') return '—';
  const n = Number(v); if (!Number.isFinite(n)) return '—';
  const whole = Number.isInteger(n) || Math.abs(n - Math.round(n)) < 0.005;
  const s = Math.abs(n).toLocaleString('en-IN', { minimumFractionDigits: whole && opts.hideZeroDecimals ? 0 : 2, maximumFractionDigits: 2 });
  return `${n < 0 ? '−' : ''}₹${s}`;
}
