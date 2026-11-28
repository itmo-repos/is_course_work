import { useState } from 'react';
import { useApp } from '@/components/providers';
import { api, ApiError } from '@/lib/api.mjs';
import type { DepositorApplication } from '@/lib/types';
import { useApiData } from '@/lib/use-api-data';

type Decision = 'contract/verify' | 'contract/reject' | 'contract/return-for-signing' | 'reject-final';
type QueueStatus = 'VERIFICATION' | 'CONTRACT_REJECTED';

function ContractRow({ application, onDecision, reload }: {
  application: DepositorApplication;
  onDecision: (application: DepositorApplication) => void;
  reload: () => void;
}) {
  const { t } = useApp();
  const [reason, setReason] = useState('');
  const [state, setState] = useState<'idle' | 'pending' | 'stale' | 'failed'>('idle');
  const reviewing = application.status === 'VERIFICATION';
  const disabled = state === 'pending' || state === 'stale';
  const path = '/admin/depositors/' + application.id;

  async function decide(decision: Decision) {
    const needsReason = decision === 'contract/reject' || decision === 'reject-final';
    if (disabled || (needsReason && !reason.trim())) return;
    setState('pending');
    try {
      onDecision(await api.request(path + '/' + decision, {
        method: 'POST',
        body: needsReason ? JSON.stringify({ reason: reason.trim() }) : undefined,
      }));
    } catch (error) {
      setState(error instanceof ApiError && error.status === 409 ? 'stale' : 'failed');
    }
  }

  return (
    <tr>
      <td>{application.legalName}</td>
      <td>{application.contract?.number}</td>
      <td><a href={'/api' + path + '/contract/scan'}>{t('Скачать скан', 'Download scan')}</a></td>
      {!reviewing && <td>{application.rejectionReason}</td>}
      <td>
        <button disabled={disabled} onClick={() => decide(reviewing ? 'contract/verify' : 'contract/return-for-signing')}>
          {reviewing ? t('Подтвердить договор', 'Verify agreement') : t('Вернуть на подписание', 'Return for signature')}
        </button>
        <form className="form" onSubmit={event => {
          event.preventDefault();
          void decide(reviewing ? 'contract/reject' : 'reject-final');
        }}>
          <label htmlFor={'contract-reason-' + application.id}>
            {reviewing ? t('Причина отклонения скана', 'Reason for rejecting the scan') : t('Причина окончательного отказа', 'Reason for final rejection')}
          </label>
          <input id={'contract-reason-' + application.id} value={reason} maxLength={2000} required
            disabled={disabled} onChange={event => setReason(event.target.value)} />
          <button className="secondary" disabled={disabled || !reason.trim()}>
            {reviewing ? t('Отклонить скан', 'Reject scan') : t('Отклонить заявку окончательно', 'Reject application permanently')}
          </button>
        </form>
        {state === 'failed' && <p role="alert">{t('Не удалось сохранить решение. Повторите попытку.', 'Could not save the decision. Try again.')}</p>}
        {state === 'stale' && <div role="alert">
          <p>{t('Статус договора уже изменился.', 'The agreement status has already changed.')}</p>
          <button onClick={reload}>{t('Обновить список', 'Refresh list')}</button>
        </div>}
      </td>
    </tr>
  );
}

function ContractList({ status }: { status: QueueStatus }) {
  const { t } = useApp();
  const { data, setData, failed, reload } = useApiData<DepositorApplication[]>('/admin/depositors?status=' + status);
  const [decision, setDecision] = useState<DepositorApplication['status'] | null>(null);
  const reviewing = status === 'VERIFICATION';

  function onDecision(application: DepositorApplication) {
    setData(previous => previous?.filter(item => item.id !== application.id) ?? null);
    setDecision(application.status);
  }

  return (
    <>
      {decision && <p role="status">{decision === 'ACTIVE' ? t('Договор подтверждён. Депозитор активирован.', 'Agreement verified. Depositor activated.')
        : decision === 'AWAITING_CONTRACT' ? t('Договор возвращён на подписание.', 'Agreement returned for signature.')
        : decision === 'CONTRACT_REJECTED' ? t('Скан отклонён.', 'Scan rejected.')
        : t('Заявка окончательно отклонена.', 'Application permanently rejected.')}</p>}
      {failed ? <div role="alert">
        <p>{t('Не удалось загрузить договоры.', 'Could not load agreements.')}</p>
        <button onClick={reload}>{t('Повторить', 'Retry')}</button>
      </div> : !data ? <p role="status">{t('Загрузка…', 'Loading…')}</p>
        : data.length === 0 ? <p>{t('В списке нет договоров.', 'There are no agreements in this list.')}</p>
        : <table>
          <thead><tr>
            <th>{t('Организация', 'Organization')}</th>
            <th>{t('Номер договора', 'Agreement number')}</th>
            <th>{t('Скан', 'Scan')}</th>
            {!reviewing && <th>{t('Причина отклонения скана', 'Reason for rejecting the scan')}</th>}
            <th>{t('Решение', 'Decision')}</th>
          </tr></thead>
          <tbody>{data.map(application => <ContractRow key={application.id} application={application}
            onDecision={onDecision} reload={reload} />)}</tbody>
        </table>}
    </>
  );
}

export function ContractQueue() {
  const { t } = useApp();
  const [status, setStatus] = useState<QueueStatus>('VERIFICATION');
  return (
    <section className="workspace-panel" id="agreements">
      <h2>{t('Договоры хранения', 'Storage agreements')}</h2>
      <p>
        <label htmlFor="contract-queue-status">{t('Статус договора', 'Agreement status')} </label>
        <select id="contract-queue-status" value={status} onChange={event => setStatus(event.target.value as QueueStatus)}>
          <option value="VERIFICATION">{t('На проверке', 'Under review')}</option>
          <option value="CONTRACT_REJECTED">{t('Отклонённые сканы', 'Rejected scans')}</option>
        </select>
      </p>
      <ContractList key={status} status={status} />
    </section>
  );
}
