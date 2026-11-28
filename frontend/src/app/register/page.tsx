'use client';

import Link from 'next/link';
import { useState, type FormEvent } from 'react';
import { SessionNotice } from '@/components/page-header';
import { useApp } from '@/components/providers';
import { api, ApiError } from '@/lib/api.mjs';
import type { Country } from '@/lib/types';
import { useApiData } from '@/lib/use-api-data';

type SectionId = 'organization' | 'contact' | 'confirmation';

function ApplicationForm({ selectSection, onSuccess }: { selectSection: (section: SectionId) => void; onSuccess: () => void }) {
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
      onSuccess();
    } catch (error) {
      if (error instanceof ApiError && error.status === 409) setState('conflict');
      else if (error instanceof ApiError && error.status === 400) setState('invalid');
      else setState('failed');
    }
  }

  if (state === 'sent') return (
    <section className="registration-success">
      <h1 role="status">{t('Заявка отправлена.', 'Application submitted.')}</h1>
      <p>{t('Войдите с указанными email и паролем, чтобы следить за статусом заявки.', 'Sign in with your email and password to check your application status.')}</p>
      <Link className="public-button primary" href="/login">{t('Войти в личный кабинет', 'Sign in to your workspace')}</Link>
    </section>
  );

  return (
    <form className="registration-form" onSubmit={submit}>
      <section id="organization" onFocus={() => selectSection('organization')}>
        <h1>{t('Данные организации', 'Organization details')}</h1>
        <p className="registration-subtitle">{t('Основная информация о вашей организации', 'Tell us about your organization')}</p>
        <div className="registration-grid">
          <label className="full">{t('Название организации', 'Organization name')}
            <input name="legalName" autoComplete="organization" maxLength={300} required placeholder={t('Например, Институт растениеводства', 'For example, Institute of Plant Science')} />
          </label>
          <label>{t('Страна', 'Country')}
            <select name="countryCode" defaultValue="" required disabled={!countries.data?.length}>
              <option value="">{t('Выберите страну', 'Select a country')}</option>
              {countries.data?.map(country => <option key={country.code} value={country.code}>{country.name}</option>)}
            </select>
          </label>
          <label>{t('Регистрационный номер', 'Registration number')}
            <input name="registrationNumber" maxLength={64} required placeholder={t('Введите номер', 'Enter a number')} />
          </label>
          {(countries.failed || countries.data?.length === 0) && <div className="full" role="alert">
            <p>{t('Список стран недоступен.', 'The country list is unavailable.')}</p>
            <button type="button" onClick={countries.reload}>{t('Повторить', 'Retry')}</button>
          </div>}
          <label className="full">{t('Юридический адрес', 'Registered address')}
            <input name="legalAddress" autoComplete="street-address" maxLength={5000} required placeholder={t('Введите адрес', 'Enter an address')} />
          </label>
        </div>
      </section>
      <section id="contact" onFocus={() => selectSection('contact')}>
        <h2>{t('Контактное лицо', 'Contact person')}</h2>
        <div className="registration-grid">
          <label className="full">{t('Контактное лицо', 'Contact person')}
            <input name="contactPerson" autoComplete="name" maxLength={200} required placeholder={t('Имя и фамилия', 'Full name')} />
          </label>
          <label>Email
            <input name="contactEmail" type="email" autoComplete="email" maxLength={254} required placeholder="name@example.org" />
          </label>
          <label>{t('Телефон (необязательно)', 'Phone (optional)')}
            <input name="contactPhone" type="tel" autoComplete="tel" maxLength={32} />
          </label>
        </div>
      </section>
      <section id="confirmation" onFocus={() => selectSection('confirmation')}>
        <h2>{t('Подтверждение', 'Confirmation')}</h2>
        <div className="registration-grid">
          <div>
            <label htmlFor="password">{t('Пароль', 'Password')}</label>
            <input id="password" name="password" type="password" autoComplete="new-password" minLength={8} maxLength={128} aria-describedby="password-hint" required />
            <small id="password-hint">{t(
              'От 8 до 128 символов. При повторной подаче используйте прежние email и пароль.',
              '8 to 128 characters. To resubmit, use your original email and password.',
            )}</small>
          </div>
        </div>
        {state === 'conflict' && <p role="alert">{t(
          'Email или реквизиты уже используются. Если заявку отклонили, проверьте прежние email и пароль.',
          'The email or organization details are already in use. If your application was rejected, check your original email and password.',
        )}</p>}
        {state === 'invalid' && <p role="alert">{t('Проверьте введённые данные.', 'Check your application details.')}</p>}
        {state === 'failed' && <p role="alert">{t('Не удалось отправить заявку. Повторите попытку.', 'Could not submit the application. Please try again.')}</p>}
        <div className="registration-footer">
          <Link href="/login">{t('Отмена', 'Cancel')}</Link>
          <button className="public-button primary" disabled={state === 'pending' || !countries.data?.length}>
            {state === 'pending' ? t('Отправка…', 'Submitting…') : t('Отправить заявку', 'Submit application')}
          </button>
        </div>
      </section>
    </form>
  );
}

export default function Register() {
  const { t, user, authLoading, lang, toggleLanguage } = useApp();
  const [active, setActive] = useState<SectionId>('organization');
  const [sent, setSent] = useState(false);
  const sections: { id: SectionId; title: string }[] = [
    { id: 'organization', title: t('Данные организации', 'Organization details') },
    { id: 'contact', title: t('Контактное лицо', 'Contact person') },
    { id: 'confirmation', title: t('Подтверждение', 'Confirmation') },
  ];

  function finish() {
    setSent(true);
  }

  return (
    <div className="vault-registration">
      <aside className="registration-sidebar">
        <Link href="/" className="auth-wordmark">SVALBARD</Link>
        <h2>{t('Регистрация организации', 'Organization registration')}</h2>
        <p>{t('Заявка на получение статуса депозитора', 'Application for depositor status')}</p>
        {!user && !sent && !authLoading && <ol className="registration-steps">
          {sections.map((section, index) => <li key={section.id}>
            <a href={'#' + section.id} onClick={() => setActive(section.id)} aria-current={active === section.id ? 'step' : undefined}>
              <span aria-hidden="true">{index + 1}</span>{section.title}
            </a>
          </li>)}
        </ol>}
        <div className="registration-note">
          <span aria-hidden="true">ⓘ</span>
          <p>{t('После отправки заявка будет рассмотрена администратором. Статус вы можете отследить в личном кабинете.', 'An administrator will review your application. You can follow its status in your workspace.')}</p>
        </div>
      </aside>
      <div className="registration-content">
        <button className="auth-language" onClick={toggleLanguage} aria-label={t('Сменить язык', 'Change language')}>{lang === 'ru' ? 'EN' : 'RU'}</button>
        <SessionNotice />
        {authLoading ? <p role="status">{t('Загрузка…', 'Loading…')}</p> : user
          ? <><h1>{t('Регистрация организации', 'Organization registration')}</h1><Link href="/workspace">{t('Перейти в личный кабинет', 'Go to workspace')}</Link></>
          : <ApplicationForm selectSection={setActive} onSuccess={finish} />}
      </div>
    </div>
  );
}
