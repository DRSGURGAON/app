import React, { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import { en, type Key } from './en';
import { hi } from './hi';
import { kv } from '../lib/storage';

export type Lang = 'en' | 'hi';
const dicts: Record<Lang, Record<Key, string>> = { en, hi };

export function translate(lang: Lang, key: Key, vars?: Record<string, string | number>): string {
  let s = dicts[lang][key] ?? en[key] ?? key;
  if (vars) for (const [k, v] of Object.entries(vars)) s = s.split(`{{${k}}}`).join(String(v));
  return s;
}

interface Ctx { lang: Lang; setLang: (l: Lang) => void; t: (k: Key, v?: Record<string, string | number>) => string; pick: (en?: string | null, hi?: string | null) => string }
const I18n = createContext<Ctx>({ lang: 'en', setLang: () => {}, t: (k) => en[k], pick: (e) => e ?? '' });

export function I18nProvider({ children }: { children: React.ReactNode }) {
  const [lang, setLangState] = useState<Lang>('hi'); // Hindi-first for the store's customers; one tap to switch
  useEffect(() => { kv.get<Lang | null>('ardh.lang', null).then((l) => { if (l === 'en' || l === 'hi') setLangState(l); }); }, []);
  const setLang = useCallback((l: Lang) => { setLangState(l); void kv.set('ardh.lang', l); }, []);
  const value = useMemo<Ctx>(() => ({ lang, setLang, t: (k, v) => translate(lang, k, v), pick: (e, h) => (lang === 'hi' && h ? h : e ?? h ?? '') }), [lang, setLang]);
  return <I18n.Provider value={value}>{children}</I18n.Provider>;
}
export const useI18n = () => useContext(I18n);
export type { Key };
