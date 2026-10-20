import { loadConfig } from '../config.js';
import { createPool, withTx } from './pool.js';

/**
 * Usage: npm run seed            -> the 9 store categories + sub-categories only (safe for production, idempotent)
 *        npm run seed -- --sample -> also adds clearly labelled SAMPLE products, zones and a coupon for testing (never use in production)
 */
export const CATEGORIES: { name: string; hi: string; subs: [string, string][] }[] = [
  { name: 'Grocery & Daily Needs', hi: 'किराना और रोज़मर्रा का सामान', subs: [['Dal & Pulses', 'दालें'], ['Rice & Flour', 'चावल और आटा'], ['Salt, Sugar & Jaggery', 'नमक, चीनी और गुड़'], ['Cooking Oil & Ghee', 'तेल और घी'], ['Tea & Coffee', 'चाय और कॉफ़ी'], ['Health Drinks', 'हेल्थ ड्रिंक']] },
  { name: 'Bakery, Snacks & Sweets', hi: 'बेकरी, स्नैक्स और मिठाई', subs: [['Biscuits & Chocopie', 'बिस्कुट और चॉकोपाई'], ['Namkeen & Mixture', 'नमकीन और मिक्सचर'], ['Chips', 'चिप्स'], ['Packaged Sweets', 'पैकेट मिठाई']] },
  { name: 'Soft Drinks & Chocolates', hi: 'कोल्ड ड्रिंक और चॉकलेट', subs: [['Soft Drinks', 'कोल्ड ड्रिंक'], ['Chocolates', 'चॉकलेट']] },
  { name: 'Cosmetics & Personal Care', hi: 'कॉस्मेटिक्स और पर्सनल केयर', subs: [['Soaps & Bath', 'साबुन और नहाने का सामान'], ['Hair Care', 'बालों की देखभाल'], ['Skin Care & Beauty', 'स्किन केयर और ब्यूटी'], ['Perfume & Deodorant', 'परफ्यूम और डियो'], ['Oral Care', 'दाँतों की देखभाल']] },
  { name: 'Baby Care', hi: 'बेबी केयर', subs: [['Diapers', 'डायपर'], ['Wipes', 'वाइप्स'], ['Baby Essentials', 'बच्चों का ज़रूरी सामान']] },
  { name: 'Housekeeping & Cleaning', hi: 'हाउसकीपिंग और सफ़ाई', subs: [['Toilet & Bathroom Cleaners', 'टॉयलेट और बाथरूम क्लीनर'], ['Floor Mops & Wipers', 'पोछा और वाइपर'], ['Mop Sets', 'मॉप सेट']] },
  { name: 'Electrical Items', hi: 'बिजली का सामान', subs: [['LED Bulbs & Tube Lights', 'एलईडी बल्ब और ट्यूबलाइट'], ['Extension Cords', 'एक्सटेंशन कॉर्ड'], ['Plugs & Sockets', 'प्लग और सॉकेट'], ['Electrical Accessories', 'बिजली के अन्य सामान']] },
  { name: 'Dry Fruits & Healthy Snacks', hi: 'ड्राई फ्रूट्स और हेल्दी स्नैक्स', subs: [['Almonds & Cashews', 'बादाम और काजू'], ['Raisins & Pistachios', 'किशमिश और पिस्ता'], ['Makhana', 'मखाना']] },
  { name: 'Stationery & School Supplies', hi: 'स्टेशनरी और स्कूल का सामान', subs: [['Notebooks & Registers', 'कॉपी और रजिस्टर'], ['Pens, Pencils & Erasers', 'पेन, पेंसिल और रबर'], ['Geometry Boxes & Rulers', 'ज्योमेट्री बॉक्स और स्केल'], ['Crayons & Colours', 'क्रेयॉन और रंग'], ['School Bags & Pouches', 'स्कूल बैग और पाउच'], ['Art & Craft', 'आर्ट और क्राफ्ट'], ['Files, Folders & Envelopes', 'फ़ाइल, फ़ोल्डर और लिफ़ाफ़े'], ['Glue, Tape, Staplers & Scissors', 'गोंद, टेप, स्टेपलर और कैंची'], ['Office Stationery', 'ऑफ़िस स्टेशनरी']] },
];
const slug = (s: string) => s.toLowerCase().replace(/&/g, 'and').replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');

const sampleProducts: [string, string, string, string, number, number, number][] = [
  // sku, name, category, sub, mrp, price, stock
  ['SAMPLE-DAL-1', '[SAMPLE] Toor Dal 1 kg', 'Grocery & Daily Needs', 'Dal & Pulses', 190, 175, 40],
  ['SAMPLE-RICE-5', '[SAMPLE] Basmati Rice 5 kg', 'Grocery & Daily Needs', 'Rice & Flour', 620, 575, 25],
  ['SAMPLE-OIL-1', '[SAMPLE] Refined Oil 1 L', 'Grocery & Daily Needs', 'Cooking Oil & Ghee', 165, 150, 60],
  ['SAMPLE-BISC-1', '[SAMPLE] Glucose Biscuit Family Pack', 'Bakery, Snacks & Sweets', 'Biscuits & Chocopie', 50, 45, 80],
  ['SAMPLE-SOAP-1', '[SAMPLE] Bathing Soap (Pack of 4)', 'Cosmetics & Personal Care', 'Soaps & Bath', 180, 160, 50],
  ['SAMPLE-LED-9', '[SAMPLE] LED Bulb 9W', 'Electrical Items', 'LED Bulbs & Tube Lights', 120, 99, 100],
  ['SAMPLE-NB-1', '[SAMPLE] Notebook 172 pages (Pack of 6)', 'Stationery & School Supplies', 'Notebooks & Registers', 330, 299, 45],
  ['SAMPLE-PEN-1', '[SAMPLE] Ball Pen Blue (Box of 20)', 'Stationery & School Supplies', 'Pens, Pencils & Erasers', 120, 100, 70],
  ['SAMPLE-GEO-1', '[SAMPLE] Geometry Box', 'Stationery & School Supplies', 'Geometry Boxes & Rulers', 95, 85, 30],
];

export async function seedCategories(db: ReturnType<typeof createPool>) {
  let created = 0;
  await withTx(db, async (tx) => {
    let order = 0;
    for (const c of CATEGORIES) {
      order += 10;
      const parent = (await tx.query(`INSERT INTO categories (name, name_hi, slug, sort_order) VALUES ($1,$2,$3,$4) ON CONFLICT (slug) DO UPDATE SET slug=categories.slug RETURNING id, (xmax = 0) AS inserted`, [c.name, c.hi, slug(c.name), order])).rows[0];
      if (parent.inserted) created++;
      let so = 0;
      for (const [n, hi] of c.subs) {
        so += 10;
        const r = await tx.query(`INSERT INTO categories (parent_id, name, name_hi, slug, sort_order) VALUES ($1,$2,$3,$4,$5) ON CONFLICT (slug) DO NOTHING RETURNING id`, [parent.id, n, hi, `${slug(c.name)}--${slug(n)}`, so]);
        if (r.rowCount) created++;
      }
    }
  });
  return created;
}

export async function seedSample(db: ReturnType<typeof createPool>) {
  await withTx(db, async (tx) => {
    for (const [sku, name, cat, sub, mrp, price, stock] of sampleProducts) {
      const c = (await tx.query('SELECT id FROM categories WHERE parent_id IS NULL AND name=$1', [cat])).rows[0];
      const s = (await tx.query('SELECT id FROM categories WHERE parent_id=$1 AND name=$2', [c.id, sub])).rows[0];
      const r = await tx.query(`INSERT INTO products (sku, name, category_id, subcategory_id, mrp, price, stock_qty, is_sample) VALUES ($1,$2,$3,$4,$5,$6,$7,true) ON CONFLICT (sku) DO NOTHING RETURNING id`, [sku, name, c.id, s.id, mrp, price, stock]);
      if (r.rowCount) await tx.query(`INSERT INTO stock_movements (product_id, type, qty_delta, stock_after, reserved_after, reason) VALUES ($1,'opening',$2,$2,0,'Sample data')`, [r.rows[0].id, stock]);
    }
    if (!(await tx.query('SELECT 1 FROM delivery_zones LIMIT 1')).rowCount) {
      await tx.query(`INSERT INTO delivery_zones (name, name_hi, pincodes, fee_mode, sort_order) VALUES ('Loharu town (SAMPLE)', 'लोहारू शहर', '{127308}', 'base', 1), ('Nearby villages (SAMPLE)', 'आसपास के गाँव', '{}', 'far', 2)`);
    }
    await tx.query(`INSERT INTO coupons (code, title, description, discount_type, discount_value, min_spend, max_discount, starts_at, ends_at, is_public)
      VALUES ('SAMPLE50', 'SAMPLE: ₹50 off', 'Sample coupon for testing only', 'fixed', 50, 999, NULL, now(), now() + interval '30 days', true) ON CONFLICT (code) DO NOTHING`);
  });
}

if (process.argv[1] && import.meta.url.endsWith(process.argv[1].split('/').pop()!)) {
  const db = createPool(loadConfig().DATABASE_URL, 2);
  try {
    console.log(`Categories created: ${await seedCategories(db)}`);
    if (process.argv.includes('--sample')) { if (loadConfig().NODE_ENV === 'production') throw new Error('Refusing to add sample data in production'); await seedSample(db); console.log('Sample products, zones and coupon added (labelled SAMPLE).'); }
  } finally { await db.end(); }
}
