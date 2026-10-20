import ExcelJS from 'exceljs';
import { parse as parseCsv } from 'csv-parse/sync';
import { withTx, type Db } from '../db/pool.js';
import { AppError, conflict, notFound } from '../lib/errors.js';
import { audit } from '../lib/audit.js';
import { adjustStock } from './stock.js';

export const IMPORT_COLUMNS = ['sku', 'name', 'name_hi', 'brand', 'category', 'subcategory', 'unit', 'pack_size', 'mrp', 'price', 'tax_rate', 'hsn_code', 'barcode', 'stock_qty', 'low_stock_threshold', 'description', 'is_active'] as const;
type Col = (typeof IMPORT_COLUMNS)[number];
export const MAX_IMPORT_ROWS = 5000;
const REQUIRED: Col[] = ['sku', 'name', 'category', 'mrp', 'price'];
const COMPARE = ['name', 'name_hi', 'brand', 'category_id', 'subcategory_id', 'unit', 'pack_size', 'mrp', 'price', 'tax_rate', 'hsn_code', 'barcode', 'low_stock_threshold', 'description', 'is_active'] as const;

export interface ImportOptions { apply_updates: boolean; update_stock: boolean }
export interface PlanRow { row: number; sku: string; action: 'create' | 'update' | 'unchanged'; values: Record<string, any>; stock_qty: number | null; diff: Record<string, { from: unknown; to: unknown }>; stock_change: { from: number; to: number } | null; before: Record<string, unknown> | null }

export const templateRows = [
  ['SAMPLE-001', 'Example Basmati Rice 5kg', 'उदाहरण बासमती चावल 5 किलो', 'ExampleBrand', 'Grocery & Staples', 'Rice', 'kg', '5 kg', '620', '575', '5', '10063010', '', '20', '5', 'Delete this example row before importing', 'yes'],
];

function cellText(v: any): string {
  if (v === null || v === undefined) return '';
  if (v instanceof Date) return v.toISOString();
  if (typeof v === 'object') { if ('result' in v) return cellText(v.result); if ('text' in v) return String(v.text).trim(); if ('richText' in v) return v.richText.map((t: any) => t.text).join('').trim(); return String(v).trim(); }
  return String(v).trim();
}

export async function parseUpload(filename: string, buf: Buffer): Promise<Record<string, string>[]> {
  const lower = filename.toLowerCase();
  let table: string[][];
  if (lower.endsWith('.csv')) {
    let text = buf.toString('utf8'); if (text.charCodeAt(0) === 0xfeff) text = text.slice(1);
    try { table = parseCsv(text, { skip_empty_lines: true, relax_column_count: true, trim: true }) as string[][]; } catch (e: any) { throw new AppError(400, 'BAD_FILE', `Could not read the CSV: ${e.message}`); }
  } else if (lower.endsWith('.xlsx')) {
    const wb = new ExcelJS.Workbook();
    try { await wb.xlsx.load(buf as any); } catch { throw new AppError(400, 'BAD_FILE', 'Could not read this Excel file. Save it as .xlsx or .csv and try again.'); }
    const ws = wb.worksheets[0]; if (!ws) throw new AppError(400, 'BAD_FILE', 'The workbook has no sheets');
    table = []; ws.eachRow({ includeEmpty: false }, (row) => { const vals: string[] = []; for (let c = 1; c <= IMPORT_COLUMNS.length + 5; c++) vals.push(cellText(row.getCell(c).value)); table.push(vals); });
  } else throw new AppError(400, 'BAD_FILE', 'Upload a .csv or .xlsx file');
  if (table.length < 2) throw new AppError(400, 'EMPTY_FILE', 'The file has no data rows');
  const header = table[0].map((h) => h.toLowerCase().replace(/\s+/g, '_'));
  const missing = REQUIRED.filter((c) => !header.includes(c));
  if (missing.length) throw new AppError(400, 'MISSING_COLUMNS', `Missing required column(s): ${missing.join(', ')}. Download the template to see the expected columns.`);
  const body = table.slice(1);
  if (body.length > MAX_IMPORT_ROWS) throw new AppError(400, 'TOO_MANY_ROWS', `Too many rows (${body.length}). Split the file into batches of ${MAX_IMPORT_ROWS} or fewer.`);
  return body.map((r) => { const o: Record<string, string> = {}; header.forEach((h, i) => { if (h) o[h] = (r[i] ?? '').toString().trim(); }); return o; });
}

const num2 = (v: string) => (/^\d{1,9}(\.\d{1,2})?$/.test(v) ? Number(v).toFixed(2) : null);
const bool = (v: string): boolean | null => { const s = v.toLowerCase(); if (['', 'yes', 'y', 'true', '1', 'active'].includes(s)) return true; if (['no', 'n', 'false', '0', 'hidden', 'inactive'].includes(s)) return false; return null; };

export async function buildPreview(db: Db, adminId: string, filename: string, buf: Buffer, options: ImportOptions) {
  const rows = await parseUpload(filename, buf);
  const cats = (await db.query('SELECT id, parent_id, name, slug FROM categories')).rows;
  const findCat = (name: string, parent: string | null) => cats.find((c) => (c.parent_id ?? null) === parent && (c.name.toLowerCase() === name.toLowerCase() || c.slug === name.toLowerCase()));
  const existing = new Map<string, any>((await db.query('SELECT * FROM products')).rows.map((p) => [p.sku.toLowerCase(), p]));
  const errors: { row: number; field: string | null; message: string; raw: any }[] = []; const plan: PlanRow[] = []; const seen = new Map<string, number>();
  rows.forEach((raw, i) => {
    const rowNo = i + 2; const errs: [string | null, string][] = [];
    if (Object.values(raw).every((v) => !v)) return;
    const sku = raw.sku ?? ''; if (!sku) errs.push(['sku', 'SKU is required']); else if (!/^[A-Za-z0-9._-]{1,40}$/.test(sku)) errs.push(['sku', 'SKU may only use letters, numbers, - _ . (max 40)']);
    if (sku) { const k = sku.toLowerCase(); if (seen.has(k)) errs.push(['sku', `Duplicate SKU (also on row ${seen.get(k)})`]); else seen.set(k, rowNo); }
    if (!raw.name || raw.name.length < 2) errs.push(['name', 'Name is required']);
    const mrp = num2(raw.mrp ?? ''), price = num2(raw.price ?? '');
    if (mrp === null) errs.push(['mrp', 'MRP must be a number like 120 or 120.50']); if (price === null) errs.push(['price', 'Price must be a number like 99 or 99.50']);
    if (mrp !== null && price !== null && Number(price) > Number(mrp)) errs.push(['price', 'Selling price is higher than MRP']);
    const cat = raw.category ? findCat(raw.category, null) : null; if (!cat) errs.push(['category', raw.category ? `Unknown category "${raw.category}". Create it in Categories first.` : 'Category is required']);
    let sub: any = null; if (raw.subcategory) { sub = cat ? findCat(raw.subcategory, cat.id) : null; if (cat && !sub) errs.push(['subcategory', `Unknown sub-category "${raw.subcategory}" under ${cat.name}`]); }
    const tax = raw.tax_rate ? Number(raw.tax_rate) : 0; if (!Number.isFinite(tax) || tax < 0 || tax > 100) errs.push(['tax_rate', 'Tax rate must be between 0 and 100']);
    let stock: number | null = null; if (raw.stock_qty) { if (!/^\d{1,7}$/.test(raw.stock_qty)) errs.push(['stock_qty', 'Stock must be a whole number (0 or more)']); else stock = Number(raw.stock_qty); }
    let low = 5; if (raw.low_stock_threshold) { if (!/^\d{1,6}$/.test(raw.low_stock_threshold)) errs.push(['low_stock_threshold', 'Must be a whole number']); else low = Number(raw.low_stock_threshold); }
    const active = bool(raw.is_active ?? ''); if (active === null) errs.push(['is_active', 'Use yes or no']);
    if ((raw.name ?? '').length > 160) errs.push(['name', 'Name is too long (max 160)']);
    if (errs.length) { for (const [f, m] of errs) errors.push({ row: rowNo, field: f, message: m, raw }); return; }
    const values = { sku, name: raw.name, name_hi: raw.name_hi || null, brand: raw.brand || null, category_id: cat.id, subcategory_id: sub?.id ?? null, unit: raw.unit || 'pc', pack_size: raw.pack_size || null,
      mrp, price, tax_rate: tax.toFixed(2), hsn_code: raw.hsn_code || null, barcode: raw.barcode || null, low_stock_threshold: low, description: raw.description || null, is_active: active };
    const cur = existing.get(sku.toLowerCase());
    if (!cur) { plan.push({ row: rowNo, sku, action: 'create', values, stock_qty: stock ?? 0, diff: {}, stock_change: null, before: null }); return; }
    const diff: PlanRow['diff'] = {}; const before: Record<string, unknown> = {};
    for (const k of COMPARE) { const a = norm(cur[k]); before[k] = a; const b = norm((values as any)[k]); if (a !== b) diff[k] = { from: a, to: b }; }
    const stock_change = stock !== null && options.update_stock && stock !== cur.stock_qty ? { from: cur.stock_qty as number, to: stock } : null;
    plan.push({ row: rowNo, sku: cur.sku, action: Object.keys(diff).length || stock_change ? 'update' : 'unchanged', values, stock_qty: stock, diff, stock_change, before: { ...before, stock_qty: cur.stock_qty } });
  });
  const counts = { create: plan.filter((p) => p.action === 'create').length, update: plan.filter((p) => p.action === 'update').length, unchanged: plan.filter((p) => p.action === 'unchanged').length };
  const job = await withTx(db, async (tx) => {
    const j = (await tx.query(`INSERT INTO import_jobs (admin_id, filename, options, total_rows, valid_rows, invalid_rows, create_count, update_count, unchanged_count, plan) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) RETURNING id`,
      [adminId, filename.slice(0, 200), options, rows.length, plan.length, new Set(errors.map((e) => e.row)).size, counts.create, counts.update, counts.unchanged, JSON.stringify(plan)])).rows[0];
    for (const e of errors.slice(0, 1000)) await tx.query('INSERT INTO import_errors (job_id,row_no,field,message,raw) VALUES ($1,$2,$3,$4,$5)', [j.id, e.row, e.field, e.message, JSON.stringify(e.raw)]);
    return j;
  });
  return { job_id: job.id as string, total_rows: rows.length, valid_rows: plan.length, invalid_rows: new Set(errors.map((e) => e.row)).size, counts, errors: errors.slice(0, 200), sample: plan.filter((p) => p.action !== 'unchanged').slice(0, 50), options };
}
const norm = (v: unknown) => (v === null || v === undefined ? null : typeof v === 'string' ? v : typeof v === 'number' ? String(v) : v === true || v === false ? v : String(v));

/** Apply a previewed job exactly once. Rows whose product changed since the preview are skipped, never overwritten. Invalid rows are never imported. */
export async function confirmImport(db: Db, jobId: string, adminId: string, ip: string | null, opts: { apply_updates?: boolean } = {}) {
  return withTx(db, async (tx) => {
    const job = (await tx.query('SELECT * FROM import_jobs WHERE id=$1 FOR UPDATE', [jobId])).rows[0]; if (!job) throw notFound('Import not found');
    if (job.status !== 'previewed') throw conflict('ALREADY_PROCESSED', job.status === 'applied' ? 'This import was already applied.' : 'This import can no longer be applied. Upload the file again.');
    if (job.admin_id && job.admin_id !== adminId) throw conflict('NOT_YOURS', 'Only the person who uploaded this file can confirm it.');
    const applyUpdates = opts.apply_updates ?? job.options.apply_updates ?? false;
    const plan: PlanRow[] = job.plan; const res = { created: 0, updated: 0, unchanged: 0, skipped_updates: 0, conflicts: [] as { row: number; sku: string; message: string }[] };
    for (const p of plan) {
      const v = p.values;
      if (p.action === 'unchanged') { res.unchanged++; continue; }
      if (p.action === 'create') {
        const ex = (await tx.query('SELECT 1 FROM products WHERE lower(sku)=lower($1)', [p.sku])).rowCount;
        if (ex) { res.conflicts.push({ row: p.row, sku: p.sku, message: 'SKU was created by someone else after the preview; skipped' }); continue; }
        const r = (await tx.query(`INSERT INTO products (sku,barcode,name,name_hi,brand,category_id,subcategory_id,description,unit,pack_size,mrp,price,tax_rate,hsn_code,low_stock_threshold,is_active) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16) RETURNING id`,
          [v.sku, v.barcode, v.name, v.name_hi, v.brand, v.category_id, v.subcategory_id, v.description, v.unit, v.pack_size, v.mrp, v.price, v.tax_rate, v.hsn_code, v.low_stock_threshold, v.is_active])).rows[0];
        if (p.stock_qty) await adjustStock(tx, { productId: r.id, delta: p.stock_qty, reason: `Import: ${job.filename}`, adminId, type: 'import' });
        res.created++; continue;
      }
      if (!applyUpdates) { res.skipped_updates++; continue; }
      const cur = (await tx.query('SELECT * FROM products WHERE lower(sku)=lower($1) FOR UPDATE', [p.sku])).rows[0];
      if (!cur) { res.conflicts.push({ row: p.row, sku: p.sku, message: 'Product no longer exists; skipped' }); continue; }
      const drifted = Object.entries(p.before ?? {}).some(([k, val]) => k !== 'stock_qty' && norm(cur[k]) !== val);
      if (drifted) { res.conflicts.push({ row: p.row, sku: p.sku, message: 'Product was edited after the preview; skipped so nothing is overwritten. Re-upload to compare again.' }); continue; }
      if (Object.keys(p.diff).length) {
        await tx.query(`UPDATE products SET name=$2,name_hi=$3,brand=$4,category_id=$5,subcategory_id=$6,unit=$7,pack_size=$8,mrp=$9,price=$10,tax_rate=$11,hsn_code=$12,barcode=$13,low_stock_threshold=$14,description=$15,is_active=$16 WHERE id=$1`,
          [cur.id, v.name, v.name_hi, v.brand, v.category_id, v.subcategory_id, v.unit, v.pack_size, v.mrp, v.price, v.tax_rate, v.hsn_code, v.barcode, v.low_stock_threshold, v.description, v.is_active]);
      }
      if (p.stock_change) {
        if (cur.stock_qty !== p.stock_change.from) { res.conflicts.push({ row: p.row, sku: p.sku, message: 'Stock changed after the preview (orders or edits); stock left as is' }); }
        else { try { await adjustStock(tx, { productId: cur.id, setTo: p.stock_change.to, reason: `Import: ${job.filename}`, adminId, type: 'import' }); } catch (e: any) { res.conflicts.push({ row: p.row, sku: p.sku, message: e.message }); } }
      }
      res.updated++;
    }
    await tx.query(`UPDATE import_jobs SET status='applied', applied_at=now() WHERE id=$1`, [jobId]);
    await audit(tx, { actorType: 'admin', actorId: adminId, action: 'import.apply', entity: 'import', entityId: jobId, after: { filename: job.filename, ...res, apply_updates: applyUpdates }, ip });
    return res;
  });
}

export async function buildTemplate(db: Db, kind: 'csv' | 'xlsx'): Promise<{ body: Buffer; contentType: string; filename: string }> {
  const cats = (await db.query('SELECT c.name, p.name AS parent FROM categories c LEFT JOIN categories p ON p.id=c.parent_id WHERE c.is_active ORDER BY p.name NULLS FIRST, c.sort_order, c.name')).rows;
  if (kind === 'csv') {
    const q = (s: string) => (/[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s);
    const text = '﻿' + [IMPORT_COLUMNS.join(','), ...templateRows.map((r) => r.map(q).join(','))].join('\r\n') + '\r\n';
    return { body: Buffer.from(text, 'utf8'), contentType: 'text/csv; charset=utf-8', filename: 'product-import-template.csv' };
  }
  const wb = new ExcelJS.Workbook(); const ws = wb.addWorksheet('Products'); ws.addRow([...IMPORT_COLUMNS]); ws.getRow(1).font = { bold: true }; templateRows.forEach((r) => ws.addRow(r));
  ws.columns.forEach((c) => { c.width = 18; });
  const help = wb.addWorksheet('Instructions');
  [['Required columns: sku, name, category, mrp, price'], ['price cannot be more than mrp. Amounts are in rupees.'], ['category / subcategory must match an existing name (see the Categories sheet).'], ['is_active: yes or no (blank = yes). stock_qty: whole number.'], ['Existing SKUs are only changed if you tick "update existing products" when confirming; you see every change first.'], ['Delete the SAMPLE-001 example row before importing.']].forEach((r) => help.addRow(r));
  help.getColumn(1).width = 110;
  const cs = wb.addWorksheet('Categories'); cs.addRow(['category / sub-category', 'parent']); cats.forEach((c) => cs.addRow([c.name, c.parent ?? '']));
  return { body: Buffer.from(await wb.xlsx.writeBuffer()), contentType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', filename: 'product-import-template.xlsx' };
}
