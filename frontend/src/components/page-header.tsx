'use client';

import { useApp } from './providers';

export function PageHeader({ title }: { title: string }) {
  return <h1 className="page-title">{title}</h1>;
}

export function SessionNotice() {
  const { t, authError } = useApp();
  if (!authError) return null;
  return <p className="session-notice">
    {t('Не удалось проверить сессию. Обновите страницу.', 'Could not check the session. Reload the page.')}
  </p>;
}
