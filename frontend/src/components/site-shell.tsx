'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useState, type ReactNode } from 'react';
import { api } from '@/lib/api.mjs';
import { navigationFor } from '@/lib/navigation';
import { SessionNotice } from './page-header';
import { useApp } from './providers';

const icons: Record<string, ReactNode> = {
  '/workspace': <><rect x="3" y="3" width="7" height="7" rx="1" /><rect x="14" y="3" width="7" height="7" rx="1" /><rect x="3" y="14" width="7" height="7" rx="1" /><rect x="14" y="14" width="7" height="7" rx="1" /></>,
  '/workspace/batches': <path d="M3 8l4-5h10l4 5v12a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V8Zm0 0h18m-12 5h6" />,
  '/workspace/withdrawals': <path d="m12 2 9 4v12l-9 4-9-4V6l9-4Zm0 7v7m-3-3 3 3 3-3" />,
  '/workspace/intake': <path d="M3 11 12 4l9 7v10H3V11Zm4 10v-9h10v9M8 15h8m-8 3h8" />,
  '/workspace/climate': <><path d="M9 14V5a3 3 0 0 1 6 0v9a5 5 0 1 1-6 0Zm3-6v9" /><circle cx="12" cy="18" r="1" /></>,
  '/workspace/access': <><rect x="2" y="4" width="20" height="16" rx="2" /><circle cx="8.5" cy="10" r="2" /><path d="M5 16c1-4 6-4 7 0m2-7h5m-5 4h4" /></>,
  '/workspace/admin': <><path d="m12 2 9 4v6c0 6-5 9-9 11-4-2-9-5-9-11V6l9-4Z" /><path d="m8 12 3 3 5-6" /></>,
  '/workspace/reports': <path d="M5 2h9l5 5v15H5zM14 2v6h5M8 12h7m-7 4h5" />,
  '/catalog': <><rect x="3" y="3" width="18" height="18" rx="2" /><path d="M7 8h10M7 12h10M7 16h6" /></>,
  account: <><circle cx="12" cy="7" r="4" /><path d="M3 22c0-9 18-9 18 0z" /></>,
};

function ShellIcon({ name }: { name: string }) {
  return <svg className="shell-icon" width="21" height="21" viewBox="0 0 24 24" fill="none"
    stroke="currentColor" strokeWidth="1.75" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
    {icons[name]}
  </svg>;
}

function AccountActions({ cabinet }: { cabinet?: boolean }) {
  const { t, lang, toggleLanguage, user, authLoading, setUser } = useApp();
  const [state, setState] = useState<'ready' | 'pending' | 'failed'>('ready');

  async function logout() {
    setState('pending');
    try {
      await api.logout();
      setUser(null);
      setState('ready');
    } catch {
      setState('failed');
    }
  }

  return (
    <div className="account-actions">
      <button className="language-switch" onClick={toggleLanguage} aria-label={t('Сменить язык', 'Change language')}>
        {lang === 'ru' ? 'EN' : 'RU'}
      </button>
      {authLoading ? <span role="status">{t('Проверка сессии…', 'Checking session…')}</span> : user ? <>
        <Link className="account-link" href="/workspace" aria-label={t('Личный кабинет', 'Workspace')}>
          <ShellIcon name="account" /><span>{cabinet ? user.email : t('Личный кабинет', 'Workspace')}</span>
        </Link>
        <button className="logout" disabled={state === 'pending'} onClick={logout}>{t('Выйти', 'Sign out')}</button>
      </> : <>
        <Link className="shell-button" href="/login">{t('Вход', 'Sign in')}</Link>
        <Link className="shell-button solid" href="/register">{t('Регистрация', 'Register')}</Link>
      </>}
      {state === 'failed' && <span role="alert">{t('Не удалось выйти. Повторите попытку.', 'Sign out failed. Try again.')}</span>}
    </div>
  );
}

function Wordmark() {
  return <Link className="site-wordmark" href="/">SVALBARD</Link>;
}

function PublicHeader({ path }: { path: string }) {
  const { t, user } = useApp();
  return (
    <header className={'public-header' + (path === '/catalog' ? ' catalog-header' : '')}>
      <Wordmark />
      <nav aria-label={t('Основная навигация', 'Main navigation')}>
        <Link href="/" aria-current={path === '/' ? 'page' : undefined}>{t('О хранилище', 'About the vault')}</Link>
        <Link href="/catalog" aria-current={path === '/catalog' ? 'page' : undefined}>{t('Каталог образцов', 'Sample catalog')}</Link>
        <Link href={user?.type === 'DEPOSITOR' ? '/workspace' : '/register'}>{t('Депозиторам', 'For depositors')}</Link>
      </nav>
      <AccountActions />
    </header>
  );
}

const roleLabels: Record<string, [string, string]> = {
  ADMIN: ['Администратор', 'Administrator'],
  CURATOR: ['Курирующий сотрудник', 'Curator'],
  ENGINEER: ['Инженер', 'Engineer'],
  SECURITY: ['Сотрудник охраны', 'Security officer'],
};

function WorkspaceShell({ children, path }: { children: ReactNode; path: string }) {
  const { t, user, lang } = useApp();
  const destinations = navigationFor(user).filter(item => item.href.startsWith('/workspace'));
  const role = user?.type === 'DEPOSITOR' ? t('Депозитор', 'Depositor')
    : user?.roles.map(code => roleLabels[code] ? t(...roleLabels[code]) : code).join(' · ');

  return (
    <div className="cab-shell">
      <aside className="cab-sidebar">
        <div className="cab-brand"><Wordmark /></div>
        <nav className="cab-nav" aria-label={t('Разделы кабинета', 'Workspace navigation')}>
          {destinations.map(link => <Link href={link.href} key={link.href} aria-current={path === link.href ? 'page' : undefined}>
            <ShellIcon name={link.href} />{link.href === '/workspace' ? t('Обзор', 'Overview') : link[lang]}
          </Link>)}
        </nav>
        <Link className="cab-public-link" href="/catalog"><ShellIcon name="/catalog" />{t('Каталог образцов', 'Sample catalog')}</Link>
      </aside>
      <div className="cab-main">
        <header className="cab-header"><span>{role || t('Личный кабинет', 'Workspace')}</span><AccountActions cabinet /></header>
        <main className="cab-content"><SessionNotice />{children}</main>
      </div>
    </div>
  );
}

export function SiteShell({ children }: { children: ReactNode }) {
  const path = usePathname();
  if (path.startsWith('/workspace')) return <WorkspaceShell path={path}>{children}</WorkspaceShell>;
  if (path === '/register' || path === '/login') return <main>{children}</main>;
  return <><PublicHeader path={path} /><main><SessionNotice />{children}</main></>;
}
