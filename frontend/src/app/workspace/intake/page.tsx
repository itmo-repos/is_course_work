'use client';

import Link from 'next/link';
import { useState, type FormEvent } from 'react';
import { PageHeader } from '@/components/page-header';
import { useApp } from '@/components/providers';
import { api, ApiError } from '@/lib/api.mjs';
import type { Batch } from '@/lib/types';
import { useApiData } from '@/lib/use-api-data';
import { Metrics } from '../metrics';
import { BatchContents } from '../batches/batch-contents';

function ReviewBatch({ batch, onDecision, reload }: {
  batch: Batch;
  onDecision: (batch: Batch) => void;
  reload: () => void;
}) {
  const { t } = useApp();
  const [reason, setReason] = useState('');
  const [state, setState] = useState<'idle' | 'pending' | 'failed' | 'stale'>('idle');
  const disabled = state === 'pending' || state === 'stale';

  async function decide(decision: 'confirm' | 'reject') {
    if (disabled || (decision === 'reject' && !reason.trim())) return;
    setState('pending');
    try {
      onDecision(await api.request(`/curator/batches/${batch.id}/${decision}`, {
        method: 'POST',
        body: decision === 'reject' ? JSON.stringify({ reason: reason.trim() }) : undefined,
      }));
    } catch (error) {
      setState(error instanceof ApiError && error.status === 409 ? 'stale' : 'failed');
    }
  }

  function reject(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    void decide('reject');
  }

  return (
    <details>
      <summary>{t('Открыть состав', 'View contents')}</summary>
      <BatchContents batch={batch} />
      <button disabled={disabled} onClick={() => decide('confirm')}>{t('Подтвердить партию', 'Confirm batch')}</button>
      <form className="form" onSubmit={reject}>
        <label htmlFor={'batch-reason-' + batch.id}>{t('Причина отклонения', 'Reason for rejection')}</label>
        <input id={'batch-reason-' + batch.id} value={reason} onChange={event => setReason(event.target.value)}
          maxLength={2000} required disabled={disabled} />
        <button className="secondary" disabled={disabled || !reason.trim()}>{t('Отклонить партию', 'Reject batch')}</button>
      </form>
      {state === 'pending' && <p role="status">{t('Сохраняем решение…', 'Saving decision…')}</p>}
      {state === 'failed' && <p role="alert">{t('Не удалось сохранить решение. Повторите попытку.', 'Could not save the decision. Try again.')}</p>}
      {state === 'stale' && <div role="alert">
        <p>{t('Партия больше недоступна для этого действия.', 'This action is no longer available for the batch.')}</p>
        <button onClick={reload}>{t('Обновить очередь', 'Refresh queue')}</button>
      </div>}
    </details>
  );
}

function ReviewQueue() {
  const { t } = useApp();
  const { data, setData, failed, reload } = useApiData<Batch[]>('/curator/batches?status=FORMED');
  const [reviewed, setReviewed] = useState<Batch | null>(null);

  function onDecision(batch: Batch) {
    setReviewed(batch);
    setData(previous => previous?.filter(item => item.id !== batch.id) ?? null);
  }

  return (
    <section>
      {data && <Metrics items={[
        { label: t('Партии к рассмотрению', 'Batches to review'), value: data.length },
        { label: t('Коробок в очереди', 'Boxes in queue'), value: data.reduce((sum, batch) => sum + batch.boxCount, 0) },
        { label: t('Паспортов образцов', 'Sample passports'), value: data.reduce((sum, batch) => sum + batch.boxes.reduce((n, box) => n + box.samples.length, 0), 0) },
      ]} />}
      <div className="workspace-section-heading">
        <h2>{t('Партии на согласовании', 'Batches awaiting review')}</h2>
        {data && <button className="secondary" onClick={reload}>{t('Обновить список', 'Refresh list')}</button>}
      </div>
      {reviewed && <p role="status">{reviewed.number} — {reviewed.status === 'CONFIRMED'
        ? t('партия подтверждена', 'batch confirmed') : t('партия отклонена', 'batch rejected')}</p>}
      {failed ? <div role="alert">
        <p>{t('Не удалось загрузить партии.', 'Could not load batches.')}</p>
        <button onClick={reload}>{t('Повторить', 'Retry')}</button>
      </div> : !data ? <p role="status">{t('Загрузка партий…', 'Loading batches…')}</p>
        : data.length === 0 ? <p>{t('Партий на согласовании нет.', 'No batches are awaiting review.')}</p>
        : <table className="review-table">
          <thead><tr>
            <th>{t('Номер партии', 'Batch number')}</th>
            <th>{t('Желаемая дата отправки', 'Desired shipment date')}</th>
            <th>{t('Коробок', 'Boxes')}</th>
            <th>{t('Состав и решение', 'Contents and decision')}</th>
          </tr></thead>
          <tbody>{data.map(batch => <tr key={batch.id}>
            <td>{batch.number}</td><td>{batch.desiredShipmentDate}</td><td>{batch.boxCount}</td>
            <td><ReviewBatch batch={batch} onDecision={onDecision} reload={reload} /></td>
          </tr>)}</tbody>
        </table>}
    </section>
  );
}

export default function Intake() {
  const { t, user, authLoading } = useApp();
  return (
    <>
      <PageHeader title={t('Приём и склад', 'Intake and storage')} />
      {authLoading ? <p role="status">{t('Загрузка…', 'Loading…')}</p>
        : !user ? <Link href="/login">{t('Войти в систему', 'Sign in')}</Link>
        : user.roles.includes('CURATOR') ? <ReviewQueue key={user.id} />
        : <p>{t('Раздел доступен кураторам.', 'This section is available to curators.')}</p>}
    </>
  );
}
