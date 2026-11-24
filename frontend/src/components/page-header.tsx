'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useState } from 'react';
import { api } from '@/lib/api.mjs';
import { navigationFor } from '@/lib/navigation';
import { useApp } from './providers';

export function PageHeader({ title }: { title: string }) {
  const { t, user, setUser, toggleLanguage, lang, authLoading, authError } = useApp();
  const path = usePathname();
  const [logoutState, setLogoutState] = useState<'idle' | 'pending' | 'failed'>('idle');

  async function logout() {
    setLogoutState('pending');
    try {
      await api.logout();
      setUser(null);
      setLogoutState('idle');
    } catch {
      setLogoutState('failed');
    }
  }

  return (
    <header>
      <div className="topbar">
        <h1>{title}</h1>
        <div className="actions">
          <Link href="/">SEED VAULT</Link>
          <button onClick={toggleLanguage} aria-label={t('Сменить язык', 'Change language')}>
            {lang === 'ru' ? 'EN' : 'RU'}
          </button>
          {authLoading ? <span role="status">{t('Проверка сессии…', 'Checking session…')}</span> : user ? (
            <>
              <span className="email">{user.email}</span>
              <button disabled={logoutState === 'pending'} onClick={logout}>
                {t('Выйти', 'Sign out')}
              </button>
            </>
          ) : <Link href="/login">{t('Войти', 'Sign in')}</Link>}
        </div>
      </div>
      <nav aria-label={t('Основная навигация', 'Main navigation')}>
        {navigationFor(user).map(link => (
          <Link key={link.href} href={link.href} aria-current={link.href === path ? 'page' : undefined}>
            {link[lang]}
          </Link>
        ))}
      </nav>

      {authError && <p className="notice">{t('Не удалось проверить сессию. Обновите страницу.', 'Could not check the session. Reload the page.')}</p>}
      {logoutState === 'failed' && <p role="alert">{t('Не удалось выйти. Повторите попытку.', 'Sign out failed. Try again.')}</p>}
    </header>
  );
}
