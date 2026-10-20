// All money maths is done in integer paise to avoid floating point drift.
// Database NUMERIC(12,2) values arrive as strings like "123.45".

export type Paise = number;

export function toPaise(v: string | number | null | undefined): Paise {
  if (v === null || v === undefined || v === '') return 0;
  const s = typeof v === 'number' ? v.toFixed(2) : String(v).trim();
  const m = /^(-)?(\d+)(?:\.(\d{1,}))?$/.exec(s);
  if (!m) throw new Error(`Invalid money value: ${s}`);
  const whole = Number(m[2]);
  const frac = (m[3] ?? '').padEnd(2, '0');
  let paise = whole * 100 + Number(frac.slice(0, 2));
  // round half up on any extra digits
  if (frac.length > 2 && Number(frac[2]) >= 5) paise += 1;
  return m[1] ? -paise : paise;
}

export function fromPaise(p: Paise): string {
  if (!Number.isInteger(p)) throw new Error(`Paise must be an integer: ${p}`);
  const sign = p < 0 ? '-' : '';
  const a = Math.abs(p);
  return `${sign}${Math.floor(a / 100)}.${String(a % 100).padStart(2, '0')}`;
}

/** percent has up to 2 decimals (e.g. 12.5 or "18.00"). Rounds half up. */
export function percentOf(amount: Paise, percent: number | string): Paise {
  const hundredths = Math.round(Number(percent) * 100); // 12.5% -> 1250
  return Math.floor((amount * hundredths + 5000) / 10000);
}

/** Tax contained inside a tax-inclusive amount. */
export function inclusiveTax(amountInclusive: Paise, ratePercent: number | string): Paise {
  const r = Math.round(Number(ratePercent) * 100);
  if (r <= 0) return 0;
  return Math.floor((amountInclusive * r + (10000 + r) / 2) / (10000 + r));
}

/** Split `total` paise across weights using the largest-remainder method; the parts always sum to `total`. */
export function allocate(total: Paise, weights: number[]): Paise[] {
  const sum = weights.reduce((a, b) => a + b, 0);
  if (total <= 0 || sum <= 0) return weights.map(() => 0);
  const raw = weights.map((w) => (total * w) / sum);
  const parts = raw.map(Math.floor);
  let left = total - parts.reduce((a, b) => a + b, 0);
  const order = raw.map((r, i) => ({ i, frac: r - Math.floor(r) })).sort((a, b) => b.frac - a.frac || a.i - b.i);
  for (let k = 0; left > 0 && k < order.length; k++, left--) parts[order[k]!.i]! += 1;
  return parts;
}

export function formatINR(p: Paise): string {
  const neg = p < 0;
  const a = Math.abs(p);
  const rupees = Math.floor(a / 100);
  const paise = a % 100;
  const s = String(rupees);
  const last3 = s.slice(-3);
  const rest = s.slice(0, -3);
  const grouped = rest ? rest.replace(/\B(?=(\d{2})+(?!\d))/g, ',') + ',' + last3 : last3;
  return `${neg ? '-' : ''}₹${grouped}${paise ? '.' + String(paise).padStart(2, '0') : ''}`;
}
