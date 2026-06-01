const { chromium } = require('C:/nvm4w/nodejs/node_modules/@playwright/test');
const path = require('path');
const OUT = path.join(__dirname, 'verify-polish-shots');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 } });
  const page = await ctx.newPage();

  await page.goto('http://localhost:5177/login', { waitUntil: 'networkidle' });
  await page.fill('input[type="email"]', 'alejandro.rodriguez@muselecom.com');
  await page.fill('input[type="password"]', 'CambiarEnProd2026!');
  await page.click('button[type="submit"]');
  await page.waitForURL(/\//, { timeout: 8000 });
  await page.goto('http://localhost:5177/empresas', { waitUntil: 'networkidle' });
  await page.waitForTimeout(1200);

  // Capturo tabla con plural arreglado
  await page.screenshot({ path: path.join(OUT, 'empresas-plural.png'), fullPage: true });

  // Click en primera fila Demo 1 · Multi-Imperium
  const row = await page.locator('text=Demo 1 · Multi-Imperium · Veterinaria').first();
  if (await row.count() > 0) {
    await row.click();
    await page.waitForTimeout(800);
    await page.screenshot({ path: path.join(OUT, 'detalle-tenant.png'), fullPage: true });

    // Buscar botón "Cambiar tier" o similar
    const btn = await page.locator('button:has-text("Cambiar tier"), button:has-text("Tier"), button:has-text("Cambiar")').first();
    if (await btn.count() > 0) {
      await btn.click();
      await page.waitForTimeout(800);
      await page.screenshot({ path: path.join(OUT, 'modal-tier.png'), fullPage: true });

      const text = await page.evaluate(() => document.body.innerText);
      console.log('Chihuahua visible: ' + /Chihuahua/.test(text));
      console.log('Border Collie visible: ' + /Border Collie/.test(text));
      console.log('Gran Danés visible: ' + /Gran Dan/.test(text));
      console.log('Sceptra/Scribe presente: ' + /(Scribe|Herald|Steward|Regent)/.test(text));
    } else {
      console.log('WARN no encontré botón "Cambiar tier" · revisar UX manualmente');
    }
  } else {
    console.log('WARN no encontré fila Demo 1');
  }

  await browser.close();
})();
