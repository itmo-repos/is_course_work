'use client';

import Link from 'next/link';
import { useState } from 'react';
import { PageHeader } from '@/components/page-header';
import { useApp } from '@/components/providers';
import { api, ApiError } from '@/lib/api.mjs';
import type { DepositorApplication } from '@/lib/types';
import { useApiData } from '@/lib/use-api-data';
import { ContractQueue } from './contract-queue';

type Decision = 'approve' | 'reject';

function ApplicationRow({ application, onDecision, reload }: {
  application: DepositorApplication;
  onDecision: (id: number, decision: Decision, name: string) => void;
  reload: () => void;
}) {
  const { t } = useApp();
  const [reason, setReason] = useState('');
  const [state, setState] = useState<'idle' | 'pending' | 'stale' | 'failed'>('idle');

  async function decide(decision: Decision) {
    if (state === 'pending' || state === 'stale') return;
    if (decision === 'reject' && !reason.trim()) return;
    setState('pending');
    try {
      await api.request(`/admin/depositors/${application.id}/${decision}`, {
        method: 'POST',
        body: decision === 'reject' ? JSON.stringify({ reason: reason.trim() }) : undefined,
      });
      onDecision(application.id, decision, application.legalName);
    } catch (error) {
      setState(error instanceof ApiError && error.status === 409 ? 'stale' : 'failed');
    }
  }

  const disabled = state === 'pending' || state === 'stale';
  return (
    <tr>
      <td>{application.legalName}</td>
      <td>{application.countryName}</td>
      <td>{application.registrationNumber}</td>
      <td>{application.legalAddress}</td>
      <td>{application.contactPerson}<br />{application.contactEmail}
        {application.contactPhone && <><br />{application.contactPhone}</>}</td>
      <td>
        <button disabled={disabled} onClick={() => decide('approve')}>{t('Одобрить', 'Approve')}</button>
        <div className="actions">
          <label htmlFor={'reason-' + application.id}>{t('Причина отказа', 'Reason for rejection')}</label>
          <input id={'reason-' + application.id} value={reason} maxLength={2000} disabled={disabled}
            onChange={event => setReason(event.target.value)} />
          <button disabled={disabled || !reason.trim()} onClick={() => decide('reject')}>{t('Отклонить', 'Reject')}</button>
        </div>
        {state === 'failed' && <p role="alert">{t('Не удалось сохранить решение. Повторите попытку.', 'Could not save the decision. Please try again.')}</p>}
        {state === 'stale' && <div role="alert">
          <p>{t('Статус заявки уже изменился.', 'The application status has already changed.')}</p>
          <button onClick={reload}>{t('Обновить список', 'Refresh list')}</button>
        </div>}
      </td>
    </tr>
  );
}

function ApplicationQueue() {
  const { t } = useApp();
  const { data, setData, failed, reload } = useApiData<DepositorApplication[]>('/admin/depositors?status=NEW_REQUEST');
  const [notice, setNotice] = useState<{ decision: Decision; name: string } | null>(null);

  function onDecision(id: number, decision: Decision, name: string) {
    setData(applications => applications?.filter(application => application.id !== id) ?? null);
    setNotice({ decision, name });
  }

  return (
    <>
      {notice && <p role="status">{notice.name} — {notice.decision === 'approve'
        ? t('заявка одобрена.', 'application approved.') : t('заявка отклонена.', 'application rejected.')}</p>}
      {failed ? <div role="alert">
        <p>{t('Не удалось загрузить заявки.', 'Could not load applications.')}</p>
        <button onClick={reload}>{t('Повторить', 'Retry')}</button>
      </div> : !data ? <p role="status">{t('Загрузка…', 'Loading…')}</p>
        : data.length === 0 ? <p>{t('Новых заявок нет.', 'No pending applications.')}</p>
        : <table>
          <caption>{t('Заявки на рассмотрении', 'Pending applications')}</caption>
          <thead><tr>
            <th>{t('Организация', 'Organization')}</th><th>{t('Страна', 'Country')}</th>
            <th>{t('Регистрационный номер', 'Registration number')}</th><th>{t('Юридический адрес', 'Registered address')}</th>
            <th>{t('Контакты', 'Contact details')}</th><th>{t('Решение', 'Decision')}</th>
          </tr></thead>
          <tbody>{data.map(application => <ApplicationRow key={application.id} application={application} onDecision={onDecision} reload={reload} />)}</tbody>
        </table>}
    </>
  );
}

export default function Admin() {
  const { t, user, authLoading } = useApp();
  return (
    <>
      <PageHeader title={t('Заявки депозиторов', 'Depositor applications')} />
      {authLoading ? <p role="status">{t('Загрузка…', 'Loading…')}</p>
        : !user ? <Link href="/login">{t('Войти в систему', 'Sign in')}</Link>
        : user.roles.includes('ADMIN') ? <div key={user.id}><ApplicationQueue /><ContractQueue /></div>
        : <p>{t('Раздел доступен только администратору.', 'Only administrators can access this section.')}</p>}
    </>
  );
}
