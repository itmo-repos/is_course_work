'use client';

import Link from 'next/link';
import { PageHeader } from '@/components/page-header';
import { useApp } from '@/components/providers';

export default function Workspace() {
  const { t, user, authLoading } = useApp();
  if (authLoading) return (
    <>
      <PageHeader title={t('Личный кабинет', 'Workspace')} />
      <p role="status">{t('Загрузка…', 'Loading…')}</p>
    </>
  );
  if (!user) {
    return (
      <>
        <PageHeader title={t('Нужен вход', 'Sign-in required')} />
        <Link href="/login">{t('Войти', 'Sign in')}</Link>
      </>
    );
  }

  return (
    <>
      <PageHeader title={t('Личный кабинет', 'Workspace')} />
      <dl>
        <dt>Email</dt><dd>{user.email}</dd>
        <dt>{t('Тип аккаунта', 'Account type')}</dt><dd>{user.type}</dd>
        <dt>{t('Роли', 'Roles')}</dt><dd>{user.roles.join(', ') || '—'}</dd>
      </dl>
    </>
  );
}
