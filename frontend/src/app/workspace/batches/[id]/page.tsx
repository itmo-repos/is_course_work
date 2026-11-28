'use client';

import Link from 'next/link';
import { useParams } from 'next/navigation';
import { PageHeader } from '@/components/page-header';
import { useApp } from '@/components/providers';
import type { Batch } from '@/lib/types';
import { useApiData } from '@/lib/use-api-data';
import { BatchContents } from '../batch-contents';
import { BatchStatus } from '../batch-status';

function BatchDetails({ id }: { id: string }) {
  const { t } = useApp();
  const { data, failed, reload } = useApiData<Batch>('/depositors/me/batches/' + encodeURIComponent(id));
  return <>
    <p className="workspace-crumb"><Link href="/workspace/batches#batch-list">{t('Мои партии', 'My batches')}</Link>
      {data && <> <span aria-hidden="true">/</span> {data.number}</>}</p>
    <PageHeader title={data ? t('Партия ', 'Batch ') + data.number : t('Карточка партии', 'Batch details')} />
    {failed ? <div role="alert"><p>{t('Не удалось загрузить партию.', 'Could not load this batch.')}</p>
      <button onClick={reload}>{t('Повторить', 'Retry')}</button></div>
      : !data ? <p role="status">{t('Загрузка…', 'Loading…')}</p> : <>
        <div className="workspace-tabs">
          <a href="#batch-info">{t('Общая информация', 'Overview')}</a>
          <a href="#boxes">{t('Коробки', 'Boxes')} ({data.boxCount})</a>
        </div>
        <section className="workspace-panel" id="batch-info">
          <dl className="workspace-facts batch-facts">
            <div><dt>{t('Дата отправки', 'Shipment date')}</dt><dd>{data.desiredShipmentDate}</dd></div>
            <div><dt>{t('Количество коробок', 'Box count')}</dt><dd>{data.boxCount}</dd></div>
            <div><dt>{t('Образцов', 'Samples')}</dt><dd>{data.boxes.reduce((sum, box) => sum + box.samples.length, 0)}</dd></div>
            <div><dt>{t('Статус', 'Status')}</dt><dd><BatchStatus status={data.status} /></dd></div>
          </dl>
          {data.rejectionReason && <p>{t('Причина отклонения', 'Reason for rejection')} — {data.rejectionReason}</p>}
        </section>
        <section id="boxes"><h2>{t('Список коробок', 'List of boxes')}</h2><BatchContents batch={data} showBarcodes /></section>
      </>}
  </>;
}

export default function BatchPage() {
  const { id } = useParams<{ id: string }>();
  const { t, user, authLoading } = useApp();
  if (authLoading) return <p role="status">{t('Загрузка…', 'Loading…')}</p>;
  if (!user) return <><PageHeader title={t('Нужен вход', 'Sign-in required')} /><Link href="/login">{t('Войти', 'Sign in')}</Link></>;
  if (user.type !== 'DEPOSITOR') return <p>{t('Раздел доступен депозиторам.', 'This section is available to depositors.')}</p>;
  return <BatchDetails key={user.id + ':' + id} id={id} />;
}
