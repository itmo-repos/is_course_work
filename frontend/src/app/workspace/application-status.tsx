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
    <section>
      <h2>{t('Моя заявка', 'My application')}</h2>
      {data ? <dl>
        <dt>{t('Организация', 'Organization')}</dt><dd>{data.legalName}</dd>
        <dt>{t('Статус', 'Status')}</dt><dd>{t(...labels[data.status])}</dd>
        {data.rejectionReason && <>
          <dt>{t('Причина отказа', 'Reason for rejection')}</dt><dd>{data.rejectionReason}</dd>
        </>}
      </dl> : failed ? <p role="alert">{t('Не удалось загрузить заявку.', 'Could not load your application.')}</p>
        : <p role="status">{t('Загрузка…', 'Loading…')}</p>}
      {data?.contract && <section>
        <h2>{t('Договор хранения', 'Storage agreement')}</h2>
        <p>{t('Номер договора', 'Agreement number')} {data.contract.number}</p>
        <p><a href="/api/depositors/me/contract">{t('Скачать шаблон договора (PDF)', 'Download agreement template (PDF)')}</a></p>
        {data.status === 'AWAITING_CONTRACT' && <ContractUpload onUploaded={setData} />}
      </section>}
      {(data || failed) && <button onClick={reload}>{t('Обновить статус', 'Refresh status')}</button>}
    </section>
  );
}
