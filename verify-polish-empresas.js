const { chromium } = require('C:/nvm4w/nodejs/node_modules/@playwright/test');
const path = require('path');
const OUT = path.join(__dirname, 'verify-polish-shots');
require('fs').mkdirSync(OUT, { recursive: true });

(async () => {
  const browser = await chromium.launch({ headless: true });
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 } });
  const page = await ctx.newPage();

  await page.goto('http://localhost:5177/login', { waitUntil: 'networkidle' });
  // Super-admin global
  await page.fill('input[type="email"]', 'alejandro.rodriguez@muselecom.com');
  await page.fill('input[type="password"]', 'CambiarEnProd2026!');
  await page.click('button[type="submit"]');
  try {
    await page.waitForURL(/\//, { timeout: 8000 });
  } catch (e) {
    console.log('LOGIN URL wait fallido · screenshot login-fail');
    await page.screenshot({ path: path.join(OUT, 'login-fail.png'), fullPage: true });
  }
  await page.waitForTimeout(800);
  console.log('post-login URL=' + page.url());

  await page.goto('http://localhost:5177/empresas', { waitUntil: 'networkidle' });
  await page.waitForTimeout(1500);
  await page.screenshot({ path: path.join(OUT, 'empresas.png'), fullPage: true });

  const text = await page.evaluate(() => document.body.innerText);
  const want = [
    { p: /Empresas/, l: 'KPI Empresas' },
    { p: /Licencias activas/, l: 'KPI Licencias' },
    { p: /Usuarios activos/, l: 'KPI Usuarios' },
    { p: /Ingresos MXN/, l: 'KPI Ingresos' },
  ];
  const dontWant = /Proyectos/;
  for (const w of want) console.log((w.p.test(text) ? 'OK   ' : 'WARN ') + w.l);
  console.log(dontWant.test(text)
    ? 'FAIL "Proyectos" todavía aparece (cache?)'
    : 'OK   "Proyectos" ya NO aparece (KPI removido)');

  // Console errors check
  const errs = [];
  page.on('pageerror', e => errs.push(e.message));
  await page.reload({ waitUntil: 'networkidle' });
  await page.waitForTimeout(800);
  console.log('console errors tras reload: ' + (errs.length ? errs.join(' | ') : 'NINGUNO'));

  await browser.close();
})();
