import { createHmac } from 'node:crypto';
import { hmacHex, safeEqualHex } from '../lib/crypto.js';
import type { Config } from '../config.js';

export type ProviderPaymentStatus = 'captured' | 'authorized' | 'failed' | 'created';

export interface ProviderPayment {
  id: string; orderId: string; amountPaise: number; status: ProviderPaymentStatus; method?: string; errorDescription?: string;
}

export type NormalizedWebhook =
  | { kind: 'payment_captured'; providerOrderId: string; providerPaymentId: string; amountPaise: number; method?: string }
  | { kind: 'payment_failed'; providerOrderId: string; providerPaymentId: string; reason?: string }
  | { kind: 'refund_processed'; providerPaymentId: string; providerRefundId: string; amountPaise: number }
  | { kind: 'refund_failed'; providerPaymentId: string; providerRefundId: string }
  | { kind: 'ignored'; type: string };

export interface PaymentProvider {
  readonly name: 'razorpay' | 'mock';
  readonly mode: 'sandbox' | 'live';
  /** Public key id that the mobile SDK needs. Never the secret. */
  readonly publicKeyId: string;
  createOrder(a: { amountPaise: number; receipt: string }): Promise<{ providerOrderId: string }>;
  verifyCheckoutSignature(a: { providerOrderId: string; providerPaymentId: string; signature: string }): boolean;
  fetchPayment(providerPaymentId: string): Promise<ProviderPayment>;
  verifyWebhookSignature(rawBody: Buffer | string, signature: string): boolean;
  parseWebhook(payload: any): NormalizedWebhook;
  refund(a: { providerPaymentId: string; amountPaise: number; receipt: string }): Promise<{ providerRefundId: string; status: 'pending' | 'processed' }>;
}

// ------------------------------------------------------------------ Razorpay (real HTTP API)
export class RazorpayProvider implements PaymentProvider {
  readonly name = 'razorpay' as const;
  readonly publicKeyId: string;
  constructor(
    private keyId: string, private keySecret: string, private webhookSecret: string, readonly mode: 'sandbox' | 'live',
    private fetchImpl: typeof fetch = fetch,
  ) { this.publicKeyId = keyId; }

  private async call(method: string, path: string, body?: unknown): Promise<any> {
    const res = await this.fetchImpl(`https://api.razorpay.com/v1${path}`, {
      method,
      headers: { authorization: 'Basic ' + Buffer.from(`${this.keyId}:${this.keySecret}`).toString('base64'), 'content-type': 'application/json' },
      body: body === undefined ? undefined : JSON.stringify(body),
      signal: AbortSignal.timeout(15000),
    });
    const json: any = await res.json().catch(() => ({}));
    if (!res.ok) throw new Error(`Razorpay ${method} ${path} failed: ${res.status} ${json?.error?.description ?? ''}`);
    return json;
  }

  async createOrder(a: { amountPaise: number; receipt: string }) {
    const r = await this.call('POST', '/orders', { amount: a.amountPaise, currency: 'INR', receipt: a.receipt.slice(0, 40), payment_capture: 1 });
    return { providerOrderId: r.id as string };
  }
  verifyCheckoutSignature(a: { providerOrderId: string; providerPaymentId: string; signature: string }) {
    return safeEqualHex(hmacHex(this.keySecret, `${a.providerOrderId}|${a.providerPaymentId}`), a.signature);
  }
  async fetchPayment(id: string): Promise<ProviderPayment> {
    const r = await this.call('GET', `/payments/${encodeURIComponent(id)}`);
    return { id: r.id, orderId: r.order_id, amountPaise: r.amount, status: r.status === 'captured' ? 'captured' : r.status === 'authorized' ? 'authorized' : r.status === 'failed' ? 'failed' : 'created', method: r.method, errorDescription: r.error_description };
  }
  verifyWebhookSignature(rawBody: Buffer | string, signature: string) {
    if (!this.webhookSecret || !signature) return false;
    return safeEqualHex(hmacHex(this.webhookSecret, rawBody), signature);
  }
  parseWebhook(p: any): NormalizedWebhook { return parseRazorpayEvent(p); }
  async refund(a: { providerPaymentId: string; amountPaise: number; receipt: string }) {
    const r = await this.call('POST', `/payments/${encodeURIComponent(a.providerPaymentId)}/refund`, { amount: a.amountPaise, receipt: a.receipt.slice(0, 40) });
    return { providerRefundId: r.id as string, status: r.status === 'processed' ? ('processed' as const) : ('pending' as const) };
  }
}

export function parseRazorpayEvent(p: any): NormalizedWebhook {
  const type: string = p?.event ?? 'unknown';
  const pay = p?.payload?.payment?.entity;
  const ref = p?.payload?.refund?.entity;
  switch (type) {
    case 'payment.captured':
    case 'order.paid':
      if (pay?.id && pay?.order_id) return { kind: 'payment_captured', providerOrderId: pay.order_id, providerPaymentId: pay.id, amountPaise: pay.amount, method: pay.method };
      break;
    case 'payment.failed':
      if (pay?.id && pay?.order_id) return { kind: 'payment_failed', providerOrderId: pay.order_id, providerPaymentId: pay.id, reason: pay.error_description };
      break;
    case 'refund.processed':
      if (ref?.id && ref?.payment_id) return { kind: 'refund_processed', providerPaymentId: ref.payment_id, providerRefundId: ref.id, amountPaise: ref.amount };
      break;
    case 'refund.failed':
      if (ref?.id && ref?.payment_id) return { kind: 'refund_failed', providerPaymentId: ref.payment_id, providerRefundId: ref.id };
      break;
  }
  return { kind: 'ignored', type };
}

// ------------------------------------------------------------------ Mock (DEVELOPMENT ONLY - refused in production by config)
// Behaves like Razorpay: signs with a local secret, keeps payments in memory. Lets the whole flow run without an account.
export class MockPaymentProvider implements PaymentProvider {
  readonly name = 'mock' as const;
  readonly mode = 'sandbox' as const;
  readonly publicKeyId = 'mock_key';
  static readonly SECRET = 'mock-payment-secret-dev-only';
  private payments = new Map<string, ProviderPayment>();
  private seq = 0;

  async createOrder(a: { amountPaise: number; receipt: string }) { return { providerOrderId: `mock_order_${++this.seq}_${a.receipt}` }; }
  /** Test/dev helper: simulate the customer paying (or failing) in the checkout UI. */
  simulatePayment(providerOrderId: string, amountPaise: number, status: ProviderPaymentStatus = 'captured') {
    const id = `mock_pay_${++this.seq}`;
    this.payments.set(id, { id, orderId: providerOrderId, amountPaise, status, method: 'upi' });
    return { providerPaymentId: id, signature: hmacHex(MockPaymentProvider.SECRET, `${providerOrderId}|${id}`) };
  }
  verifyCheckoutSignature(a: { providerOrderId: string; providerPaymentId: string; signature: string }) {
    return safeEqualHex(hmacHex(MockPaymentProvider.SECRET, `${a.providerOrderId}|${a.providerPaymentId}`), a.signature);
  }
  async fetchPayment(id: string): Promise<ProviderPayment> {
    const p = this.payments.get(id);
    if (!p) throw new Error('mock payment not found');
    return p;
  }
  verifyWebhookSignature(rawBody: Buffer | string, signature: string) {
    return safeEqualHex(createHmac('sha256', MockPaymentProvider.SECRET).update(rawBody).digest('hex'), signature ?? '');
  }
  signWebhook(rawBody: string) { return createHmac('sha256', MockPaymentProvider.SECRET).update(rawBody).digest('hex'); }
  parseWebhook(p: any) { return parseRazorpayEvent(p); }
  async refund(a: { providerPaymentId: string; amountPaise: number; receipt: string }) {
    return { providerRefundId: `mock_rfnd_${++this.seq}`, status: 'processed' as const };
  }
}

export function createPaymentProvider(c: Config): PaymentProvider {
  if (c.PAYMENT_PROVIDER === 'razorpay') return new RazorpayProvider(c.RAZORPAY_KEY_ID, c.RAZORPAY_KEY_SECRET, c.RAZORPAY_WEBHOOK_SECRET, c.PAYMENT_MODE);
  return new MockPaymentProvider();
}
