import type { Config } from '../config.js';

export interface OtpSender {
  readonly name: 'mock' | 'msg91';
  /** true => the code may be echoed back to the caller (development only). */
  readonly devEcho: boolean;
  send(phone10: string, code: string): Promise<void>;
}

export class MockOtpSender implements OtpSender {
  readonly name = 'mock' as const;
  readonly devEcho = true;
  readonly sent: Array<{ phone: string; code: string }> = [];
  async send(phone: string, code: string) { this.sent.push({ phone, code }); }
}

/** MSG91 OTP API v5. Requires an approved DLT template. Not exercised in this sandbox (no network access to MSG91). */
export class Msg91OtpSender implements OtpSender {
  readonly name = 'msg91' as const;
  readonly devEcho = false;
  constructor(private authKey: string, private templateId: string, private fetchImpl: typeof fetch = fetch) {}
  async send(phone: string, code: string) {
    const url = new URL('https://control.msg91.com/api/v5/otp');
    url.searchParams.set('template_id', this.templateId);
    url.searchParams.set('mobile', `91${phone}`);
    url.searchParams.set('otp', code);
    const res = await this.fetchImpl(url, { method: 'POST', headers: { authkey: this.authKey, 'content-type': 'application/json' }, body: '{}', signal: AbortSignal.timeout(10000) });
    const body: any = await res.json().catch(() => ({}));
    if (!res.ok || body?.type === 'error') throw new Error(`MSG91 send failed: ${res.status} ${body?.message ?? ''}`);
  }
}

export function createOtpSender(c: Config): OtpSender {
  return c.OTP_PROVIDER === 'msg91' ? new Msg91OtpSender(c.MSG91_AUTH_KEY, c.MSG91_TEMPLATE_ID) : new MockOtpSender();
}
