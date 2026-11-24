'use client';

import { useState, type FormEvent } from 'react';
import { useRouter } from 'next/navigation';
import { api, ApiError } from '@/lib/api.mjs';
import { PageHeader } from '@/components/page-header';
import { useApp } from '@/components/providers';

export default function Login() {
  const { t, setUser } = useApp();
  const router = useRouter();
  const [state, setState] = useState<'idle' | 'pending' | 'invalid' | 'failed'>('idle');

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (state === 'pending') return;
    const form = event.currentTarget;
    const fields = new FormData(form);
    setState('pending');
    try {
      const user = await api.login(String(fields.get('email')).trim(), String(fields.get('password')));
      form.reset();
      setUser(user);
      router.push('/workspace');
    } catch (error) {
      setState(error instanceof ApiError && error.status === 401 ? 'invalid' : 'failed');
    }
  }

  return (
    <>
      <PageHeader title={t('Вход в систему', 'Sign in')} />
      <p>{t('Для депозиторов и сотрудников.', 'For depositors and staff.')}</p>
      <form className="form" onSubmit={submit}>
        <label htmlFor="email">Email</label>
        <input id="email" name="email" type="email" autoComplete="username" required />
        <label htmlFor="password">{t('Пароль', 'Password')}</label>
        <input id="password" name="password" type="password" autoComplete="current-password" required />
        {state === 'invalid' && <p role="alert">{t('Неверный email или пароль', 'Invalid email or password')}</p>}
        {state === 'failed' && <p role="alert">{t('Не удалось завершить вход. Повторите попытку.', 'Could not sign in. Please try again.')}</p>}
        <button disabled={state === 'pending'}>{state === 'pending' ? t('Входим…', 'Signing in…') : t('Войти', 'Sign in')}</button>
      </form>
    </>
  );
}
