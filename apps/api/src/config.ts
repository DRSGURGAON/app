import 'dotenv/config';
import { z } from 'zod';

const schema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().default(4000),
  PUBLIC_BASE_URL: z.string().default('http://localhost:4000'),
  DATABASE_URL: z.string().min(1),
  TEST_DATABASE_URL: z.string().optional(),
  JWT_SECRET: z.string().min(16),
  OTP_HMAC_SECRET: z.string().min(16),
  CORS_ORIGINS: z.string().default(''),
  OTP_PROVIDER: z.enum(['mock', 'msg91']).default('mock'),
  MSG91_AUTH_KEY: z.string().default(''),
  MSG91_TEMPLATE_ID: z.string().default(''),
  // none = no payment gateway: checkout offers COD and (if enabled in Admin → UPI) staff-verified UPI only.
  PAYMENT_PROVIDER: z.enum(['mock', 'razorpay', 'none']).default('mock'),
  RAZORPAY_KEY_ID: z.string().default(''),
  RAZORPAY_KEY_SECRET: z.string().default(''),
  RAZORPAY_WEBHOOK_SECRET: z.string().default(''),
  PAYMENT_MODE: z.enum(['sandbox', 'live']).default('sandbox'),
  ROUTING_PROVIDER: z.enum(['none', 'osrm', 'google']).default('none'),
  OSRM_BASE_URL: z.string().default(''),
  GOOGLE_MAPS_API_KEY: z.string().default(''), // SERVER key (Routes + Places + Geocoding). Never the Android app key.
  GOOGLE_PLACES_ENABLED: z.enum(['true', 'false']).default('true').transform((v) => v === 'true'),
  FCM_PROJECT_ID: z.string().default(''),
  FCM_SERVICE_ACCOUNT_FILE: z.string().default(''),
  STORAGE_DRIVER: z.enum(['local', 's3']).default('local'),
  UPLOAD_DIR: z.string().default('./uploads'),
  S3_ENDPOINT: z.string().default(''),
  S3_REGION: z.string().default(''),
  S3_BUCKET: z.string().default(''),
  S3_ACCESS_KEY_ID: z.string().default(''),
  S3_SECRET_ACCESS_KEY: z.string().default(''),
  S3_PUBLIC_BASE_URL: z.string().default(''),
  ADMIN_DIST_DIR: z.string().default(''),
});

export type Config = z.infer<typeof schema>;

export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  const parsed = schema.safeParse(env);
  if (!parsed.success) {
    const msg = parsed.error.issues.map((i) => `${i.path.join('.')}: ${i.message}`).join('; ');
    throw new Error(`Invalid environment configuration: ${msg}`);
  }
  const c = parsed.data;
  if (c.NODE_ENV === 'production') {
    const problems: string[] = [];
    if (c.OTP_PROVIDER === 'mock') problems.push('OTP_PROVIDER=mock is not allowed in production');
    if (c.PAYMENT_PROVIDER === 'mock') problems.push('PAYMENT_PROVIDER=mock is not allowed in production');
    if (/CHANGE_ME/i.test(c.JWT_SECRET + c.OTP_HMAC_SECRET)) problems.push('JWT_SECRET/OTP_HMAC_SECRET still contain placeholders');
    if (c.PAYMENT_PROVIDER === 'razorpay') {
      if (!c.RAZORPAY_KEY_ID || !c.RAZORPAY_KEY_SECRET || !c.RAZORPAY_WEBHOOK_SECRET) problems.push('Razorpay keys/webhook secret missing');
      if (c.PAYMENT_MODE === 'live' && !c.RAZORPAY_KEY_ID.startsWith('rzp_live_')) problems.push('PAYMENT_MODE=live requires a rzp_live_ key id');
      if (c.PAYMENT_MODE === 'sandbox' && c.RAZORPAY_KEY_ID.startsWith('rzp_live_')) problems.push('live key id used while PAYMENT_MODE=sandbox');
    }
    if (c.OTP_PROVIDER === 'msg91' && (!c.MSG91_AUTH_KEY || !c.MSG91_TEMPLATE_ID)) problems.push('MSG91 credentials missing');
    if (problems.length) throw new Error('Refusing to start: ' + problems.join('; '));
  }
  return c;
}
