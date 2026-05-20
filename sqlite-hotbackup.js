/**
 * Hot-backup de SQLite usando VACUUM INTO (atómico · seguro durante writes).
 *
 * VACUUM INTO crea un backup consistente de la DB sin necesidad de detener el server,
 * a diferencia de Copy-Item que puede capturar páginas inconsistentes si la DB
 * se está escribiendo en ese momento.
 *
 * Uso (desde el cwd del vertical · necesita Prisma/SQLite client):
 *   node sqlite-hotbackup.js <prismaProjectDir> <dbPath> <destPath>
 *
 * Ejemplo:
 *   node _ops/sqlite-hotbackup.js \
 *     C:/Users/Administrator/Desktop/Kompaws/server \
 *     ./prisma/dev.db \
 *     C:/Users/Administrator/Desktop/_backups/2026-XX-XX/sqlite/kompaws_dev.db
 *
 * El primer arg debe tener instalado @prisma/client + dev.db de SQLite.
 */
const path = require('path');
const fs = require('fs');

const [, , projectDir, dbPath, destPath] = process.argv;

if (!projectDir || !destPath) {
  console.error('Uso: node sqlite-hotbackup.js <projectDir> <dbPath> <destPath>');
  process.exit(2);
}

(async () => {
  // Resolver @prisma/client desde el projectDir (busca también en parent dirs si está en monorepo)
  const resolved = require.resolve('@prisma/client', { paths: [projectDir] });
  const PrismaClient = require(resolved).PrismaClient;
  const prisma = new PrismaClient({ datasources: { db: { url: 'file:' + path.resolve(projectDir, dbPath) } } });
  try {
    if (fs.existsSync(destPath)) fs.unlinkSync(destPath);
    const escaped = destPath.replace(/'/g, "''");
    await prisma.$executeRawUnsafe(`VACUUM INTO '${escaped}'`);
    const stat = fs.statSync(destPath);
    console.log(`OK ${path.basename(destPath)} · ${(stat.size / 1024).toFixed(1)} KB`);
    process.exit(0);
  } catch (err) {
    console.error('FAIL', err.message);
    process.exit(1);
  } finally {
    await prisma.$disconnect();
  }
})();
