'use client';

import Link from 'next/link';
import { PageHeader } from '@/components/page-header';
import { useApp } from '@/components/providers';

export default function PendingSection() {
  const { t, user, authLoading } = useApp();
  return (
    <>
      <PageHeader title={t('Раздел в разработке', 'Section under development')} />
      <p>{t('Операции этого раздела пока недоступны.', 'Operations in this section are not available yet.')}</p>
      {authLoading ? <p role="status">{t('Проверка сессии…', 'Checking session…')}</p> : (
        <Link href={user ? '/workspace' : '/login'}>
          {user ? t('В личный кабинет', 'Back to workspace') : t('Войти', 'Sign in')}
        </Link>
      )}
    </>
  );
}
