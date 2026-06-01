const { chromium } = require('C:/nvm4w/nodejs/node_modules/@playwright/test');
const path = require('path');
const OUT = path.join(__dirname, 'verify-reel-n82-shots');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 } });
  const page = await ctx.newPage();

  await page.goto('http://localhost:5177/login', { waitUntil: 'networkidle' });
  await page.fill('input[type="email"]', 'demo1@local.com');
  await page.fill('input[type="password"]', 'Demo12345!');
  await page.click('button[type="submit"]');
  await page.waitForURL(/\//);
  await page.waitForTimeout(800);

  // Cerrar banner MFA si lo logramos
  await page.goto('http://localhost:5177/agenda', { waitUntil: 'networkidle' });
  await page.waitForTimeout(1000);
  try {
    const closeBtn = await page.$('button[aria-label*="errar" i], button[title*="errar" i]');
    if (closeBtn) {
      await closeBtn.click();
      console.log('OK   banner cerrado vía botón');
    } else {
      // Probar el último botón del top bar (la X)
      const xBtn = await page.$('header button:has-text("×"), header svg.lucide-x, [class*="banner"] button');
      if (xBtn) { await xBtn.click(); console.log('OK   banner cerrado vía X'); }
    }
  } catch (e) { console.log('WARN cierre banner: '+e.message); }
  await page.waitForTimeout(600);

  // Click "siguiente semana" → buscar botón a la derecha del "Hoy"
  // Por el screenshot, junto al botón "Hoy" hay un chevron > a su derecha
  await page.locator('button:has-text("Hoy")').first().waitFor({ timeout: 5000 });
  const allButtons = await page.$$('button');
  console.log(`buttons en pagina: ${allButtons.length}`);
  // El chevron > suele ser el botón inmediatamente después del "Hoy"
  let clicked = false;
  for (const b of allButtons) {
    const aria = await b.getAttribute('aria-label');
    const text = (await b.innerText()).trim();
    if (/sig|next|>/i.test(aria || '') || text === '>' || text === '›' || text === '▶') {
      await b.click();
      console.log(`OK   click botón siguiente · aria="${aria}" text="${text}"`);
      clicked = true;
      break;
    }
  }
  if (!clicked) {
    // Fallback: click el botón después del que dice "Hoy"
    const hoyIdx = await page.evaluate(() => {
      const btns = [...document.querySelectorAll('button')];
      return btns.findIndex(b => b.innerText.trim() === 'Hoy');
    });
    if (hoyIdx >= 0) {
      await allButtons[hoyIdx + 1].click();
      console.log(`OK   click botón índice ${hoyIdx+1} (post-Hoy)`);
    }
  }
  await page.waitForTimeout(1200);
  await page.screenshot({ path: path.join(OUT, '05-agenda-semana-siguiente.png'), fullPage: true });

  const text = await page.evaluate(() => document.body.innerText);
  console.log('Pelusa en pantalla: ' + /Pelusa/i.test(text));
  console.log('Esterilización en pantalla: ' + /Esterilizaci[óo]n/i.test(text));

  await browser.close();
})();
