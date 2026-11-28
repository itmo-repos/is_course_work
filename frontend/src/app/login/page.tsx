'use client';

import Link from 'next/link';
import { useState, type FormEvent } from 'react';
import { useRouter } from 'next/navigation';
import { api, ApiError } from '@/lib/api.mjs';
import { SessionNotice } from '@/components/page-header';
import { useApp } from '@/components/providers';

export default function Login() {
  const { t, setUser, user, toggleLanguage, lang } = useApp();
  const router = useRouter();
  const [state, setState] = useState<'idle' | 'pending' | 'invalid' | 'failed'>('idle');
  const [showPassword, setShowPassword] = useState(false);

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
    <div className="vault-login">
      <div className="login-image" aria-hidden="true" />
      <div className="login-content">
        <div className="auth-masthead">
          <Link href="/" className="auth-wordmark">SVALBARD</Link>
          <button className="auth-language" onClick={toggleLanguage} aria-label={t('Сменить язык', 'Change language')}>{lang === 'ru' ? 'EN' : 'RU'}</button>
        </div>
        <h1>{t('Вход в систему', 'Sign in')}</h1>
        <p className="login-intro">{t('Для сотрудников хранилища', 'For vault staff')}<br />{t('и зарегистрированных депозиторов', 'and registered depositors')}</p>
        <SessionNotice />
        <form className="login-form" onSubmit={submit}>
          <label htmlFor="email">Email</label>
          <div className="login-field">
            <svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="7" r="4" /><path d="M3 22v-2a9 9 0 0 1 18 0v2Z" /></svg>
            <input id="email" name="email" type="email" autoComplete="username" placeholder={t('Введите e-mail', 'Enter your email')} required />
          </div>
          <label htmlFor="password">{t('Пароль', 'Password')}</label>
          <div className="login-field">
            <svg viewBox="0 0 24 24" aria-hidden="true"><rect x="4" y="10" width="16" height="12" rx="1" /><path d="M7 10V6a5 5 0 0 1 10 0v4M12 15v3" /></svg>
            <input id="password" name="password" type={showPassword ? 'text' : 'password'} autoComplete="current-password" placeholder={t('Введите пароль', 'Enter your password')} required />
            <button type="button" className="password-eye" aria-pressed={showPassword} aria-label={t('Показать пароль', 'Show password')} onClick={() => setShowPassword(value => !value)}>
              <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12Z" /><circle cx="12" cy="12" r="3" />{showPassword && <path d="m3 3 18 18" />}</svg>
            </button>
          </div>
          {state === 'invalid' && <p role="alert">{t('Неверный email или пароль', 'Invalid email or password')}</p>}
          {state === 'failed' && <p role="alert">{t('Не удалось завершить вход. Повторите попытку.', 'Could not sign in. Please try again.')}</p>}
          <button className="public-button primary" disabled={state === 'pending'}>{state === 'pending' ? t('Входим…', 'Signing in…') : t('Войти', 'Sign in')}</button>
        </form>
        <div className="login-footer">
          <Link href={user ? '/workspace' : '/'}>{user ? t('Личный кабинет', 'Workspace') : t('На главную', 'Home')}</Link><span />
          <Link href="/register">{t('Регистрация организации', 'Register an organization')} <span aria-hidden="true">→</span></Link>
        </div>
      </div>
    </div>
  );
}
