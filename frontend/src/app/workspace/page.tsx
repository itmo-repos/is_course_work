'use client';

import Link from 'next/link';
import { ApplicationStatus } from './application-status';
import { BatchStatus } from './batches/batch-status';
import { Metrics } from './metrics';
import { PageHeader } from '@/components/page-header';
import { useApp } from '@/components/providers';
import type { Batch, User } from '@/lib/types';
import { useApiData } from '@/lib/use-api-data';

function Profile({ user }: { user: User }) {
  const { t } = useApp();
  return <section className="workspace-profile">
    <h2>{t('Профиль', 'Profile')}</h2>
    <dl className="workspace-facts">
      <div><dt>Email</dt><dd>{user.email}</dd></div>
      <div><dt>{t('Тип аккаунта', 'Account type')}</dt><dd>{user.type === 'DEPOSITOR' ? t('Депозитор', 'Depositor') : t('Сотрудник', 'Employee')}</dd></div>
      {user.roles.length > 0 && <div><dt>{t('Роли', 'Roles')}</dt><dd>{user.roles.join(', ')}</dd></div>}
    </dl>
  </section>;
}

function DepositorOverview({ user }: { user: User }) {
  const { t } = useApp();
  const batches = useApiData<Batch[]>('/depositors/me/batches');
  return (
    <>
      {batches.data && <Metrics items={[
        { label: t('Всего партий', 'Total batches'), value: batches.data.length },
        { label: t('Коробок в партиях', 'Boxes in batches'), value: batches.data.reduce((sum, batch) => sum + batch.boxCount, 0) },
        { label: t('На согласовании', 'Awaiting review'), value: batches.data.filter(batch => batch.status === 'FORMED').length },
      ]} />}
      <div className="overview-columns">
        <ApplicationStatus />
        <div className="overview-aside">
          <Profile user={user} />
          <h2>{t('Быстрые действия', 'Quick actions')}</h2>
          <div className="workspace-actions">
            <Link className="workspace-action" href="/workspace/batches">{t('Работа с партиями', 'Manage batches')} <span aria-hidden="true">→</span></Link>
            <Link className="workspace-action secondary" href="/catalog">{t('Найти образцы', 'Find samples')}</Link>
          </div>
        </div>
      </div>

      <section>
        <div className="workspace-section-heading">
          <h2>{t('Мои партии', 'My batches')}</h2>
          <Link href="/workspace/batches#batch-list">{t('Все партии', 'All batches')} <span aria-hidden="true">→</span></Link>
        </div>
        {batches.failed ? <div role="alert"><p>{t('Не удалось загрузить партии.', 'Could not load batches.')}</p>
          <button className="secondary" onClick={batches.reload}>{t('Повторить', 'Retry')}</button></div>
          : !batches.data ? <p role="status">{t('Загрузка партий…', 'Loading batches…')}</p>
          : !batches.data.length ? <p className="workspace-empty">{t('Партий пока нет.', 'No batches yet.')}</p>
          : <table>
            <thead><tr>
              <th>{t('№ партии', 'Batch no.')}</th><th>{t('Дата отправки', 'Shipment date')}</th>
              <th>{t('Коробок', 'Boxes')}</th><th>{t('Статус', 'Status')}</th>
            </tr></thead>
            <tbody>{batches.data.slice(0, 4).map(batch => <tr key={batch.id}>
              <td><Link className="batch-number" href={'/workspace/batches/' + batch.id}>{batch.number}</Link></td>
              <td>{batch.desiredShipmentDate}</td><td>{batch.boxCount}</td><td><BatchStatus status={batch.status} /></td>
            </tr>)}</tbody>
          </table>}
      </section>
    </>
  );
}

export default function Workspace() {
  const { t, user, authLoading } = useApp();
  if (authLoading) return <><PageHeader title={t('Личный кабинет', 'Workspace')} /><p role="status">{t('Загрузка…', 'Loading…')}</p></>;
  if (!user) return <><PageHeader title={t('Нужен вход', 'Sign-in required')} /><Link className="workspace-action" href="/login">{t('Войти', 'Sign in')}</Link></>;
  return <>
    <PageHeader title={t('Обзор', 'Overview')} />
    {user.type === 'DEPOSITOR' ? <DepositorOverview key={user.id} user={user} /> : <div className="overview-columns staff-overview">
      <Profile user={user} />
      <section className="overview-aside">
        <h2>{t('Быстрые действия', 'Quick actions')}</h2>
        <div className="workspace-actions">
          {user.roles.includes('CURATOR') && <Link className="workspace-action" href="/workspace/intake">{t('Согласовать партии', 'Review batches')}</Link>}
          {user.roles.includes('ADMIN') && <Link className="workspace-action" href="/workspace/admin">{t('Рассмотреть заявки', 'Review applications')}</Link>}
          <Link className="workspace-action secondary" href="/catalog">{t('Найти образцы', 'Find samples')}</Link>
        </div>
      </section>
    </div>}
  </>;
}
