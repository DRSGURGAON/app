import { loadConfig } from '../config.js';
import { createPool } from '../db/pool.js';
import { hashPassword } from '../lib/crypto.js';

// Usage: ADMIN_EMAIL=owner@example.com ADMIN_NAME="Owner" ADMIN_PASSWORD='long-password' npm run create-admin
const email = process.env.ADMIN_EMAIL?.trim().toLowerCase(); const password = process.env.ADMIN_PASSWORD; const name = process.env.ADMIN_NAME?.trim() || 'Owner';
const role = (process.env.ADMIN_ROLE ?? 'owner') as 'owner' | 'manager' | 'staff';
if (!email || !password) { console.error('Set ADMIN_EMAIL and ADMIN_PASSWORD (min 10 characters).'); process.exit(1); }
if (password.length < 10) { console.error('Password must be at least 10 characters.'); process.exit(1); }
if (!['owner', 'manager', 'staff'].includes(role)) { console.error('ADMIN_ROLE must be owner, manager or staff.'); process.exit(1); }
const db = createPool(loadConfig().DATABASE_URL, 2);
try {
  const r = await db.query(`INSERT INTO admin_users (email, name, password_hash, role) VALUES ($1,$2,$3,$4)
    ON CONFLICT (email) DO UPDATE SET password_hash=EXCLUDED.password_hash, name=EXCLUDED.name, status='active', failed_logins=0, locked_until=NULL RETURNING id, email, role`, [email, name, await hashPassword(password), role]);
  console.log(`Admin ready: ${r.rows[0].email} (${r.rows[0].role})`);
} finally { await db.end(); }
