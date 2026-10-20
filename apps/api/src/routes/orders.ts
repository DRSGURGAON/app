import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import type { RouteDeps } from '../app.js';
import { parse, uuid } from '../lib/validate.js';
import { AppError } from '../lib/errors.js';
import { createOrder, getOrderDetail, listUserOrders, transitionOrder } from '../services/orders.js';
import { MockPaymentProvider } from '../providers/payments.js';
import { confirmPayment, createPaymentSession, handleWebhook, processPendingRefunds } from '../services/payments.js';

export async function orderRoutes(app: FastifyInstance, { ctx, requireUser }: RouteDeps) {
  const auth = { preHandler: requireUser };

  const checkoutBody = z.object({
    items: z.array(z.object({ product_id: uuid, qty: z.number().int().min(1).max(999) })).min(1).max(200),
    fulfilment: z.enum(['delivery', 'pickup']), address_id: uuid.nullish(), zone_id: uuid.nullish(),
    payment_method: z.enum(['cod', 'online']), coupon_code: z.string().trim().max(24).nullish(), use_coins: z.number().int().min(0).max(100000).default(0),
    expected_total: z.string().regex(/^\d+(\.\d{1,2})?$/).nullish(), note: z.string().trim().max(300).nullish(),
  });

  app.post('/orders', auth, async (req, reply) => {
    const key = String(req.headers['idempotency-key'] ?? '');
    if (key.length < 8 || key.length > 80) throw new AppError(400, 'IDEMPOTENCY_KEY_REQUIRED', 'Idempotency-Key header (8-80 characters) is required');
    const b = parse(checkoutBody, req.body);
    if (b.zone_id && b.address_id) await ctx.db.query('UPDATE addresses SET zone_id=$1 WHERE id=$2 AND user_id=$3', [b.zone_id, b.address_id, req.userId]); // remember the delivery area the customer confirmed
    const r = await createOrder(ctx, req.userId!, { ...b, idempotency_key: key });
    reply.status(r.replay ? 200 : 201);
    return { order: await getOrderDetail(ctx.db, r.orderId, req.userId), replay: r.replay };
  });

  app.get('/orders', auth, async (req) => {
    const q = parse(z.object({ limit: z.coerce.number().int().min(1).max(50).default(20) }), req.query);
    return { orders: await listUserOrders(ctx.db, req.userId!, q.limit) };
  });
  app.get('/orders/:id', auth, async (req) => {
    const { id } = parse(z.object({ id: uuid }), req.params);
    return { order: await getOrderDetail(ctx.db, id, req.userId) };
  });
  app.post('/orders/:id/cancel', auth, async (req) => {
    const { id } = parse(z.object({ id: uuid }), req.params);
    const b = parse(z.object({ reason: z.string().trim().min(3).max(200) }), req.body);
    await getOrderDetail(ctx.db, id, req.userId);
    await transitionOrder(ctx, id, 'cancelled', { type: 'customer', id: req.userId }, { reason: b.reason });
    await processPendingRefunds(ctx);
    return { order: await getOrderDetail(ctx.db, id, req.userId) };
  });
  app.get('/orders/:id/reorder', auth, async (req) => {
    const { id } = parse(z.object({ id: uuid }), req.params);
    const o = await getOrderDetail(ctx.db, id, req.userId);
    return { items: o.items.filter((i: any) => i.product_id).map((i: any) => ({ product_id: i.product_id, qty: i.qty })) };
  });

  // ---- online payment
  app.post('/orders/:id/payment-session', auth, async (req) => {
    const { id } = parse(z.object({ id: uuid }), req.params);
    return { session: await createPaymentSession(ctx, id, req.userId!) };
  });
  app.post('/payments/confirm', auth, async (req) => {
    const b = parse(z.object({ provider_order_id: z.string().min(5).max(80), provider_payment_id: z.string().min(5).max(80), signature: z.string().min(10).max(200) }), req.body);
    const r = await confirmPayment(ctx, req.userId!, { providerOrderId: b.provider_order_id, providerPaymentId: b.provider_payment_id, signature: b.signature });
    return { status: r.status, order: await getOrderDetail(ctx.db, r.orderId, req.userId) };
  });

  // ---- DEV ONLY: lets the mobile app complete a payment when the MOCK provider is configured. Never registered with real Razorpay keys (config refuses mock in production).
  if (ctx.payments instanceof MockPaymentProvider && ctx.config.NODE_ENV !== 'production') {
    app.post('/dev/mock-pay', auth, async (req) => {
      const b = parse(z.object({ provider_order_id: z.string().min(5).max(120), outcome: z.enum(['captured', 'failed']).default('captured') }), req.body);
      const p = (await ctx.db.query(`SELECT p.amount FROM payments p JOIN orders o ON o.id=p.order_id WHERE p.provider_order_id=$1 AND o.user_id=$2`, [b.provider_order_id, req.userId])).rows[0];
      if (!p) throw new AppError(404, 'NOT_FOUND', 'Payment not found');
      const sim = (ctx.payments as MockPaymentProvider).simulatePayment(b.provider_order_id, Math.round(Number(p.amount) * 100), b.outcome);
      return { provider_order_id: b.provider_order_id, provider_payment_id: sim.providerPaymentId, signature: sim.signature, dev_notice: 'MOCK payment (development only)' };
    });
  }

  // ---- provider webhook (signature-verified, idempotent). Always answers 2xx for handled events so the provider stops retrying.
  app.post('/webhooks/payments', { config: { rateLimit: { max: 600, timeWindow: '1 minute' } } }, async (req, reply) => {
    const res = await handleWebhook(ctx, req.rawBody ?? Buffer.from(''), String(req.headers['x-razorpay-signature'] ?? ''), req.headers['x-razorpay-event-id'] ? String(req.headers['x-razorpay-event-id']) : undefined);
    return reply.status(res.status).send(res.body);
  });
}
