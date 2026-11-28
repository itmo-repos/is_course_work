import { useApp } from '@/components/providers';
import type { Batch } from '@/lib/types';

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

export function BatchStatus({ status }: { status: Batch['status'] }) {
  const { t } = useApp();
  return <span className="workspace-status" data-status={status}>{t(...statusLabels[status])}</span>;
}
