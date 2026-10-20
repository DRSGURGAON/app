import { api, ApiError, setTokens } from '../src/lib/api';

const json = (status: number, body: unknown) => ({ ok: status < 400, status, text: async () => JSON.stringify(body), json: async () => body }) as any;
afterEach(() => { jest.restoreAllMocks(); });

describe('api client', () => {
  it('maps the server error shape to ApiError', async () => {
    global.fetch = jest.fn(async () => json(422, { error: { code: 'MIN_ORDER_NOT_MET', message: 'Minimum order is ₹999' } })) as any;
    await expect(api('/v1/orders', { method: 'POST', body: {}, auth: false })).rejects.toMatchObject({ status: 422, code: 'MIN_ORDER_NOT_MET', message: 'Minimum order is ₹999' });
  });
  it('reports network failure distinctly', async () => {
    global.fetch = jest.fn(async () => { throw new TypeError('Network request failed'); }) as any;
    const e = await api('/v1/config', { auth: false }).catch((x) => x); expect(e).toBeInstanceOf(ApiError); expect(e.isNetwork).toBe(true);
  });
  it('sends the idempotency key and bearer token', async () => {
    await setTokens('access-1', 'refresh-1');
    const f = jest.fn(async () => json(200, { ok: true })); global.fetch = f as any;
    await api('/v1/orders', { method: 'POST', body: { a: 1 }, idempotencyKey: 'key-123456' });
    const init = (f.mock.calls[0] as any)[1]; expect(init.headers['Idempotency-Key']).toBe('key-123456'); expect(init.headers.Authorization).toBe('Bearer access-1');
  });
  it('refreshes once on 401 and retries the original request with the new token', async () => {
    await setTokens('old', 'refresh-1');
    const calls: string[] = [];
    global.fetch = jest.fn(async (url: string, init: any) => {
      calls.push(`${init.method ?? 'GET'} ${url.replace(/^https?:\/\/[^/]+/, '')} ${init.headers.Authorization ?? ''}`);
      if (url.endsWith('/v1/auth/refresh')) return json(200, { access_token: 'new', refresh_token: 'refresh-2' });
      return init.headers.Authorization === 'Bearer new' ? json(200, { user: { id: 'u' } }) : json(401, { error: { code: 'UNAUTHORIZED', message: 'expired' } });
    }) as any;
    const r = await api('/v1/me'); expect(r.user.id).toBe('u');
    expect(calls).toEqual(['GET /v1/me Bearer old', 'POST /v1/auth/refresh ', 'GET /v1/me Bearer new']);
  });
  it('clears the session when refresh is rejected', async () => {
    await setTokens('old', 'bad-refresh');
    global.fetch = jest.fn(async (url: string) => (url.endsWith('/v1/auth/refresh') ? json(401, { error: { code: 'UNAUTHORIZED', message: 'x' } }) : json(401, { error: { code: 'UNAUTHORIZED', message: 'expired' } }))) as any;
    await expect(api('/v1/me')).rejects.toMatchObject({ status: 401 });
    const f = jest.fn(async () => json(200, {})); global.fetch = f as any; await api('/v1/config', { auth: true });
    expect((f.mock.calls[0] as any)[1].headers.Authorization).toBeUndefined();
  });
});
