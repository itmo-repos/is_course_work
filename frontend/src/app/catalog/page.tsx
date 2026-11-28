'use client';

import { useEffect, useState, type FormEvent } from 'react';
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

  function reset() {
    setSpecies('');
    setCountry('');
    setResult({ status: 'loading' });
    setQuery(new URLSearchParams());
  }

  return (
    <article className="vault-catalog">
      <h1>{t('Каталог образцов', 'Sample catalog')}</h1>
      <p className="catalog-subtitle">{t('Публичный реестр депонированных коллекций', 'Public register of deposited collections')}</p>
      <form className="catalog-searchbar" id="catalog-filter" onSubmit={search}>
        <label className="catalog-search">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" aria-hidden="true"><circle cx="10" cy="10" r="7" /><path d="m15 15 7 7" /></svg>
          <span className="public-sr-only">{t('Вид растения', 'Species')}</span>
          <input maxLength={160} value={species} onChange={event => setSpecies(event.target.value)}
            placeholder={t('Поиск по латинскому или местному названию вида…', 'Search by Latin or local species name…')} />
        </label>
        {result.status === 'ready' && <p>{t('В выборке', 'Results returned')} — {result.samples.length}</p>}
      </form>
      <div className="catalog-layout">
        <aside className="catalog-sidebar">
          <label htmlFor="catalog-country">{t('Страна происхождения', 'Country of origin')}</label>
          <select id="catalog-country" form="catalog-filter" value={country} disabled={!countries} onChange={event => setCountry(event.target.value)}>
            <option value="">{t('Все страны', 'All countries')}</option>
            {countries?.map(item => <option key={item.code} value={item.code}>{item.name}</option>)}
          </select>
          {!countries && <p>{t('Справочник стран недоступен. Поиск по виду остаётся доступен.', 'Countries are unavailable. You can still search by species.')}</p>}
          <div className="catalog-filter-actions">
            <button type="submit" form="catalog-filter" className="public-button primary" disabled={result.status === 'loading'}>{t('Найти', 'Search')}</button>
            <button type="button" className="public-button" onClick={reset}>{t('Сбросить', 'Reset')}</button>
          </div>
        </aside>
        <section className="catalog-results" aria-label={t('Результаты поиска', 'Search results')}>
          {result.status === 'loading' && <p role="status">{t('Загрузка…', 'Loading…')}</p>}
          {result.status === 'error' && (
            <div role="alert">
              <p>{t('Не удалось загрузить каталог. Фильтры сохранены.', 'Could not load the catalog. Filters have been preserved.')}</p>
              <button onClick={() => search()}>{t('Повторить', 'Retry')}</button>
            </div>
          )}
          {result.status === 'ready' && <SampleTable samples={result.samples} />}
        </section>
      </div>
    </article>
  );
}
