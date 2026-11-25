import { afterEach, expect, test, vi } from 'vitest';
import { cleanup, render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import Register from '@/app/register/page';
import { Providers } from '@/components/providers';
import { api, ApiError } from '@/lib/api.mjs';

vi.mock('next/navigation', () => ({ usePathname: () => '/register' }));
afterEach(() => { cleanup(); vi.restoreAllMocks(); });

test('a conflict preserves the application and allows a corrected submission', async () => {
  const submit = vi.fn().mockRejectedValueOnce(new ApiError(409)).mockResolvedValueOnce({ id: 7 });
  vi.spyOn(api, 'request').mockImplementation(async (path, options) => {
    if (path === '/samples/countries') return [{ code: 'NO', name: 'Норвегия' }];
    if (path === '/depositors/applications') return submit(JSON.parse(String(options?.body)));
    throw new ApiError(401);
  });
  render(<Providers><Register /></Providers>);
  const user = userEvent.setup();
  const fields = {
    'Название организации': 'Seed Bank', 'Регистрационный номер': 'REG-7',
    'Юридический адрес': 'Oslo 7', 'Контактное лицо': 'Alex',
    'Email': 'test@example.org', 'Пароль': 'sample-password',
  };
  for (const [label, value] of Object.entries(fields)) await user.type(await screen.findByLabelText(label), value);
  await user.selectOptions(screen.getByLabelText('Страна'), 'NO');
  await user.click(screen.getByRole('button', { name: 'Отправить заявку' }));
  expect(await screen.findByRole('alert')).toBeVisible();
  for (const [label, value] of Object.entries(fields)) expect(screen.getByLabelText(label)).toHaveValue(value);
  expect(screen.getByLabelText('Страна')).toHaveValue('NO');
  await user.clear(screen.getByLabelText('Email'));
  await user.type(screen.getByLabelText('Email'), 'other@example.org');
  await user.click(screen.getByRole('button', { name: 'Отправить заявку' }));
  expect(await screen.findByText('Заявка отправлена.')).toBeVisible();
  expect(submit).toHaveBeenLastCalledWith({
    legalName: 'Seed Bank', registrationNumber: 'REG-7', legalAddress: 'Oslo 7',
    contactPerson: 'Alex', contactEmail: 'other@example.org', password: 'sample-password',
    countryCode: 'NO', contactPhone: '',
  });
});
