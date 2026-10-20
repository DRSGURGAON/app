import { SignJWT, jwtVerify } from 'jose';
import type { Db } from '../db/pool.js';
import { withTx } from '../db/pool.js';
import type { Config } from '../config.js';
import type { OtpSender } from '../providers/otp.js';
import { AppError, forbidden, unauthorized } from '../lib/errors.js';
import { hmacHex, randomOtp, randomToken, safeEqualHex, sha256, verifyPassword } from '../lib/crypto.js';
import { normalizeIndianMobile } from '../lib/phone.js';
import { ensureWallet } from './coins.js';
import { audit } from '../lib/audit.js';

const ACCESS_TTL_USER = '30m';
const ACCESS_TTL_ADMIN = '8h';
const REFRESH_DAYS = 60;
const OTP_TTL_MIN = 5;
const OTP_MAX_ATTEMPTS = 5;

const key = (c: Config) => new TextEncoder().encode(c.JWT_SECRET);

export async function signUserToken(c: Config, userId: string) {
  return new SignJWT({ typ: 'user' }).setProtectedHeader({ alg: 'HS256' }).setSubject(userId).setIssuedAt().setExpirationTime(ACCESS_TTL_USER).sign(key(c));
}
export async function signAdminToken(c: Config, adminId: string) {
  return new SignJWT({ typ: 'admin' }).setProtectedHeader({ alg: 'HS256' }).setSubject(adminId).setIssuedAt().setExpirationTime(ACCESS_TTL_ADMIN).sign(key(c));
}
export async function verifyToken(c: Config, token: string, typ: 'user' | 'admin'): Promise<string> {
  try {
    const { payload } = await jwtVerify(token, key(c), { algorithms: ['HS256'] });
    if (payload.typ !== typ || !payload.sub) throw new Error('wrong token type');
    return payload.sub;
  } catch (e: any) {
    throw new AppError(401, e?.code === 'ERR_JWT_EXPIRED' ? 'TOKEN_EXPIRED' : 'UNAUTHORIZED', e?.code === 'ERR_JWT_EXPIRED' ? 'Session expired. Please log in again.' : 'Please log in to continue');
  }
}

// ------------------------------------------------------------------ OTP
export async function requestOtp(db: Db, c: Config, sender: OtpSender, phoneRaw: string, ip: string | null) {
  const phone = normalizeIndianMobile(phoneRaw);
  if (!phone) throw new AppError(400, 'INVALID_PHONE', 'Enter a valid 10-digit mobile number');
  const recent = await db.query(`SELECT created_at, (SELECT count(*)::int FROM auth_otps WHERE phone=$1 AND created_at > now() - interval '1 hour') AS hourly FROM auth_otps WHERE phone=$1 ORDER BY created_at DESC LIMIT 1`, [phone]);
  if (recent.rowCount) {
    const age = (Date.now() - new Date(recent.rows[0].created_at).getTime()) / 1000;
    if (age < 30) throw new AppError(429, 'OTP_COOLDOWN', `Please wait ${Math.ceil(30 - age)} seconds before requesting another code`, { retry_after: Math.ceil(30 - age) });
    if (recent.rows[0].hourly >= 5) throw new AppError(429, 'OTP_LIMIT', 'Too many codes requested. Please try again in an hour.');
  }
  const u = await db.query(`SELECT status FROM users WHERE phone=$1`, [phone]);
  if (u.rows[0]?.status === 'blocked') throw forbidden('This account has been blocked. Please contact the store.');
  const code = randomOtp();
  await db.query(`INSERT INTO auth_otps (phone, code_hash, expires_at, ip) VALUES ($1,$2, now() + make_interval(mins => $3), $4)`, [phone, hmacHex(c.OTP_HMAC_SECRET, `${phone}:${code}`), OTP_TTL_MIN, ip]);
  try { await sender.send(phone, code); } catch (e) {
    throw new AppError(502, 'OTP_SEND_FAILED', 'We could not send the code right now. Please try again shortly.', { cause: (e as Error).message });
  }
  return { phone, expires_in: OTP_TTL_MIN * 60, ...(sender.devEcho && c.NODE_ENV !== 'production' ? { dev_code: code, dev_notice: 'DEVELOPMENT MODE: OTP shown because OTP_PROVIDER=mock' } : {}) };
}

export async function verifyOtp(db: Db, c: Config, phoneRaw: string, code: string, device: string | null) {
  const phone = normalizeIndianMobile(phoneRaw);
  if (!phone) throw new AppError(400, 'INVALID_PHONE', 'Enter a valid 10-digit mobile number');
  return withTx(db, async (tx) => {
    const r = await tx.query(`SELECT * FROM auth_otps WHERE phone=$1 AND consumed_at IS NULL AND expires_at > now() ORDER BY created_at DESC LIMIT 1 FOR UPDATE`, [phone]);
    if (!r.rowCount) throw new AppError(400, 'OTP_EXPIRED', 'This code has expired. Please request a new one.');
    const otp = r.rows[0];
    if (otp.attempts >= OTP_MAX_ATTEMPTS) throw new AppError(429, 'OTP_ATTEMPTS', 'Too many wrong attempts. Please request a new code.');
    if (!safeEqualHex(otp.code_hash, hmacHex(c.OTP_HMAC_SECRET, `${phone}:${code}`))) {
      await tx.query('UPDATE auth_otps SET attempts = attempts + 1 WHERE id=$1', [otp.id]);
      // commit the attempt counter even though we are about to throw
      await tx.query('COMMIT'); await tx.query('BEGIN');
      throw new AppError(400, 'OTP_INVALID', `Incorrect code. ${Math.max(OTP_MAX_ATTEMPTS - otp.attempts - 1, 0)} attempts left.`);
    }
    await tx.query('UPDATE auth_otps SET consumed_at = now() WHERE id=$1', [otp.id]);
    const found = await tx.query('SELECT * FROM users WHERE phone=$1 FOR UPDATE', [phone]);
    let user = found.rows[0];
    if (user?.status === 'blocked') throw forbidden('This account has been blocked. Please contact the store.');
    if (!user) user = (await tx.query('INSERT INTO users (phone) VALUES ($1) RETURNING *', [phone])).rows[0];
    await ensureWallet(tx, user.id);
    if (user.deletion_requested_at) await tx.query('UPDATE users SET deletion_requested_at = NULL WHERE id=$1', [user.id]); // logging in again cancels a pending request
    const tokens = await issueTokens(tx, c, user.id, device);
    return { user: publicUser(user), ...tokens, is_new: !found.rowCount };
  });
}

export const publicUser = (u: any) => ({ id: u.id, phone: u.phone, name: u.name, email: u.email, language: u.language });

async function issueTokens(q: { query: Db['query'] }, c: Config, userId: string, device: string | null) {
  const refresh = randomToken(48);
  await q.query(`INSERT INTO refresh_tokens (user_id, token_hash, device, expires_at) VALUES ($1,$2,$3, now() + make_interval(days => $4))`, [userId, sha256(refresh), device, REFRESH_DAYS]);
  return { access_token: await signUserToken(c, userId), refresh_token: refresh, expires_in: 30 * 60 };
}

/** Refresh-token rotation with reuse detection: replaying an old token revokes the whole family. */
export async function refreshSession(db: Db, c: Config, refreshToken: string, device: string | null) {
  const h = sha256(refreshToken);
  // The reuse path must commit its revocation, so it cannot run inside the rolled-back transaction.
  let reused: string | null = null;
  const result = await withTx(db, async (tx) => {
    const r = await tx.query('SELECT * FROM refresh_tokens WHERE token_hash=$1 FOR UPDATE', [h]);
    const t = r.rows[0];
    if (!t) throw unauthorized('Session expired. Please log in again.');
    if (t.revoked_at) { reused = t.user_id; return null; }
    if (new Date(t.expires_at) <= new Date()) throw unauthorized('Session expired. Please log in again.');
    const u = (await tx.query('SELECT * FROM users WHERE id=$1', [t.user_id])).rows[0];
    if (!u || u.status !== 'active') throw unauthorized('Session expired. Please log in again.');
    await tx.query('UPDATE refresh_tokens SET revoked_at = now() WHERE id=$1', [t.id]);
    return { user: publicUser(u), ...(await issueTokens(tx, c, u.id, device ?? t.device)) };
  });
  if (reused) {
    await db.query('UPDATE refresh_tokens SET revoked_at = now() WHERE user_id=$1 AND revoked_at IS NULL', [reused]);
    throw unauthorized('Session expired. Please log in again.');
  }
  return result!;
}

export async function logout(db: Db, refreshToken: string | undefined) {
  if (refreshToken) await db.query('UPDATE refresh_tokens SET revoked_at = now() WHERE token_hash=$1 AND revoked_at IS NULL', [sha256(refreshToken)]);
}

// ------------------------------------------------------------------ admin
export const PERMISSIONS = ['catalog:read', 'catalog:write', 'inventory:read', 'inventory:write', 'orders:read', 'orders:write', 'refunds:write', 'offers:write', 'coins:write', 'delivery:write', 'settings:write', 'staff:write', 'customers:read', 'customers:write', 'reports:read', 'audit:read', 'imports:write'] as const;
export type Permission = (typeof PERMISSIONS)[number];
export const ROLE_PERMISSIONS: Record<'owner' | 'manager' | 'staff', Permission[] | '*'> = {
  owner: '*',
  manager: ['catalog:read', 'catalog:write', 'inventory:read', 'inventory:write', 'orders:read', 'orders:write', 'refunds:write', 'offers:write', 'coins:write', 'delivery:write', 'customers:read', 'reports:read', 'imports:write'],
  staff: ['catalog:read', 'inventory:read', 'orders:read', 'orders:write', 'customers:read'],
};
export const hasPermission = (a: { role: 'owner' | 'manager' | 'staff'; extra_permissions: string[] }, p: Permission) => {
  const base = ROLE_PERMISSIONS[a.role];
  return base === '*' || base.includes(p) || a.extra_permissions.includes(p);
};

export async function adminLogin(db: Db, c: Config, email: string, password: string, ip: string | null) {
  const generic = new AppError(401, 'INVALID_CREDENTIALS', 'Incorrect email or password');
  const r = await db.query('SELECT * FROM admin_users WHERE lower(email)=lower($1)', [email.trim()]);
  const a = r.rows[0];
  if (!a) { await verifyPassword(password, 'scrypt$00$00'); throw generic; } // keep timing similar
  if (a.status !== 'active') throw new AppError(403, 'ACCOUNT_DISABLED', 'This account has been disabled');
  if (a.locked_until && new Date(a.locked_until) > new Date()) throw new AppError(429, 'ACCOUNT_LOCKED', 'Too many failed attempts. Try again in a few minutes.');
  if (!(await verifyPassword(password, a.password_hash))) {
    const fails = a.failed_logins + 1;
    await db.query(`UPDATE admin_users SET failed_logins=$2, locked_until = CASE WHEN $3::boolean THEN now() + interval '15 minutes' ELSE NULL END WHERE id=$1`, [a.id, fails >= 5 ? 0 : fails, fails >= 5]);
    await audit(db, { actorType: 'system', action: 'admin.login_failed', entity: 'admin', entityId: a.id, ip });
    throw generic;
  }
  await db.query('UPDATE admin_users SET failed_logins=0, locked_until=NULL, last_login_at=now() WHERE id=$1', [a.id]);
  await audit(db, { actorType: 'admin', actorId: a.id, action: 'admin.login', entity: 'admin', entityId: a.id, ip });
  return { token: await signAdminToken(c, a.id), admin: publicAdmin(a) };
}
export const publicAdmin = (a: any) => ({ id: a.id, email: a.email, name: a.name, role: a.role, permissions: ROLE_PERMISSIONS[a.role as 'owner'] === '*' ? [...PERMISSIONS] : [...new Set([...(ROLE_PERMISSIONS[a.role as 'manager'] as string[]), ...a.extra_permissions])] });
