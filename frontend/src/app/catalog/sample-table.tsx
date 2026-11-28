import { useState } from 'react';
import { useApp } from '@/components/providers';
import type { Sample } from '@/lib/types';

const pageSize = 8;

export function SampleTable({ samples }: { samples: Sample[] }) {
  const { t, lang } = useApp();
  const [page, setPage] = useState(1);
  if (!samples.length) return <p role="status">{t('Образцы не найдены', 'No samples found')}</p>;
  const pageCount = Math.ceil(samples.length / pageSize);
  const headings = [
    t('ID образца', 'Sample ID'), t('Культура / вид', 'Crop / species'), t('Страна происхождения', 'Country of origin'),
    t('Год сбора', 'Collection year'), t('Количество', 'Seeds'), t('Депозитор', 'Depositor'),
  ];

  return (
    <>
      <table>
        <caption className="public-sr-only">{t('Результаты поиска', 'Search results')}</caption>
        <thead>
          <tr>{headings.map(heading => <th key={heading} scope="col">{heading}</th>)}</tr>
        </thead>
        <tbody>
          {samples.slice((page - 1) * pageSize, page * pageSize).map(sample => (
            <tr key={sample.accessionCode}>
              <td>{sample.accessionCode}</td>
              <td>{sample.latinName} {sample.localName && <span>({sample.localName})</span>}</td>
              <td>{sample.originCountry}</td>
              <td>{sample.collectionYear ?? '—'}</td>
              <td>{sample.seedQuantity?.toLocaleString(lang) ?? '—'}</td>
              <td>{sample.depositorName}</td>
            </tr>
          ))}
        </tbody>
      </table>
      {pageCount > 1 && <nav className="catalog-pages" aria-label={t('Страницы результатов', 'Result pages')}>
        <button disabled={page === 1} onClick={() => setPage(page - 1)} aria-label={t('Назад', 'Previous')}>←</button>
        {Array.from({ length: pageCount }, (_, index) => index + 1).map(number =>
          <button key={number} aria-current={number === page ? 'page' : undefined} onClick={() => setPage(number)}>{number}</button>)}
        <button disabled={page === pageCount} onClick={() => setPage(page + 1)} aria-label={t('Вперёд', 'Next')}>→</button>
      </nav>}
    </>
  );
}
