import React, { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import { api, getRefreshToken, hasSession, setSessionLostHandler, setTokens } from '../lib/api';
import { useI18n } from '../i18n';

export interface User { id: string; phone: string; name: string | null; email: string | null; language: 'en' | 'hi'; deletion_requested_at?: string | null }
interface AuthCtx {
  ready: boolean; user: User | null;
  requestOtp: (phone: string) => Promise<{ dev_code?: string }>;
  verifyOtp: (phone: string, code: string) => Promise<{ is_new: boolean }>;
  updateProfile: (p: { name?: string; email?: string | null }) => Promise<void>;
  refreshUser: () => Promise<void>; logout: () => Promise<void>;
}
const Ctx = createContext<AuthCtx>(null as any);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null); const [ready, setReady] = useState(false);
  const { setLang } = useI18n();

  const refreshUser = useCallback(async () => {
    try { const r = await api<{ user: User }>('/v1/me'); setUser(r.user); } catch (e: any) { if (e?.status === 401) setUser(null); }
  }, []);
  useEffect(() => {
    setSessionLostHandler(() => setUser(null));
    (async () => { if (await hasSession()) await refreshUser(); setReady(true); })();
  }, [refreshUser]);

  const value = useMemo<AuthCtx>(() => ({
    ready, user, refreshUser,
    requestOtp: async (phone) => { const r = await api<{ dev_code?: string }>('/v1/auth/otp/request', { method: 'POST', body: { phone }, auth: false }); return { dev_code: r.dev_code }; },
    verifyOtp: async (phone, code) => {
      const r = await api<any>('/v1/auth/otp/verify', { method: 'POST', body: { phone, code, device: 'android' }, auth: false });
      await setTokens(r.access_token, r.refresh_token); setUser(r.user); if (r.user?.language) setLang(r.user.language);
      return { is_new: !!r.is_new };
    },
    updateProfile: async (p) => { const r = await api<{ user: User }>('/v1/me', { method: 'PATCH', body: p }); setUser((u) => ({ ...(u as User), ...r.user })); },
    logout: async () => { const rt = await getRefreshToken(); try { if (rt) await api('/v1/auth/logout', { method: 'POST', body: { refresh_token: rt }, auth: false }); } catch { /* offline logout still clears the device */ } await setTokens(null, null); setUser(null); },
  }), [ready, user, refreshUser, setLang]);
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}
export const useAuth = () => useContext(Ctx);
