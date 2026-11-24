'use client';

import { useEffect, useState, type FormEvent } from 'react';
import { PageHeader } from '@/components/page-header';
import { useApp } from '@/components/providers';
import { api } from '@/lib/api.mjs';
import type { Country, Sample } from '@/lib/types';
import { SampleTable } from './sample-table';

type Result = { status: 'loading' | 'error' } | { status: 'ready'; samples: Sample[] };

export default function Catalog() {
  const { t } = useApp();
  const [species, setSpecies] = useState('');
  const [country, setCountry] = useState('');
  const [countries, setCountries] = useState<Country[] | null>([]);
  const [query, setQuery] = useState(new URLSearchParams());
  const [result, setResult] = useState<Result>({ status: 'loading' });

  useEffect(() => {
    const controller = new AbortController();
    const { signal } = controller;
    api.request('/samples/countries', { signal })
      .then(data => { if (!signal.aborted) setCountries(data); })
      .catch(() => { if (!signal.aborted) setCountries(null); });
    return () => controller.abort();
  }, []);

  useEffect(() => {
    const controller = new AbortController();
    const { signal } = controller;
    api.request('/samples?' + query, { signal })
      .then(samples => { if (!signal.aborted) setResult({ status: 'ready', samples }); })
      .catch(() => { if (!signal.aborted) setResult({ status: 'error' }); });
    return () => controller.abort();
  }, [query]);

  function search(event?: FormEvent) {
    event?.preventDefault();
    const params = new URLSearchParams();
    if (species.trim()) params.set('species', species.trim());
    if (country) params.set('country', country);
    setResult({ status: 'loading' });
    setQuery(params);
  }

  return (
    <>
      <PageHeader title={t('Каталог образцов', 'Sample catalog')} />
      <form className="filters" onSubmit={search}>
        <label>
          {t('Вид растения', 'Species')}
          <input maxLength={160} value={species} onChange={e => setSpecies(e.target.value)} placeholder="Triticum" />
        </label>
        <label>
          {t('Страна происхождения', 'Country of origin')}
          <select value={country} disabled={!countries} onChange={e => setCountry(e.target.value)}>
            <option value="">{t('Все страны', 'All countries')}</option>
            {countries?.map(item => <option key={item.code} value={item.code}>{item.name}</option>)}
          </select>
        </label>
        <button disabled={result.status === 'loading'}>{t('Найти', 'Search')}</button>
      </form>
      {!countries && <p className="notice">{t('Справочник стран недоступен. Поиск по виду остаётся доступен.', 'Countries are unavailable. You can still search by species.')}</p>}
      {result.status === 'loading' && <p role="status">{t('Загрузка…', 'Loading…')}</p>}
      {result.status === 'error' && (
        <div role="alert">
          <p>{t('Не удалось загрузить каталог. Фильтры сохранены.', 'Could not load the catalog. Filters have been preserved.')}</p>
          <button onClick={() => search()}>{t('Повторить', 'Retry')}</button>
        </div>
      )}
      {result.status === 'ready' && <SampleTable samples={result.samples} />}
      <p>{t('Публичные паспорта без точных координат хранения.', 'Public records without precise storage locations.')}</p>
    </>
  );
}
