'use client';

import Link from 'next/link';
import { useApp } from '@/components/providers';

export default function Home() {
  const { t, user } = useApp();
  const features = [
    { title: t('Долгосрочное хранение', 'Long-term storage'),
      text: t('Сохранение образцов на десятилетия и столетия', 'Preserving seed samples for decades and centuries'),
      icon: <path d="M3 21C4 11 11 4 22 3c0 10-5 18-14 17M3 21l11-11" /> },
    { title: t('Глобальная безопасность', 'Global security'),
      text: t('Резервные копии национальных коллекций', 'Backup copies of national seed collections'),
      icon: <><path d="m12 2 9 4v6c0 5-5 9-9 11-4-2-9-6-9-11V6z" /><path d="m7 12 3 3 7-7" /></> },
    { title: t('Международное сотрудничество', 'International cooperation'),
      text: t('Доступ для стран и научных организаций со всего мира', 'Access for countries and research institutions worldwide'),
      icon: <>{[[2, 2], [14, 2], [2, 14], [14, 14]].map(([x, y]) => <rect key={x + '-' + y} x={x} y={y} width="8" height="8" rx="2" />)}</> },
  ];
  return (
    <div className="public-home">
      <section className="home-hero">
        <div className="hero-image" role="img" aria-label={t('Вход в семенохранилище среди снега', 'Entrance to the Seed Vault in the snow')} />
        <div className="hero-content">
          <h1>{t('Всемирное', 'Svalbard')}<br />{t('семенохранилище', 'Global Seed Vault')}<br />{t('на Шпицбергене', '')}</h1>
          <p>{t('Международное хранилище образцов семян для сохранения биоразнообразия и продовольственной безопасности.', 'An international seed repository preserving biodiversity and safeguarding global food security.')}</p>
          <div className="hero-actions">
            <Link href="/catalog" className="public-button primary">{t('Перейти в каталог', 'Browse catalog')} <span aria-hidden="true">→</span></Link>
            <Link href={user ? '/workspace' : '/register'} className="public-button">{user ? t('Личный кабинет', 'Workspace') : t('Стать депозитором', 'Become a depositor')}</Link>
          </div>
        </div>
      </section>
      <section className="home-features" aria-label={t('О хранилище', 'About the vault')}>
        {features.map(feature => <div className="home-feature" key={feature.title}>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.4" aria-hidden="true">{feature.icon}</svg>
          <div><h2>{feature.title}</h2><p>{feature.text}</p></div>
        </div>)}
      </section>
    </div>
  );
}
