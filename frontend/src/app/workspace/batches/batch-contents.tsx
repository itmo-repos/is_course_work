import { useApp } from '@/components/providers';
import type { Batch } from '@/lib/types';

export function BatchContents({ batch, showBarcodes = false }: { batch: Batch; showBarcodes?: boolean }) {
  const { t } = useApp();
  return (
    <>
      {batch.boxes.map(box => (
        <section key={box.id}>
          <h3>{t('Коробка', 'Box')} {box.seqNo}</h3>
          {showBarcodes && box.barcode && <p>
            <a href={`/api/depositors/me/batches/${batch.id}/boxes/${box.id}/barcode`}>
              {t('Скачать штрихкод', 'Download barcode')} {box.barcode} (SVG)
            </a>
          </p>}
          <table>
            <thead><tr>
              <th>{t('Код образца', 'Accession code')}</th><th>{t('Вид', 'Species')}</th>
              <th>{t('Код страны', 'Country code')}</th><th>{t('Год сбора', 'Collection year')}</th>
              <th>{t('Количество семян', 'Seed quantity')}</th><th>{t('Примечание', 'Note')}</th>
            </tr></thead>
            <tbody>{box.samples.map(sample => <tr key={sample.id}>
              <td>{sample.accessionCode}</td><td>{sample.latinName}</td>
              <td>{sample.originCountryCode}</td><td>{sample.collectionYear}</td>
              <td>{sample.seedQuantity}</td><td>{sample.note || '—'}</td>
            </tr>)}</tbody>
          </table>
        </section>
      ))}
    </>
  );
}
