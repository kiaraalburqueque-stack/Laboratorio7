const { test, expect } = require('@playwright/test');

async function login(page, username) {
  await page.locator('.demo-accounts summary').click();
  await page.locator(`[data-demo="${username}"]`).click();
  await page.locator('#login-button').click();
  await expect(page.locator('#account-name')).toHaveText(username);
  await expect(page.locator('#authenticated-session')).toBeVisible();
}

async function access(page, path, status) {
  await page.locator(`[data-path="${path}"]`).click();
  await expect(page.locator('#response-preview .response-status')).toHaveText(`HTTP ${status}`);
  await expect(page.locator('#history-body tr').first().locator('td').first()).toHaveText(path);
}

test('invitado puede entrar al frontend y probar acceso libre y protegido', async ({ page }) => {
  await page.goto('/');
  await expect(page).toHaveTitle(/Access Lab/);
  await expect(page.locator('#connection-label')).toHaveText('Servidor conectado');
  await access(page, '/api/free', 200);
  await expect(page.locator('#response-preview')).toContainText('Endpoint público funcionando');
  await access(page, '/client/home', 401);
  await expect(page.locator('#request-count')).toHaveText('02');
  await page.locator('#clear-history').click();
  await expect(page.locator('#empty-history')).toBeVisible();
});

test('login incorrecto muestra error y permite reintentar', async ({ page }) => {
  await page.goto('/');
  await page.locator('#username').fill('user');
  await page.locator('#password').fill('incorrecta');
  await page.locator('#login-button').click();
  await expect(page.locator('#login-error')).toContainText('Usuario o contraseña incorrectos');
  await expect(page.locator('#guest-session')).toBeVisible();
  await login(page, 'user');
  await expect(page.locator('#login-error')).toBeHidden();
});

for (const account of [
  { name: 'user', statuses: [200, 403, 403] },
  { name: 'admin', statuses: [200, 200, 200] },
  { name: 'manager', statuses: [403, 403, 200] }
]) {
  test(`${account.name}: permisos reales, contraseña en memoria y logout`, async ({ page }) => {
    await page.goto('/');
    await login(page, account.name);
    await expect(page.locator('#account-roles')).toContainText(account.name.toUpperCase());
    for (const [index, path] of ['/client/home', '/management/dashboard', '/manager/reportes'].entries()) {
      await access(page, path, account.statuses[index]);
    }
    expect(await page.evaluate(() => ({ local: localStorage.length, session: sessionStorage.length })))
      .toEqual({ local: 0, session: 0 });
    await page.locator('#logout-button').click();
    await expect(page.locator('#guest-session')).toBeVisible();
    await expect(page.locator('#password')).toHaveValue('');
    await access(page, '/manager/reportes', 401);
  });
}

test('recargar elimina la sesión y el frontend se adapta al móvil', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto('/');
  await login(page, 'admin');
  await page.reload();
  await expect(page.locator('#guest-session')).toBeVisible();
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
  await access(page, '/api/free', 200);
});
