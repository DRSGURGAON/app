import { readFile } from 'node:fs/promises';
import { SignJWT, importPKCS8 } from 'jose';
import type { Config } from '../config.js';

export interface PushSender {
  readonly configured: boolean;
  /** Returns 'sent' | 'invalid_token' | throws on transient failure */
  send(token: string, title: string, body: string, data: Record<string, string>): Promise<'sent' | 'invalid_token'>;
}

export class NoopPush implements PushSender {
  readonly configured = false;
  async send(): Promise<'sent'> { return 'sent'; }
}

/** Firebase Cloud Messaging HTTP v1 using a service-account JSON. Not exercised in this sandbox (Google hosts are blocked). */
export class FcmPush implements PushSender {
  readonly configured = true;
  private cached?: { token: string; exp: number };
  constructor(private projectId: string, private saFile: string, private fetchImpl: typeof fetch = fetch) {}

  private async accessToken(): Promise<string> {
    if (this.cached && this.cached.exp > Date.now() + 60_000) return this.cached.token;
    const sa = JSON.parse(await readFile(this.saFile, 'utf8'));
    const key = await importPKCS8(sa.private_key, 'RS256');
    const jwt = await new SignJWT({ scope: 'https://www.googleapis.com/auth/firebase.messaging' })
      .setProtectedHeader({ alg: 'RS256', typ: 'JWT' }).setIssuer(sa.client_email).setSubject(sa.client_email)
      .setAudience('https://oauth2.googleapis.com/token').setIssuedAt().setExpirationTime('55m').sign(key);
    const res = await this.fetchImpl('https://oauth2.googleapis.com/token', {
      method: 'POST', headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion: jwt }),
    });
    const j: any = await res.json();
    if (!res.ok) throw new Error(`FCM auth failed: ${res.status}`);
    this.cached = { token: j.access_token, exp: Date.now() + (j.expires_in ?? 3300) * 1000 };
    return this.cached.token;
  }

  async send(token: string, title: string, body: string, data: Record<string, string>) {
    const at = await this.accessToken();
    const res = await this.fetchImpl(`https://fcm.googleapis.com/v1/projects/${this.projectId}/messages:send`, {
      method: 'POST', headers: { authorization: `Bearer ${at}`, 'content-type': 'application/json' },
      body: JSON.stringify({ message: { token, notification: { title, body }, data, android: { priority: 'HIGH', notification: { channel_id: 'orders' } } } }),
    });
    if (res.ok) return 'sent' as const;
    const j: any = await res.json().catch(() => ({}));
    if (res.status === 404 || j?.error?.status === 'UNREGISTERED' || j?.error?.status === 'INVALID_ARGUMENT') return 'invalid_token' as const;
    throw new Error(`FCM send failed: ${res.status}`);
  }
}

export function createPush(c: Config): PushSender {
  return c.FCM_PROJECT_ID && c.FCM_SERVICE_ACCOUNT_FILE ? new FcmPush(c.FCM_PROJECT_ID, c.FCM_SERVICE_ACCOUNT_FILE) : new NoopPush();
}
