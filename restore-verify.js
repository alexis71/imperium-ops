/**
 * N°80 Bloque 1 · Test de restore REAL de un backup SQLite.
 * Copia el .db respaldado a un scratch temporal, lo abre con el Prisma client del proyecto
 * y corre PRAGMA integrity_check + conteo de tablas/filas. NO toca la DB viva.
 * Uso: node _ops/restore-verify.js <backupDbPath> <projectServerDir>
 */
const path = require('path');
const fs = require('fs');
const os = require('os');

const [, , BK, PROJ] = process.argv;
if (!BK || !PROJ) { console.error('Uso: node restore-verify.js <backupDb> <projectServerDir>'); process.exit(2); }
if (!fs.existsSync(BK)) { console.error('Backup no existe:', BK); process.exit(1); }

const scratch = path.join(os.tmpdir(), 'restore-test-' + Date.now() + '.db');
fs.copyFileSync(BK, scratch);

const resolved = require.resolve('@prisma/client', { paths: [PROJ] });
const { PrismaClient } = require(resolved);
const prisma = new PrismaClient({ datasources: { db: { url: 'file:' + scratch } } });

(async () => {
  let ok = false;
  try {
    const integ = await prisma.$queryRawUnsafe('PRAGMA integrity_check');
    const tbls = await prisma.$queryRawUnsafe("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE '_prisma%'");
    let totalRows = 0; const sample = [];
    for (const t of tbls) {
      const r = await prisma.$queryRawUnsafe(`SELECT count(*) as n FROM "${t.name}"`);
      const n = Number(r[0].n); totalRows += n;
      if (n > 0 && sample.length < 4) sample.push(`${t.name}=${n}`);
    }
    const intResult = Array.isArray(integ) ? (integ[0].integrity_check || JSON.stringify(integ[0])) : JSON.stringify(integ);
    console.log(`integrity_check: ${intResult}`);
    console.log(`tablas: ${tbls.length} · filas totales: ${totalRows} · muestra: ${sample.join(' ')}`);
    ok = intResult === 'ok' && tbls.length > 0;
  } catch (e) {
    console.error('FAIL', e.message);
  } finally {
    await prisma.$disconnect();
    try { fs.unlinkSync(scratch); } catch {}
  }
  console.log(ok ? 'RESTORE OK' : 'RESTORE FAIL');
  process.exit(ok ? 0 : 1);
})();
