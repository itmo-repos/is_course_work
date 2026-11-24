'use client';

import { PageHeader } from '@/components/page-header';
import { useApp } from '@/components/providers';

export default function Register() {
  const { t } = useApp();
  return (
    <>
      <PageHeader title={t('Регистрация депозитора', 'Depositor registration')} />
      <p>{t('Приём заявок через сайт пока недоступен.', 'Online applications are not available yet.')}</p>
    </>
  );
}
