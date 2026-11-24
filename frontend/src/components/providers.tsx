'use client';

import { createContext, useContext, useEffect, useState, type ReactNode } from 'react';
import { api, ApiError } from '@/lib/api.mjs';
import type { User } from '@/lib/types';

type Language = 'ru' | 'en';
type AppState = {
  lang: Language;
  toggleLanguage: () => void;
  t: (ru: string, en: string) => string;
  user: User | null;
  setUser: (user: User | null) => void;
  authLoading: boolean;
  authError: boolean;
};

const AppContext = createContext<AppState | null>(null);

export function Providers({ children }: { children: ReactNode }) {
  const [lang, setLang] = useState<Language>('ru');
  const [user, updateUser] = useState<User | null>(null);
  const [session, setSession] = useState<'loading' | 'ready' | 'failed'>('loading');

  useEffect(() => {
    if (session !== 'loading') return;
    const controller = new AbortController();
    const { signal } = controller;
    api.request('/auth/me', { signal })
      .then(user => {
        if (signal.aborted) return;
        updateUser(user);
        setSession('ready');
      })
      .catch(error => {
        if (signal.aborted) return;
        setSession(error instanceof ApiError && error.status === 401 ? 'ready' : 'failed');
      });
    return () => controller.abort();
  }, [session]);

  useEffect(() => { document.documentElement.lang = lang; }, [lang]);

  const value: AppState = {
    lang,
    toggleLanguage: () => setLang(current => current === 'ru' ? 'en' : 'ru'),
    t: (ru, en) => lang === 'ru' ? ru : en,
    user,
    setUser(user) {
      updateUser(user);
      setSession('ready');
    },
    authLoading: session === 'loading',
    authError: session === 'failed',
  };

  return <AppContext.Provider value={value}>{children}</AppContext.Provider>;
}

export function useApp() {
  const state = useContext(AppContext);
  if (!state) throw new Error('Providers missing');
  return state;
}
