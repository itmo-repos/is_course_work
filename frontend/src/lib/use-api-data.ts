'use client';

import { useEffect, useState } from 'react';
import { api } from './api.mjs';

export function useApiData<T>(path: string) {
  const [data, setData] = useState<T | null>(null);
  const [failed, setFailed] = useState(false);
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    const controller = new AbortController();
    const { signal } = controller;
    api.request(path, { signal })
      .then(value => { if (!signal.aborted) setData(value); })
      .catch(() => { if (!signal.aborted) setFailed(true); });
    return () => controller.abort();
  }, [path, attempt]);

  function reload() {
    setData(null);
    setFailed(false);
    setAttempt(value => value + 1);
  }

  return { data, setData, failed, reload };
}
