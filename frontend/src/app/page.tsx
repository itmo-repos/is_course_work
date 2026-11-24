'use client';

import Link from 'next/link';
import { PageHeader } from '@/components/page-header';
import { useApp } from '@/components/providers';

export default function Home() {
  const { t } = useApp();
  return (
    <>
      <PageHeader title={t('Семенохранилище на Шпицбергене', 'Svalbard Seed Vault')} />
      <p>{t('В публичном каталоге можно найти образцы по виду растения и стране происхождения.', 'Search the public catalog by species and country of origin.')}</p>
      <div className="actions">
        <Link className="button" href="/catalog">{t('Открыть каталог', 'Browse catalog')}</Link>
        <Link href="/login">{t('Войти в систему', 'Sig n in')}</Link>
      </div>
      <section>
        <h2>{t('Хранение коллекций', 'Collection storage')}</h2>
        <p>{t('Коробки остаются опечатанными. Право распоряжаться содержимым сохраняется за депозитором.', 'Boxes remain sealed. The depositor retains control over their contents.')}</p>
      </section>
    </>
  );
}
