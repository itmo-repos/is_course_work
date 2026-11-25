'use client';

import Link from 'next/link';
import { useState } from 'react';
import { PageHeader } from '@/components/page-header';
import { useApp } from '@/components/providers';
import type { Batch, Country, DepositorApplication, Species } from '@/lib/types';
import { useApiData } from '@/lib/use-api-data';
import { BatchForm } from './batch-form';
import { BatchContents } from './batch-contents';

const statusLabels: Record<Batch['status'], [string, string]> = {
  FORMED: ['Сформирована', 'Created'],
  CONFIRMED: ['Подтверждена', 'Confirmed'],
  REJECTED: ['Отклонена', 'Rejected'],
  IN_TRANSIT: ['В пути', 'In transit'],
  ARRIVED: ['Прибыла', 'Arrived'],
  INSPECTION: ['На досмотре', 'Under inspection'],
  PLACED: ['Размещена', 'Stored'],
  PARTIALLY_PLACED: ['Размещена частично', 'Partially stored'],
  WRITTEN_OFF: ['Списана', 'Written off'],
};

function BatchEditor({ onSaved, initialBatch, onCancel }: {
  onSaved: (batch: Batch) => void;
  initialBatch?: Batch;
  onCancel?: () => void;
}) {
  const { t } = useApp();
  const countries = useApiData<Country[]>('/samples/countries');
  const species = useApiData<Species[]>('/samples/species');
  const [formVersion, setFormVersion] = useState(0);

  if (countries.failed || species.failed) return (
    <div role="alert">
      <p>{t('Не удалось загрузить справочники.', 'Could not load the directories.')}</p>
      <button onClick={() => { countries.reload(); species.reload(); }}>{t('Повторить', 'Retry')}</button>
    </div>
  );
  if (!countries.data || !species.data) return <p role="status">{t('Загрузка справочников…', 'Loading directories…')}</p>;

  return <BatchForm key={formVersion} countries={countries.data} species={species.data}
    onSpeciesCreated={item => species.setData(previous => [...(previous ?? []), item])}
    initialBatch={initialBatch} onCancel={onCancel}
    onSaved={batch => { onSaved(batch); setFormVersion(version => version + 1); }} />;
}

function DepositorBatches() {
  const { t } = useApp();
  const profile = useApiData<DepositorApplication>('/depositors/me');
  const batches = useApiData<Batch[]>('/depositors/me/batches');
  const [notice, setNotice] = useState<{ number: string; resubmitted: boolean } | null>(null);
  const [editingId, setEditingId] = useState<number | null>(null);
  const editingBatch = batches.data?.find(batch => batch.id === editingId && batch.status === 'REJECTED');

  function onSaved(batch: Batch, resubmitted = false) {
    setNotice({ number: batch.number, resubmitted });
    if (resubmitted) setEditingId(null);
    batches.reload();
  }

  return (
    <>
      {notice && <p role="status">{notice.resubmitted
        ? t('Партия отправлена повторно', 'Batch resubmitted')
        : t('Партия создана', 'Batch created')} — {notice.number}</p>}
      {profile.failed ? <div role="alert">
        <p>{t('Не удалось проверить статус депозитора.', 'Could not check the depositor status.')}</p>
        <button onClick={profile.reload}>{t('Повторить', 'Retry')}</button>
      </div> : !profile.data ? <p role="status">{t('Проверяем статус депозитора…', 'Checking depositor status…')}</p>
        : profile.data.status === 'ACTIVE' ? (editingBatch
          ? <BatchEditor key={editingBatch.id} initialBatch={editingBatch}
            onCancel={() => setEditingId(null)} onSaved={batch => onSaved(batch, true)} />
          : <BatchEditor key="new" onSaved={onSaved} />)
        : <p>{t('Создание партии доступно после подтверждения договора.', 'You can create batches after your agreement is verified.')}</p>}

      <section>
        <h2>{t('Список партий', 'Batch list')}</h2>
        {!editingBatch && <button onClick={batches.reload}>{t('Обновить список', 'Refresh list')}</button>}
        {batches.failed ? <div role="alert">
          <p>{t('Не удалось загрузить партии.', 'Could not load batches.')}</p>
          <button onClick={batches.reload}>{t('Повторить', 'Retry')}</button>
        </div> : !batches.data ? <p role="status">{t('Загрузка партий…', 'Loading batches…')}</p>
          : batches.data.length === 0 ? <p>{t('Партий пока нет.', 'No batches yet.')}</p>
          : <table>
            <thead><tr>
              <th>{t('Номер партии', 'Batch number')}</th><th>{t('Статус', 'Status')}</th>
              <th>{t('Желаемая дата отправки', 'Desired shipment date')}</th><th>{t('Коробок', 'Boxes')}</th>
              <th>{t('Состав и действия', 'Contents and actions')}</th>
            </tr></thead>
            <tbody>{batches.data.map(batch => <tr key={batch.id}>
              <td>{batch.number}</td><td>{t(...statusLabels[batch.status])}</td>
              <td>{batch.desiredShipmentDate}</td><td>{batch.boxCount}</td>
              <td>
                {batch.rejectionReason && <p>{t('Причина отклонения', 'Reason for rejection')} — {batch.rejectionReason}</p>}
                {batch.status === 'REJECTED' && profile.data?.status === 'ACTIVE' && !editingBatch &&
                  <button onClick={() => setEditingId(batch.id)}>{t('Исправить партию', 'Edit batch')}</button>}
                <details>
                  <summary>{t('Открыть состав', 'View contents')}</summary>
                  <BatchContents batch={batch} showBarcodes />
                </details>
              </td>
            </tr>)}</tbody>
          </table>}
      </section>
    </>
  );
}

export default function Batches() {
  const { t, user, authLoading } = useApp();
  return (
    <>
      <PageHeader title={t('Мои партии', 'My batches')} />
      {authLoading ? <p role="status">{t('Загрузка…', 'Loading…')}</p>
        : !user ? <Link href="/login">{t('Войти в систему', 'Sign in')}</Link>
        : user.type === 'DEPOSITOR' ? <DepositorBatches key={user.id} />
        : <p>{t('Раздел доступен депозиторам.', 'This section is available to depositors.')}</p>}
    </>
  );
}
