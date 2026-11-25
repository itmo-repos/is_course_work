'use client';

import Link from 'next/link';
import { useState, type FormEvent } from 'react';
import { PageHeader } from '@/components/page-header';
import { useApp } from '@/components/providers';
import { api, ApiError } from '@/lib/api.mjs';
import type { Country } from '@/lib/types';
import { useApiData } from '@/lib/use-api-data';

function ApplicationForm() {
  const { t } = useApp();
  const countries = useApiData<Country[]>('/samples/countries');
  const [state, setState] = useState<'idle' | 'pending' | 'sent' | 'conflict' | 'invalid' | 'failed'>('idle');

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (state === 'pending') return;
    const fields = Object.fromEntries(new FormData(event.currentTarget));
    setState('pending');
    try {
      await api.request('/depositors/applications', { method: 'POST', body: JSON.stringify(fields) });
      setState('sent');
    } catch (error) {
      if (error instanceof ApiError && error.status === 409) setState('conflict');
      else if (error instanceof ApiError && error.status === 400) setState('invalid');
      else setState('failed');
    }
  }

  if (state === 'sent') return (
    <>
      <p role="status">{t('Заявка отправлена.', 'Application submitted.')}</p>
      <p>{t('Войдите с указанными email и паролем, чтобы следить за статусом заявки.', 'Sign in with your email and password to check your application status.')}</p>
      <Link href="/login">{t('Войти в личный кабинет', 'Sign in to your workspace')}</Link>
    </>
  );

  return (
    <form className="form" onSubmit={submit}>
      <label htmlFor="legalName">{t('Название организации', 'Organization name')}</label>
      <input id="legalName" name="legalName" autoComplete="organization" maxLength={300} required />
      <label htmlFor="countryCode">{t('Страна', 'Country')}</label>
      <select id="countryCode" name="countryCode" defaultValue="" required disabled={!countries.data?.length}>
        <option value="">{t('Выберите страну', 'Select a country')}</option>
        {countries.data?.map(country => <option key={country.code} value={country.code}>{country.name}</option>)}
      </select>
      {(countries.failed || countries.data?.length === 0) && <div role="alert">
        <p>{t('Список стран недоступен.', 'The country list is unavailable.')}</p>
        <button type="button" onClick={countries.reload}>{t('Повторить', 'Retry')}</button>
      </div>}
      <label htmlFor="registrationNumber">{t('Регистрационный номер', 'Registration number')}</label>
      <input id="registrationNumber" name="registrationNumber" maxLength={64} required />
      <label htmlFor="legalAddress">{t('Юридический адрес', 'Registered address')}</label>
      <input id="legalAddress" name="legalAddress" maxLength={5000} required />
      <label htmlFor="contactPerson">{t('Контактное лицо', 'Contact person')}</label>
      <input id="contactPerson" name="contactPerson" autoComplete="name" maxLength={200} required />
      <label htmlFor="contactEmail">Email</label>
      <input id="contactEmail" name="contactEmail" type="email" autoComplete="email" maxLength={254} required />
      <label htmlFor="contactPhone">{t('Телефон (необязательно)', 'Phone (optional)')}</label>
      <input id="contactPhone" name="contactPhone" type="tel" autoComplete="tel" maxLength={32} />
      <label htmlFor="password">{t('Пароль', 'Password')}</label>
      <input id="password" name="password" type="password" autoComplete="new-password" minLength={8} maxLength={128} required />
      <small>{t('От 8 до 128 символов.', '8 to 128 characters.')}</small>
      {state === 'conflict' && <p role="alert">{t('Email, название организации или регистрационные данные уже используются.', 'The email, organization name or registration details are already in use.')}</p>}
      {state === 'invalid' && <p role="alert">{t('Проверьте введённые данные.', 'Check your application details.')}</p>}
      {state === 'failed' && <p role="alert">{t('Не удалось отправить заявку. Повторите попытку.', 'Could not submit the application. Please try again.')}</p>}
      <button disabled={state === 'pending' || !countries.data?.length}>
        {state === 'pending' ? t('Отправка…', 'Submitting…') : t('Отправить заявку', 'Submit application')}
      </button>
    </form>
  );
}

export default function Register() {
  const { t, user, authLoading } = useApp();
  return (
    <>
      <PageHeader title={t('Регистрация депозитора', 'Depositor registration')} />
      {authLoading ? <p>{t('Загрузка…', 'Loading…')}</p> : user
        ? <Link href="/workspace">{t('Перейти в личный кабинет', 'Go to workspace')}</Link>
        : <ApplicationForm />}
    </>
  );
}
