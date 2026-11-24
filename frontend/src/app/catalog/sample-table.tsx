import { useApp } from '@/components/providers';
import type { Sample } from '@/lib/types';

export function SampleTable({ samples }: { samples: Sample[] }) {
  const { t } = useApp();
  if (!samples.length) return <p role="status">{t('Образцы не найдены', 'No samples found')}</p>;

  const headings = [
    t('Код', 'Code'), t('Вид', 'Species'), t('Страна', 'Country'),
    t('Год', 'Year'), t('Семян', 'Seeds'), t('Депозитор', 'Depositor'),
  ];
  return (
    <table>
      <caption>{t('Результаты поиска', 'Search results')}</caption>
      <thead>
        <tr>{headings.map(heading => <th key={heading} scope="col">{heading}</th>)}</tr>
      </thead>
      <tbody>
        {samples.map(sample => (
          <tr key={sample.accessionCode}>
            <td>{sample.accessionCode}</td>
            <td><i>{sample.latinName}</i><br />{sample.localName}</td>
            <td>{sample.originCountry}</td>
            <td>{sample.collectionYear ?? '—'}</td>
            <td>{sample.seedQuantity ?? '—'}</td>
            <td>{sample.depositorName}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}
