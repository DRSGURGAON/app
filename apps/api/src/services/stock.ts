import type { Tx } from '../db/pool.js';
import { AppError, conflict } from '../lib/errors.js';

export interface StockLine { productId: string; qty: number }

async function movement(tx: Tx, m: { productId: string; type: string; qtyDelta: number; reservedDelta: number; stockAfter: number; reservedAfter: number; reason?: string | null; orderId?: string | null; adminId?: string | null }) {
  await tx.query(
    `INSERT INTO stock_movements (product_id, type, qty_delta, reserved_delta, stock_after, reserved_after, reason, order_id, admin_id)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
    [m.productId, m.type, m.qtyDelta, m.reservedDelta, m.stockAfter, m.reservedAfter, m.reason ?? null, m.orderId ?? null, m.adminId ?? null]);
}

/** Atomically reserve stock. Each UPDATE is guarded in SQL, so concurrent checkouts can never oversell. */
export async function reserveStock(tx: Tx, lines: StockLine[], orderId: string): Promise<void> {
  const sorted = [...lines].sort((a, b) => a.productId.localeCompare(b.productId)); // consistent lock order -> no deadlocks
  for (const l of sorted) {
    const r = await tx.query(
      `UPDATE products SET reserved_qty = reserved_qty + $2
        WHERE id = $1 AND is_active AND stock_qty - reserved_qty >= $2
        RETURNING stock_qty, reserved_qty`, [l.productId, l.qty]);
    if (!r.rowCount) {
      const p = await tx.query('SELECT name, stock_qty - reserved_qty AS available, is_active FROM products WHERE id=$1', [l.productId]);
      const row = p.rows[0];
      throw conflict('STOCK_INSUFFICIENT',
        row ? `Only ${Math.max(row.available, 0)} left of "${row.name}"` : 'A product in your cart is no longer available',
        { product_id: l.productId, available: row ? Math.max(row.available, 0) : 0 });
    }
    await movement(tx, { productId: l.productId, type: 'reserve', qtyDelta: 0, reservedDelta: l.qty, stockAfter: r.rows[0].stock_qty, reservedAfter: r.rows[0].reserved_qty, orderId, reason: 'Order placed' });
  }
}

async function orderLines(tx: Tx, orderId: string): Promise<StockLine[]> {
  const { rows } = await tx.query('SELECT product_id, qty FROM order_items WHERE order_id=$1 AND product_id IS NOT NULL ORDER BY product_id', [orderId]);
  return rows.map((r) => ({ productId: r.product_id, qty: r.qty }));
}

/** Release reservation (cancel / reject / expiry). Idempotent via orders.stock_state. */
export async function releaseStock(tx: Tx, orderId: string, reason: string): Promise<boolean> {
  const g = await tx.query(`UPDATE orders SET stock_state='released' WHERE id=$1 AND stock_state='reserved' RETURNING id`, [orderId]);
  if (!g.rowCount) return false;
  for (const l of await orderLines(tx, orderId)) {
    const r = await tx.query('UPDATE products SET reserved_qty = reserved_qty - $2 WHERE id=$1 RETURNING stock_qty, reserved_qty', [l.productId, l.qty]);
    if (r.rowCount) await movement(tx, { productId: l.productId, type: 'release', qtyDelta: 0, reservedDelta: -l.qty, stockAfter: r.rows[0].stock_qty, reservedAfter: r.rows[0].reserved_qty, orderId, reason });
  }
  return true;
}

/** Goods handed over: remove from on-hand stock and from reserved. Idempotent. */
export async function fulfilStock(tx: Tx, orderId: string): Promise<boolean> {
  const g = await tx.query(`UPDATE orders SET stock_state='fulfilled' WHERE id=$1 AND stock_state='reserved' RETURNING id`, [orderId]);
  if (!g.rowCount) return false;
  for (const l of await orderLines(tx, orderId)) {
    const r = await tx.query(
      `UPDATE products SET stock_qty = stock_qty - $2, reserved_qty = reserved_qty - $2 WHERE id=$1 RETURNING stock_qty, reserved_qty`, [l.productId, l.qty]);
    if (r.rowCount) await movement(tx, { productId: l.productId, type: 'fulfil', qtyDelta: -l.qty, reservedDelta: -l.qty, stockAfter: r.rows[0].stock_qty, reservedAfter: r.rows[0].reserved_qty, orderId, reason: 'Order fulfilled' });
  }
  return true;
}

export interface AdjustArgs { productId: string; delta?: number; setTo?: number; reason: string; adminId: string | null; type?: 'adjustment' | 'import' | 'opening' | 'return' }

/** Admin stock correction. Never lets on-hand stock drop below what is reserved for open orders. */
export async function adjustStock(tx: Tx, a: AdjustArgs): Promise<{ stock_qty: number; reserved_qty: number }> {
  if (!a.reason || a.reason.trim().length < 3) throw new AppError(400, 'REASON_REQUIRED', 'Please give a reason for the stock change');
  const p = await tx.query('SELECT stock_qty, reserved_qty FROM products WHERE id=$1 FOR UPDATE', [a.productId]);
  if (!p.rowCount) throw new AppError(404, 'NOT_FOUND', 'Product not found');
  const cur = p.rows[0].stock_qty as number;
  const target = a.setTo !== undefined ? a.setTo : cur + (a.delta ?? 0);
  if (!Number.isInteger(target) || target < 0) throw new AppError(400, 'BAD_STOCK', 'Stock cannot be negative');
  if (target < p.rows[0].reserved_qty) throw conflict('BELOW_RESERVED', `Cannot set stock below ${p.rows[0].reserved_qty} (reserved for open orders)`);
  const r = await tx.query('UPDATE products SET stock_qty=$2 WHERE id=$1 RETURNING stock_qty, reserved_qty', [a.productId, target]);
  await movement(tx, { productId: a.productId, type: a.type ?? 'adjustment', qtyDelta: target - cur, reservedDelta: 0, stockAfter: r.rows[0].stock_qty, reservedAfter: r.rows[0].reserved_qty, reason: a.reason.trim(), adminId: a.adminId });
  return r.rows[0];
}
