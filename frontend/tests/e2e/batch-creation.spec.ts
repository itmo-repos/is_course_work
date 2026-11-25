import { randomUUID } from 'node:crypto';
import { expect, test } from '@playwright/test';

// Run against a disposable database with an active depositor and country NO.
const email = process.env.BATCH_TEST_DEPOSITOR_EMAIL;
const password = process.env.BATCH_TEST_DEPOSITOR_PASSWORD;

test('an active depositor reviews, corrects and creates a batch with two boxes', async ({ page }) => {
  test.skip(!email || !password, 'Requires a test backend and an active test depositor');
  const species = 'Test species ' + randomUUID();
  const date = String(new Date().getFullYear() + 1) + '-01-20';

  await page.goto('/login');
  await page.getByLabel('Email').fill(email!);
  await page.getByLabel('Пароль').fill(password!);
  await page.getByRole('button', { name: 'Войти', exact: true }).click();
  await expect(page).toHaveURL(/\/workspace$/);
  await page.getByRole('link', { name: 'Мои партии' }).click();

  await page.getByLabel('Желаемая дата отправки').fill(date);
  await page.getByText('Добавить вид в справочник', { exact: true }).click();
  await page.getByLabel('Латинское название').fill(species);
  await page.getByLabel('Местное название').fill('Тестовый вид');
  await page.getByRole('button', { name: 'Сохранить вид' }).click();
  await expect(page.getByText('Вид добавлен — ' + species)).toBeVisible();

  const box1 = page.getByRole('group', { name: 'Коробка 1', exact: true });
  await box1.getByRole('button', { name: 'Добавить паспорт' }).click();
  await box1.getByRole('button', { name: 'Удалить паспорт 2' }).click();
  await page.getByRole('button', { name: 'Добавить коробку' }).click();
  for (const [index, quantity] of [[1, 100], [2, 200]]) {
    const box = page.getByRole('group', { name: 'Коробка ' + index, exact: true });
    await box.getByLabel('Вид растения').selectOption({ label: species + ' — Тестовый вид' });
    await box.getByLabel('Страна происхождения').selectOption('NO');
    await box.getByLabel('Год сбора').fill('2024');
    await box.getByLabel('Количество семян').fill(String(quantity));
  }
  await page.getByRole('button', { name: 'Проверить состав' }).click();
  await expect(page.getByRole('heading', { name: 'Проверка состава' })).toBeVisible();
  await expect(page.getByRole('row').filter({ hasText: species })).toHaveCount(2);
  await page.getByRole('button', { name: 'Вернуться к редактированию' }).click();
  const quantity = box1.getByLabel('Количество семян');
  await expect(quantity).toHaveValue('100');
  await quantity.fill('101');
  await page.getByRole('button', { name: 'Проверить состав' }).click();
  await expect(page.getByRole('cell', { name: '101', exact: true })).toBeVisible();

  await page.route('**/api/depositors/me/batches', route => route.fulfill({ status: 503 }), { times: 1 });
  await page.getByRole('button', { name: 'Создать партию' }).click();
  await expect(page.getByText('Не удалось создать партию.', { exact: false })).toBeVisible();
  await expect(page.getByRole('cell', { name: '101', exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'Создать партию' }).click();

  const success = page.getByRole('status').filter({ hasText: 'Партия создана' });
  await expect(success).toBeVisible();
  const number = (await success.innerText()).split(' — ')[1];
  const row = page.getByRole('row').filter({ hasText: number });
  await expect(row).toContainText('Сформирована');
  await expect(row).toContainText(date);
  await expect(row.getByRole('cell', { name: '2', exact: true })).toBeVisible();
  await page.reload();
  await expect(row).toContainText('Сформирована');
});
