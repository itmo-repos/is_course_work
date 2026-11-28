'use client';

import { useApp } from '@/components/providers';
import type { DepositorApplication, DepositorStatus } from '@/lib/types';
import { useApiData } from '@/lib/use-api-data';
import { ContractUpload } from './contract-upload';

const labels: Record<DepositorStatus, [string, string]> = {
  NEW_REQUEST: ['На рассмотрении', 'Under review'],
  AWAITING_CONTRACT: ['Одобрена. Ожидается подписание договора', 'Approved. Awaiting contract signature'],
  REJECTED: ['Заявка отклонена', 'Application rejected'],
  VERIFICATION: ['Договор на проверке', 'Contract under review'],
  CONTRACT_REJECTED: ['Договор отклонён', 'Contract rejected'],
  ACTIVE: ['Депозитор активен', 'Depositor active'],
};

export function ApplicationStatus() {
  const { t } = useApp();
  const { data, setData, failed, reload } = useApiData<DepositorApplication>('/depositors/me');
  return (
    <section className="application-summary" id="application">
      <h2>{t('Моя заявка', 'My application')}</h2>
      {data ? <dl className="workspace-facts">
        <div><dt>{t('Организация', 'Organization')}</dt><dd>{data.legalName}</dd></div>
        <div><dt>{t('Статус', 'Status')}</dt><dd><span className="workspace-status" data-status={data.status}>{t(...labels[data.status])}</span></dd></div>
        {data.rejectionReason && <div>
          <dt>{t('Причина отказа', 'Reason for rejection')}</dt><dd>{data.rejectionReason}</dd>
        </div>}
      </dl> : failed ? <p role="alert">{t('Не удалось загрузить заявку.', 'Could not load your application.')}</p>
        : <p role="status">{t('Загрузка…', 'Loading…')}</p>}
      {data?.contract && <section className="workspace-contract" id="contract">
        <h2>{t('Договор хранения', 'Storage agreement')}</h2>
        <p>{t('Номер договора', 'Agreement number')} {data.contract.number}</p>
        <p><a href="/api/depositors/me/contract">{t('Скачать шаблон договора (PDF)', 'Download agreement template (PDF)')}</a></p>
        {(data.status === 'AWAITING_CONTRACT' || data.status === 'CONTRACT_REJECTED') &&
          <ContractUpload onUploaded={setData} resubmitting={data.status === 'CONTRACT_REJECTED'} />}
      </section>}
      {data?.status === 'REJECTED' && <p>{t(
        'Для повторной подачи выйдите из кабинета и откройте регистрацию. Укажите прежние email и пароль.',
        'To resubmit, sign out and open registration. Enter your original email and password.',
      )}</p>}
      {(data || failed) && <button className="secondary" onClick={reload}>{t('Обновить статус', 'Refresh status')}</button>}
    </section>
  );
}
