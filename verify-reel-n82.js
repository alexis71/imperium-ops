/**
 * verify-reel-n82.js · captura de evidencia para el demo reel N°82
 * Login real demo1@local.com en KP :5177 · pacient Rocky Bulldog + agenda
 */
const { chromium } = require('C:/nvm4w/nodejs/node_modules/@playwright/test');
const path = require('path');
const fs = require('fs');

const OUT = path.join(__dirname, 'verify-reel-n82-shots');
const ROCKY_ID = '37291991-e3b1-4805-861b-49710b0ea295';

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const browser = await chromium.launch({ headless: true });
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 } });
  const page = await ctx.newPage();

  const findings = [];
  const log = (m) => { console.log(m); findings.push(m); };

  try {
    // ── (1) LOGIN ────────────────────────────────────────────────────────
    log('STEP login → http://localhost:5177/login');
    await page.goto('http://localhost:5177/login', { waitUntil: 'networkidle', timeout: 20000 });
    await page.screenshot({ path: path.join(OUT, '01-login.png'), fullPage: true });

    await page.fill('input[type="email"], input[name="email"]', 'demo1@local.com');
    await page.fill('input[type="password"], input[name="password"]', 'Demo12345!');
    await page.click('button[type="submit"]');
    await page.waitForURL(/\/(dashboard|pacientes|inicio|$)/, { timeout: 15000 });
    log(`STEP post-login URL = ${page.url()}`);
    await page.waitForTimeout(800);
    await page.screenshot({ path: path.join(OUT, '02-dashboard.png'), fullPage: true });

    // ── (2) EXPEDIENTE ROCKY ────────────────────────────────────────────
    log(`STEP expediente Rocky → /pacientes/${ROCKY_ID}`);
    await page.goto(`http://localhost:5177/pacientes/${ROCKY_ID}`, { waitUntil: 'networkidle', timeout: 15000 });
    await page.waitForTimeout(1500); // dar tiempo a que cargue la imagen externa
    await page.screenshot({ path: path.join(OUT, '03-rocky-expediente.png'), fullPage: true });

    // Verificar el src del img (si hay un <img> apuntando a dog.ceo)
    const imgs = await page.$$eval('img', els => els.map(e => ({ src: e.src, alt: e.alt, naturalWidth: e.naturalWidth, naturalHeight: e.naturalHeight })));
    const bulldog = imgs.find(i => i.src.includes('dog.ceo'));
    if (bulldog) {
      log(`OK   <img src dog.ceo>  natural=${bulldog.naturalWidth}x${bulldog.naturalHeight}  alt='${bulldog.alt}'`);
      if (bulldog.naturalWidth === 0) log('WARN foto referenciada pero naturalWidth=0 (no cargó)');
    } else {
      log('WARN ningún <img> con src dog.ceo encontrado en /pacientes/<rocky>');
      log(`     imgs encontradas: ${imgs.length} · primeras 3: ${JSON.stringify(imgs.slice(0,3))}`);
    }

    // Buscar texto narrativo del expediente
    const bodyText = await page.evaluate(() => document.body.innerText);
    const checks = [
      { pat: /Rocky/i,                   label: 'nombre Rocky' },
      { pat: /Bulldog/i,                 label: 'raza Bulldog' },
      { pat: /Ana Mart[ií]nez/i,         label: 'owner Ana Martínez' },
      { pat: /postquir[uú]rgic/i,        label: 'SOAP "postquirúrgica"' },
    ];
    for (const c of checks) {
      log(c.pat.test(bodyText) ? `OK   match: ${c.label}` : `WARN no match: ${c.label}`);
    }

    // ── (3) AGENDA ──────────────────────────────────────────────────────
    log('STEP agenda → /agenda');
    await page.goto('http://localhost:5177/agenda', { waitUntil: 'networkidle', timeout: 15000 });
    await page.waitForTimeout(1500);
    await page.screenshot({ path: path.join(OUT, '04-agenda.png'), fullPage: true });

    const agendaText = await page.evaluate(() => document.body.innerText);
    const agendaChecks = [
      { pat: /Control postquir[uú]rgic/i, label: 'cita Rocky · "Control postquirúrgico día 14"' },
      { pat: /Seguimiento gastroenteritis/i, label: 'cita Luna · "Seguimiento gastroenteritis"' },
      { pat: /Esterilizaci[oó]n programada/i, label: 'cita Pelusa · "Esterilización programada"' },
    ];
    for (const c of agendaChecks) {
      log(c.pat.test(agendaText) ? `OK   match: ${c.label}` : `WARN no match: ${c.label}`);
    }

    // navegación por fecha si la agenda default no muestra las del 30/31
    if (!/Control postquir[uú]rgic/i.test(agendaText)) {
      log('STEP intentando avanzar fecha · busco botón "Siguiente" o input date');
      const nextBtn = await page.$('button:has-text("Siguiente"), button:has-text(">"), [aria-label*="iguiente"]');
      if (nextBtn) {
        for (let i = 0; i < 3; i++) {
          await nextBtn.click();
          await page.waitForTimeout(600);
        }
        await page.screenshot({ path: path.join(OUT, '05-agenda-avanzada.png'), fullPage: true });
        const t2 = await page.evaluate(() => document.body.innerText);
        if (/Control postquir[uú]rgic/i.test(t2)) log('OK   citas aparecen tras avanzar fecha');
        else log('WARN citas siguen sin aparecer tras avanzar 3x · revisar manualmente');
      } else {
        log('WARN no encontré botón siguiente · agenda puede usar vista semanal/mes default');
      }
    }

    log(`\nshots → ${OUT}`);
  } catch (e) {
    log(`ERR ${e.message}`);
    await page.screenshot({ path: path.join(OUT, 'crash.png'), fullPage: true });
  } finally {
    await browser.close();
  }

  fs.writeFileSync(path.join(OUT, 'log.txt'), findings.join('\n'));
})();
