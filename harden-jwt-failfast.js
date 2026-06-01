/**
 * N°80 Bloque 1 · Endurecimiento JWT — elimina el fallback inseguro compartido.
 *
 * Antes:  const JWT_SECRET = process.env.JWT_SECRET || 'dev-secret-change-me';
 * Después: fail-fast si el env no está seteado (igual que Imperium_Analytics_Admin, que ya lo hace bien).
 *
 * Los secretos reales ya son únicos+seteados por app (verificado por hash N°80); esto cierra el
 * riesgo latente de que el fallback idéntico se active silenciosamente si el .env no carga.
 *
 * Reemplazo LITERAL exacto · idempotente · si no encuentra la cadena vulnerable, reporta SKIP.
 * Uso: node _ops/harden-jwt-failfast.js
 */
const fs = require('fs');
const path = require('path');
const ROOT = 'C:/Users/Administrator/Desktop';

const ACCESS_FALLBACKS = [
  "const JWT_SECRET = process.env.JWT_SECRET || 'dev-secret-change-me';",
  "const JWT_SECRET  = process.env.JWT_SECRET  || 'dev-secret-change-me';",
  "const JWT_SECRET = process.env.JWT_SECRET || 'nk-jwt-dev-only-change-in-prod';",
];
const ACCESS_FIX =
  "const JWT_SECRET = process.env.JWT_SECRET;\nif (!JWT_SECRET) throw new Error('JWT_SECRET requerido · setéalo en server/.env (sin fallback inseguro)');";

const REFRESH_FALLBACKS = [
  "const JWT_REFRESH_SECRET = process.env.JWT_REFRESH_SECRET || 'rt-refresh-dev-change-me';",
  "const JWT_REFRESH_SECRET = process.env.JWT_REFRESH_SECRET || 'nk-ref-dev-only-change-in-prod';",
];
const REFRESH_FIX =
  "const JWT_REFRESH_SECRET = process.env.JWT_REFRESH_SECRET;\nif (!JWT_REFRESH_SECRET) throw new Error('JWT_REFRESH_SECRET requerido · setéalo en server/.env (sin fallback inseguro)');";

const TARGETS = [
  // access secret (middleware/auth.js)
  ...['Imperium_Analytics_Hub','Kompaws','Imperium_Purchasing','Imperium_Sales','RoundTable_v1','Imperium_Inventory','Imperium_Hr','Imperium_Finance','Imperium_Crm']
    .map((a) => ({ file: `${a}/server/src/middleware/auth.js`, fallbacks: ACCESS_FALLBACKS, fix: ACCESS_FIX })),
  // refresh secret (routes/auth.js)
  ...['Imperium_Crm','Imperium_Finance','Imperium_Analytics_Hub','Kompaws','Imperium_Inventory','Imperium_Hr','Imperium_Purchasing','Imperium_Sales','RoundTable_v1']
    .map((a) => ({ file: `${a}/server/src/routes/auth.js`, fallbacks: REFRESH_FALLBACKS, fix: REFRESH_FIX })),
  // NetKnight (ambos en routes/auth.js, strings propios)
  { file: 'NetKnight_Project_v5/netknight/server/src/routes/auth.js', fallbacks: ACCESS_FALLBACKS, fix: ACCESS_FIX },
  { file: 'NetKnight_Project_v5/netknight/server/src/routes/auth.js', fallbacks: REFRESH_FALLBACKS, fix: REFRESH_FIX },
  // Forge template (fuente del clon · parked, sin runtime, pero evita re-propagar el bug)
  { file: 'Imperium_Forge/packages/core/auth-core/src/backend/middleware.js', fallbacks: ACCESS_FALLBACKS, fix: ACCESS_FIX },
];

let changed = 0, skipped = 0;
for (const t of TARGETS) {
  const p = path.join(ROOT, t.file);
  if (!fs.existsSync(p)) { console.log(`MISSING ${t.file}`); skipped++; continue; }
  let src = fs.readFileSync(p, 'utf8');
  const hit = t.fallbacks.find((f) => src.includes(f));
  if (!hit) {
    const already = src.includes(t.fix.split('\n')[0]) && src.includes('throw new Error');
    console.log(`${already ? 'DONE  ' : 'SKIP  '} ${t.file}`);
    skipped++; continue;
  }
  src = src.replace(hit, t.fix);
  fs.writeFileSync(p, src);
  console.log(`FIXED ${t.file}`);
  changed++;
}
console.log(`\n${changed} fixed · ${skipped} skip/done`);
