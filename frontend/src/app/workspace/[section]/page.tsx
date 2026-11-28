'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { PageHeader } from '@/components/page-header';
import { useApp } from '@/components/providers';
import { navigationFor } from '@/lib/navigation';

export default function PendingSection() {
  const { t, lang, user, authLoading } = useApp();
  const path = usePathname();
  const section = navigationFor(user).find(link => link.href === path);
  return <>
    <PageHeader title={section?.[lang] || t('Раздел в разработке', 'Section under development')} />
    <section className="workspace-panel">
      <p>{t('Операции этого раздела пока недоступны.', 'Operations in this section are not available yet.')}</p>
      {authLoading ? <p role="status">{t('Проверка сессии…', 'Checking session…')}</p> :
        <Link className="workspace-action secondary" href={user ? '/workspace' : '/login'}>
          {user ? t('В личный кабинет', 'Back to workspace') : t('Войти', 'Sign in')}
        </Link>}
    </section>
  </>;
}
