import { useState, type FormEvent } from 'react';
import { useApp } from '@/components/providers';
import { api, ApiError } from '@/lib/api.mjs';
import type { DepositorApplication } from '@/lib/types';

const maxScanBytes = 15 * 1024 * 1024;

export function ContractUpload({ onUploaded, resubmitting }: {
  onUploaded: (application: DepositorApplication) => void;
  resubmitting: boolean;
}) {
  const { t } = useApp();
  const [state, setState] = useState<'idle' | 'pending' | 'size' | 'invalid' | 'stale' | 'failed'>('idle');

  async function upload(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (state === 'pending' || state === 'stale') return;
    const body = new FormData(event.currentTarget);
    const file = body.get('file');
    if (!(file instanceof File) || !file.size) {
      setState('invalid');
      return;
    }
    if (file.size > maxScanBytes) {
      setState('size');
      return;
    }
    setState('pending');
    try {
      onUploaded(await api.request('/depositors/me/contract/scan', { method: 'POST', body }));
    } catch (error) {
      if (error instanceof ApiError && error.status === 409) setState('stale');
      else if (error instanceof ApiError && error.status === 413) setState('size');
      else if (error instanceof ApiError && error.status === 400) setState('invalid');
      else setState('failed');
    }
  }

  return (
    <form className="form" onSubmit={upload}>
      <label htmlFor="contract-scan">{t('Подписанный скан', 'Signed scan')}</label>
      <input id="contract-scan" name="file" type="file"
        accept=".pdf,.jpg,.jpeg,.png,application/pdf,image/jpeg,image/png"
        aria-describedby="contract-scan-help" required disabled={state === 'pending'} />
      <small id="contract-scan-help">{t('PDF, JPEG или PNG, до 15 МиБ.', 'PDF, JPEG or PNG, up to 15 MiB.')}</small>
      {state === 'size' && <p role="alert">{t('Файл превышает 15 МиБ.', 'The file exceeds 15 MiB.')}</p>}
      {state === 'invalid' && <p role="alert">{t('Выберите непустой PDF, JPEG или PNG.', 'Choose a non-empty PDF, JPEG or PNG.')}</p>}
      {state === 'stale' && <p role="alert">{t('Статус договора изменился. Обновите статус.', 'The contract status has changed. Refresh the status.')}</p>}
      {state === 'failed' && <p role="alert">{t('Не удалось загрузить скан. Повторите попытку.', 'Could not upload the scan. Try again.')}</p>}
      <button disabled={state === 'pending' || state === 'stale'}>
        {state === 'pending' ? t('Загрузка…', 'Uploading…')
          : resubmitting ? t('Отправить исправленный скан', 'Submit corrected scan') : t('Отправить скан', 'Submit scan')}
      </button>
    </form>
  );
}
