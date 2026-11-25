import { randomUUID } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { expect, test, type Page } from '@playwright/test';

// Run against a disposable database with a seeded admin and country NO.
const adminEmail = process.env.SLICE3_TEST_ADMIN_EMAIL;
const adminPassword = process.env.SLICE3_TEST_ADMIN_PASSWORD;
test.skip(!adminEmail || !adminPassword, 'Requires a test backend and test admin credentials');

async function signIn(page: Page, email: string, password: string) {
  await page.goto('/login');
  await page.getByLabel('Email').fill(email);
  await page.getByLabel('Пароль').fill(password);
  await page.getByRole('button', { name: 'Войти', exact: true }).click();
  await expect(page).toHaveURL(/\/workspace$/);
}

const template = fileURLToPath(new URL('../../../contract.pdf', import.meta.url));

async function reviewContract(page: Page, review: Page, name: string, finalRejection: boolean) {
  const download = page.waitForEvent('download');
  await page.getByRole('link', { name: 'Скачать шаблон договора (PDF)' }).click();
  expect((await download).suggestedFilename()).toBe('contract.pdf');

  async function uploadScan(file: string | { name: string; mimeType: string; buffer: Buffer } = template) {
    await page.getByLabel('Подписанный скан').setInputFiles(file);
    await page.getByRole('button', { name: 'Отправить скан' }).click();
    await expect(page.getByText('Договор на проверке', { exact: true })).toBeVisible();
  }

  await uploadScan();
  await review.reload();
  const row = review.getByRole('row').filter({ hasText: name });
  const scan = review.waitForEvent('download');
  await row.getByRole('link', { name: 'Скачать скан' }).click();
  expect((await scan).suggestedFilename()).toMatch(/\.pdf$/);
  const reason = 'Нужна подпись на последней странице';
  const reject = row.getByRole('button', { name: 'Отклонить скан' });
  await expect(reject).toBeDisabled();
  await row.getByLabel('Причина отклонения скана').fill(reason);
  await reject.click();
  await expect(row).toHaveCount(0);

  await page.reload();
  await expect(page.getByText('Договор отклонён', { exact: true })).toBeVisible();
  await expect(page.getByText(reason, { exact: true })).toBeVisible();
  await expect(page.getByLabel('Подписанный скан')).toHaveCount(0);

  const queue = review.getByLabel('Статус договора');
  await queue.selectOption('CONTRACT_REJECTED');
  await expect(row.getByText(reason, { exact: true })).toBeVisible();
  if (finalRejection) {
    const finalReason = 'Заявку закрыли после проверки документов';
    await row.getByLabel('Причина окончательного отказа').fill(finalReason);
    await row.getByRole('button', { name: 'Отклонить заявку окончательно' }).click();
    await expect(row).toHaveCount(0);
    await page.reload();
    await expect(page.getByText('Заявка отклонена', { exact: true })).toBeVisible();
    await expect(page.getByText(finalReason, { exact: true })).toBeVisible();
    return;
  }

  await row.getByRole('button', { name: 'Вернуть на подписание' }).click();
  await expect(row).toHaveCount(0);
  await page.getByRole('button', { name: 'Обновить статус' }).click();
  await expect(page.getByText(reason, { exact: true })).toHaveCount(0);
  const pdf = await readFile(template);
  // Insert whitespace after the cross-reference table so its offsets stay valid.
  const marker = pdf.lastIndexOf('startxref');
  expect(marker).toBeGreaterThan(0);
  await uploadScan({
    name: 'signed.pdf',
    mimeType: 'application/pdf',
    buffer: Buffer.concat([pdf.subarray(0, marker), Buffer.alloc(15 * 1024 * 1024 - pdf.length, 32), pdf.subarray(marker)]),
  });
  await queue.selectOption('VERIFICATION');
  await row.getByRole('button', { name: 'Подтвердить договор' }).click();
  await expect(row).toHaveCount(0);
  await page.reload();
  await expect(page.getByText('Депозитор активен', { exact: true })).toBeVisible();
}

for (const decision of ['approve', 'reject', 'return and verify contract', 'reject contract permanently'] as const) {
  test(`application decision persists after reload: ${decision}`, async ({ browser, page, baseURL }) => {
    const id = randomUUID();
    const name = 'Test Seed Bank ' + id;
    const email = id + '@example.org';
    const password = randomUUID();
    const reason = 'Требуется уточнить регистрационный номер';

    await page.goto('/register');
    await page.getByLabel('Название организации').fill(name);
    await page.getByLabel('Страна').selectOption('NO');
    await page.getByLabel('Регистрационный номер').fill(id);
    await page.getByLabel('Юридический адрес').fill('Test address');
    await page.getByLabel('Контактное лицо').fill('Test contact');
    await page.getByLabel('Email').fill(email);
    await page.getByLabel('Пароль').fill(password);
    await page.getByRole('button', { name: 'Отправить заявку' }).click();
    await expect(page.getByText('Заявка отправлена.', { exact: true })).toBeVisible();
    await signIn(page, email, password);
    await expect(page.getByText('На рассмотрении', { exact: true })).toBeVisible();

    const admin = await browser.newContext({ baseURL });
    try {
      const review = await admin.newPage();
      await signIn(review, adminEmail!, adminPassword!);
      await review.getByRole('link', { name: 'Администрирование' }).click();
      const row = review.getByRole('row').filter({ hasText: name });
      if (decision !== 'reject') {
        await row.getByRole('button', { name: 'Одобрить' }).click();
      } else {
        const reject = row.getByRole('button', { name: 'Отклонить' });
        await expect(reject).toBeDisabled();
        await row.getByLabel('Причина отказа').fill(reason);
        await reject.click();
      }
      await expect(row).toHaveCount(0);
      await review.reload();
      await expect(review.getByRole('heading', { name: 'Заявки депозиторов' })).toBeVisible();
      await expect(review.getByRole('table', { name: 'Заявки на рассмотрении' }).or(review.getByText('Новых заявок нет.'))).toBeVisible();
      await expect(row).toHaveCount(0);
      await page.reload();
      const status = decision !== 'reject' ? 'Одобрена. Ожидается подписание договора' : 'Заявка отклонена';
      await expect(page.getByText(status, { exact: true })).toBeVisible();
      await page.getByRole('button', { name: 'Сменить язык' }).click();
      const englishStatus = decision !== 'reject' ? 'Approved. Awaiting contract signature' : 'Application rejected';
      await expect(page.getByText(englishStatus, { exact: true })).toBeVisible();
      await page.getByRole('button', { name: 'Change language' }).click();
      if (decision === 'return and verify contract' || decision === 'reject contract permanently') {
        await reviewContract(page, review, name, decision === 'reject contract permanently');
      }
      if (decision === 'reject') {
        await expect(page.getByText(reason, { exact: true })).toBeVisible();
        await page.getByRole('button', { name: 'Выйти' }).click();
        await expect(page.getByRole('heading', { name: 'Нужен вход' })).toBeVisible();
        await page.goto('/login');
        await page.getByLabel('Email').fill(email);
        await page.getByLabel('Пароль').fill(password);
        await page.getByRole('button', { name: 'Войти', exact: true }).click();
        await expect(page.getByRole('main').getByRole('alert')).toHaveText('Неверный email или пароль');
      }
    } finally {
      await admin.close();
    }
  });
}
