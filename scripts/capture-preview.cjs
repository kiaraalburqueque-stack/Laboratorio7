const { chromium } = require('@playwright/test');
const fs = require('node:fs');

(async () => {
  fs.mkdirSync('docs/capturas', { recursive: true });
  const browser = await chromium.launch({
    executablePath: process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH || undefined
  });
  try {
    const page = await browser.newPage({ viewport: { width: 1440, height: 1100 } });
    await page.goto(process.env.E2E_BASE_URL || 'http://localhost:8080');
    await page.locator('#connection-label').waitFor();
    await page.evaluate(() => document.fonts.ready);
    await page.screenshot({ path: 'docs/capturas/escritorio.png', fullPage: true });
    await page.locator('.demo-accounts summary').click();
    await page.locator('[data-demo="manager"]').click();
    await page.locator('#login-button').click();
    await page.locator('#authenticated-session').waitFor();
    await page.locator('[data-path="/manager/reportes"]').click();
    await page.locator('#response-preview .response-status').filter({ hasText: 'HTTP 200' }).waitFor();
    await page.screenshot({ path: 'docs/capturas/manager.png', fullPage: true });
    await page.setViewportSize({ width: 390, height: 844 });
    await page.screenshot({ path: 'docs/capturas/movil.png', fullPage: true });
  } finally { await browser.close(); }
})().catch((error) => { console.error(error.message); process.exitCode = 1; });
