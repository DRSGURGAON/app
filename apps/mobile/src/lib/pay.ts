import { Platform } from 'react-native';
import { api, ApiError } from './api';

export type PayResult = { status: 'paid' | 'pending' | 'cancelled' | 'failed'; message?: string };

/**
 * Pays an unpaid ONLINE order. Never trusts the SDK result on its own: the backend verifies the signature,
 * fetches the payment from the provider and checks the amount before marking the order paid.
 * Razorpay SDK path is untested in this repository's CI (needs a device + test keys); the MOCK path is for development only.
 */
export async function payOrder(orderId: string, prefillName?: string | null): Promise<PayResult> {
  let session: any;
  try { session = (await api<{ session: any }>(`/v1/orders/${orderId}/payment-session`, { method: 'POST' })).session; }
  catch (e) { return { status: 'failed', message: e instanceof ApiError ? e.message : undefined }; }

  let result: { provider_order_id: string; provider_payment_id: string; signature: string };
  if (session.provider === 'razorpay') {
    if (Platform.OS === 'web') return { status: 'failed', message: 'Online payment works in the Android app.' };
    try {
      const Razorpay = require('react-native-razorpay').default;
      const data = await Razorpay.open({ key: session.key_id, amount: session.amount_paise, currency: 'INR', order_id: session.provider_order_id, name: 'Ardh Sainik Canteen', description: `Order ${session.order_no}`, prefill: { contact: session.prefill?.contact, name: prefillName ?? session.prefill?.name ?? undefined }, theme: { color: '#1B5E20' } });
      result = { provider_order_id: data.razorpay_order_id, provider_payment_id: data.razorpay_payment_id, signature: data.razorpay_signature };
    } catch (e: any) {
      if (e?.code === 0 || e?.code === 2 || /cancel/i.test(String(e?.description ?? ''))) return { status: 'cancelled' };
      return { status: 'failed', message: e?.description ?? undefined };
    }
  } else {
    try { const m = await api<any>('/v1/dev/mock-pay', { method: 'POST', body: { provider_order_id: session.provider_order_id } }); result = m; }
    catch (e) { return { status: 'failed', message: e instanceof ApiError ? e.message : undefined }; }
  }
  try {
    const r = await api<{ status: string }>('/v1/payments/confirm', { method: 'POST', body: { provider_order_id: result.provider_order_id, provider_payment_id: result.provider_payment_id, signature: result.signature } });
    if (r.status === 'paid') return { status: 'paid' };
    if (r.status === 'late_refund') return { status: 'failed', message: 'Your payment arrived after the order expired. It will be refunded automatically.' };
    if (r.status === 'amount_mismatch' || r.status === 'conflict') return { status: 'failed', message: 'We could not match this payment to your order. If money was deducted it will be refunded; please contact the store.' };
    return r.status === 'failed' ? { status: 'failed' } : { status: 'pending' };
  } catch (e) {
    // The money may have moved even though confirmation failed (network). The webhook will still settle the order; tell the customer to check My Orders.
    return { status: e instanceof ApiError && e.isNetwork ? 'pending' : 'failed', message: e instanceof ApiError ? e.message : undefined };
  }
}
