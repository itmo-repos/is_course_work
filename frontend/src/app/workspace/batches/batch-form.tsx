import { useRef, useState, type FormEvent } from 'react';
import { useApp } from '@/components/providers';
import { api } from '@/lib/api.mjs';
import type { Batch, BatchData, Country, SamplePassport, Species } from '@/lib/types';
import { SpeciesForm } from './species-form';

type BoxFields = { id: number; samples: number[] };

function PassportFields({ id, index, species, countries, year, initial }: {
  id: number;
  index: number;
  species: Species[];
  countries: Country[];
  year: number;
  initial?: Omit<SamplePassport, 'note'> & { note: string | null };
}) {
  const { t } = useApp();
  return (
    <fieldset className="passport-fields">
      <legend>{t('Паспорт образца', 'Sample passport')} {index}</legend>
      <div className="passport-field">
        <label htmlFor={'species-' + id}>{t('Вид растения', 'Plant species')}</label>
        <select id={'species-' + id} name={'species-' + id} defaultValue={initial?.speciesId ?? ''} required>
          <option value="">{t('Выберите вид', 'Select a species')}</option>
          {species.map(item => <option key={item.id} value={item.id}>{item.latinName} — {item.localName}</option>)}
        </select>
      </div>
      <div className="passport-field">
        <label htmlFor={'country-' + id}>{t('Страна происхождения', 'Country of origin')}</label>
        <select id={'country-' + id} name={'country-' + id} defaultValue={initial?.originCountryCode ?? ''} required>
          <option value="">{t('Выберите страну', 'Select a country')}</option>
          {countries.map(country => <option key={country.code} value={country.code}>{country.name}</option>)}
        </select>
      </div>
      <div className="passport-field">
        <label htmlFor={'year-' + id}>{t('Год сбора', 'Collection year')}</label>
        <input id={'year-' + id} name={'year-' + id} defaultValue={initial?.collectionYear} type="number" min={1850} max={year} step={1} required />
      </div>
      <div className="passport-field">
        <label htmlFor={'quantity-' + id}>{t('Количество семян', 'Seed quantity')}</label>
        <input id={'quantity-' + id} name={'quantity-' + id} defaultValue={initial?.seedQuantity} type="number" min={1} max={2147483647} step={1} required />
      </div>
      <div className="passport-field">
        <label htmlFor={'note-' + id}>{t('Примечание (необязательно)', 'Note (optional)')}</label>
        <input id={'note-' + id} name={'note-' + id} defaultValue={initial?.note ?? ''} maxLength={5000} />
      </div>
    </fieldset>
  );
}

export function BatchForm({ countries, species, onSpeciesCreated, onSaved, initialBatch, onCancel }: {
  countries: Country[];
  species: Species[];
  onSpeciesCreated: (species: Species) => void;
  onSaved: (batch: Batch) => void;
  initialBatch?: Batch;
  onCancel?: () => void;
}) {
  const { t } = useApp();
  const nextId = useRef(-2);
  const [boxes, setBoxes] = useState<BoxFields[]>(() => initialBatch
    ? initialBatch.boxes.map(box => ({ id: box.id, samples: box.samples.map(sample => sample.id) }))
    : [{ id: 0, samples: [-1] }]);
  const initialSamples = new Map(initialBatch?.boxes.flatMap(box => box.samples.map(sample => [sample.id, sample] as const)));
  const [draft, setDraft] = useState<BatchData | null>(null);
  const [state, setState] = useState<'idle' | 'pending' | 'failed'>('idle');
  const now = new Date();
  const today = [
    now.getFullYear(),
    String(now.getMonth() + 1).padStart(2, '0'),
    String(now.getDate()).padStart(2, '0'),
  ].join('-');

  function updateSamples(boxId: number, samples: number[]) {
    setBoxes(previous => previous.map(box => box.id === boxId ? { ...box, samples } : box));
  }

  function addBox() {
    const box = { id: nextId.current--, samples: [nextId.current--] };
    setBoxes(previous => [...previous, box]);
  }

  function review(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const fields = new FormData(event.currentTarget);
    setDraft({
      desiredShipmentDate: String(fields.get('shipmentDate')),
      boxes: boxes.map(box => ({
        samples: box.samples.map(id => ({
          speciesId: Number(fields.get('species-' + id)),
          originCountryCode: String(fields.get('country-' + id)),
          collectionYear: Number(fields.get('year-' + id)),
          seedQuantity: Number(fields.get('quantity-' + id)),
          note: String(fields.get('note-' + id)).trim(),
        })),
      })),
    });
    setState('idle');
  }

  async function save() {
    if (!draft || state === 'pending') return;
    setState('pending');
    try {
      const path = '/depositors/me/batches' + (initialBatch ? '/' + initialBatch.id : '');
      onSaved(await api.request(path, {
        method: initialBatch ? 'PUT' : 'POST',
        body: JSON.stringify(draft),
      }));
    } catch {
      setState('failed');
    }
  }

  return (
    <section className="workspace-panel batch-editor" id="batch-editor">
      <h2>{initialBatch ? t('Исправление партии', 'Edit batch') + ' ' + initialBatch.number : t('Новая партия', 'New batch')}</h2>
      {onCancel && <button disabled={state === 'pending'} onClick={onCancel}>
        {t('Отменить редактирование', 'Cancel editing')}
      </button>}
      <div hidden={Boolean(draft)}>
        <SpeciesForm onCreated={onSpeciesCreated} />
        <form onSubmit={review}>
          <p className="form">
            <label htmlFor="shipment-date">{t('Желаемая дата отправки', 'Desired shipment date')}</label>
            <input id="shipment-date" name="shipmentDate" defaultValue={initialBatch?.desiredShipmentDate} type="date" min={today} required />
          </p>
          {boxes.map((box, boxIndex) => (
            <fieldset key={box.id}>
              <legend>{t('Коробка', 'Box')} {boxIndex + 1}</legend>
              {box.samples.map((id, sampleIndex) => (
                <div key={id}>
                  <PassportFields id={id} index={sampleIndex + 1} species={species} countries={countries} year={now.getFullYear()} initial={initialSamples.get(id)} />
                  {box.samples.length > 1 && <button type="button"
                    onClick={() => updateSamples(box.id, box.samples.filter(sampleId => sampleId !== id))}>
                    {t('Удалить паспорт', 'Remove passport')} {sampleIndex + 1}
                  </button>}
                </div>
              ))}
              <button type="button" disabled={box.samples.length >= 100}
                onClick={() => updateSamples(box.id, [...box.samples, nextId.current--])}>
                {t('Добавить паспорт', 'Add passport')}
              </button>
              {boxes.length > 1 && <button type="button" onClick={() => setBoxes(previous => previous.filter(item => item.id !== box.id))}>
                {t('Удалить коробку', 'Remove box')} {boxIndex + 1}
              </button>}
            </fieldset>
          ))}
          <div className="actions">
            <button type="button" disabled={boxes.length >= 100} onClick={addBox}>{t('Добавить коробку', 'Add box')}</button>
            <button>{t('Проверить состав', 'Review contents')}</button>
          </div>
        </form>
      </div>

      {draft && <section>
        <h3>{t('Проверка состава', 'Review contents')}</h3>
        <p>{t('Желаемая дата отправки', 'Desired shipment date')} — {draft.desiredShipmentDate}</p>
        {draft.boxes.map((box, index) => (
          <div key={boxes[index].id}>
            <h4>{t('Коробка', 'Box')} {index + 1}</h4>
            <table>
              <thead><tr>
                <th>{t('Вид растения', 'Plant species')}</th><th>{t('Страна происхождения', 'Country of origin')}</th>
                <th>{t('Год сбора', 'Collection year')}</th><th>{t('Количество семян', 'Seed quantity')}</th>
                <th>{t('Примечание', 'Note')}</th>
              </tr></thead>
              <tbody>{box.samples.map((sample, sampleIndex) => <tr key={boxes[index].samples[sampleIndex]}>
                <td>{species.find(item => item.id === sample.speciesId)?.latinName}</td>
                <td>{countries.find(item => item.code === sample.originCountryCode)?.name}</td>
                <td>{sample.collectionYear}</td><td>{sample.seedQuantity}</td><td>{sample.note || '—'}</td>
              </tr>)}</tbody>
            </table>
          </div>
        ))}
        {state === 'failed' && <p role="alert">{initialBatch
          ? t('Не удалось отправить партию повторно. Если статус изменился, закройте редактирование и обновите список.', 'Could not resubmit the batch. If the status changed, close the editor and refresh the list.')
          : t('Не удалось создать партию. Проверьте данные и повторите попытку.', 'Could not create the batch. Check the details and try again.')}</p>}
        <div className="actions">
          <button disabled={state === 'pending'} onClick={() => setDraft(null)}>{t('Вернуться к редактированию', 'Back to editing')}</button>
          <button disabled={state === 'pending'} onClick={save}>
            {state === 'pending' ? t('Отправляем…', 'Submitting…') : initialBatch
              ? t('Отправить повторно', 'Resubmit batch') : t('Создать партию', 'Create batch')}
          </button>
        </div>
      </section>}
    </section>
  );
}
