import { useState, type FormEvent } from 'react';
import { useApp } from '@/components/providers';
import { api, ApiError } from '@/lib/api.mjs';
import type { Species } from '@/lib/types';

export function SpeciesForm({ onCreated }: { onCreated: (species: Species) => void }) {
  const { t } = useApp();
  const [state, setState] = useState<'idle' | 'pending' | 'duplicate' | 'invalid' | 'failed'>('idle');
  const [created, setCreated] = useState('');

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (state === 'pending') return;
    const form = event.currentTarget;
    const fields = new FormData(form);
    const latinName = String(fields.get('latinName')).trim();
    const localName = String(fields.get('localName')).trim();
    setCreated('');
    if (!latinName || !localName) {
      setState('invalid');
      return;
    }

    setState('pending');
    try {
      const species: Species = await api.request('/depositors/me/species', {
        method: 'POST',
        body: JSON.stringify({ latinName, localName, family: String(fields.get('family')).trim() }),
      });
      onCreated(species);
      setCreated(species.latinName);
      form.reset();
      setState('idle');
    } catch (error) {
      setState(error instanceof ApiError && error.status === 409 ? 'duplicate' : 'failed');
    }
  }

  return (
    <details>
      <summary>{t('Добавить вид в справочник', 'Add species to the directory')}</summary>
      <form className="form" onSubmit={submit}>
        <label htmlFor="species-latin">{t('Латинское название', 'Latin name')}</label>
        <input id="species-latin" name="latinName" required maxLength={160} disabled={state === 'pending'} />
        <label htmlFor="species-local">{t('Местное название', 'Local name')}</label>
        <input id="species-local" name="localName" required maxLength={160} disabled={state === 'pending'} />
        <label htmlFor="species-family">{t('Семейство (необязательно)', 'Family (optional)')}</label>
        <input id="species-family" name="family" maxLength={120} disabled={state === 'pending'} />
        {state === 'duplicate' && <p role="alert">{t('Вид с таким латинским названием уже есть.', 'A species with this Latin name already exists.')}</p>}
        {state === 'invalid' && <p role="alert">{t('Укажите оба названия вида.', 'Enter both species names.')}</p>}
        {state === 'failed' && <p role="alert">{t('Не удалось добавить вид. Повторите попытку.', 'Could not add the species. Try again.')}</p>}
        {created && <p role="status">{t('Вид добавлен', 'Species added')} — {created}</p>}
        <button disabled={state === 'pending'}>{t('Сохранить вид', 'Save species')}</button>
      </form>
    </details>
  );
}
