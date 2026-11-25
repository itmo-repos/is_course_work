import { expect, test, type Page } from '@playwright/test';

const depositorEmail = process.env.BATCH_TEST_DEPOSITOR_EMAIL;
const depositorPassword = process.env.BATCH_TEST_DEPOSITOR_PASSWORD;
const curatorEmail = process.env.BATCH_TEST_CURATOR_EMAIL;
const curatorPassword = process.env.BATCH_TEST_CURATOR_PASSWORD;

async function signIn(page: Page, email: string, password: string) {
  await page.goto('/login');
  await page.getByLabel('Email').fill(email);
  await page.getByLabel('Пароль').fill(password);
  await page.getByRole('button', { name: 'Войти', exact: true }).click();
  await expect(page).toHaveURL(/\/workspace$/);
}

test('curator rejects a batch, depositor corrects it, and confirmation enables SVG downloads', async ({ page, browser, baseURL }) => {
  test.skip(!depositorEmail || !depositorPassword || !curatorEmail || !curatorPassword,
    'Requires a disposable test backend with an active depositor and a curator');

  await signIn(page, depositorEmail!, depositorPassword!);
  const species = await (await page.request.get('/api/samples/species')).json();
  const csrf = await (await page.request.get('/api/auth/csrf')).json();
  const sample = { speciesId: species[0].id, originCountryCode: 'NO', collectionYear: 2024, seedQuantity: 100, note: 'Original note' };
  const created = await page.request.post('/api/depositors/me/batches', {
    headers: { [csrf.headerName]: csrf.token },
    data: {
      desiredShipmentDate: (new Date().getFullYear() + 1) + '-02-01',
      boxes: [{ samples: [sample] }, { samples: [{ ...sample, seedQuantity: 200 }] }],
    },
  });
  expect(created.status()).toBe(201);
  const { number } = await created.json();

  const context = await browser.newContext({ baseURL });
  try {
    const curator = await context.newPage();
    await signIn(curator, curatorEmail!, curatorPassword!);
    await curator.getByRole('link', { name: 'Приём и склад' }).click();
    const pending = curator.getByRole('row').filter({ has: curator.getByRole('cell', { name: number, exact: true }) });
    await pending.getByText('Открыть состав', { exact: true }).click();
    await expect(pending.getByText('Original note', { exact: true })).toHaveCount(2);
    const reject = pending.getByRole('button', { name: 'Отклонить партию' });
    await expect(reject).toBeDisabled();
    const reason = 'Уточните примечание первой коробки';
    await pending.getByLabel('Причина отклонения').fill(reason);
    await reject.click();
    await expect(pending).toHaveCount(0);

    await page.getByRole('link', { name: 'Мои партии' }).click();
    const row = page.getByRole('row').filter({ has: page.getByRole('cell', { name: number, exact: true }) });
    await expect(row).toContainText(reason);
    await row.getByText('Открыть состав', { exact: true }).click();
    await expect(row.getByRole('link', { name: /Скачать штрихкод/ })).toHaveCount(0);
    await row.getByRole('button', { name: 'Исправить партию' }).click();
    const box = page.getByRole('group', { name: 'Коробка 1', exact: true });
    await expect(box.getByLabel('Вид растения')).toHaveValue(String(sample.speciesId));
    await expect(box.getByLabel('Страна происхождения')).toHaveValue('NO');
    await expect(box.getByLabel('Количество семян')).toHaveValue('100');
    await expect(box.getByLabel('Примечание (необязательно)')).toHaveValue('Original note');
    await box.getByLabel('Примечание (необязательно)').fill('Corrected note');
    await page.getByRole('button', { name: 'Проверить состав' }).click();
    await page.getByRole('button', { name: 'Отправить повторно' }).click();
    await expect(row).toContainText('Сформирована');
    await expect(row).not.toContainText(reason);

    await curator.reload();
    await pending.getByText('Открыть состав', { exact: true }).click();
    await expect(pending.getByText('Corrected note', { exact: true })).toBeVisible();
    await pending.getByRole('button', { name: 'Подтвердить партию' }).click();
    await expect(pending).toHaveCount(0);

    await page.reload();
    await expect(row).toContainText('Подтверждена');
    await row.getByText('Открыть состав', { exact: true }).click();
    const barcodes = row.getByRole('link', { name: /Скачать штрихкод/ });
    await expect(barcodes).toHaveCount(2);
    const download = page.waitForEvent('download');
    await barcodes.first().click();
    expect((await download).suggestedFilename()).toMatch(/^box-\d+\.svg$/);
  } finally {
    await context.close();
  }
});
