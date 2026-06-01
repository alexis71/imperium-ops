# Restore real probado · 2026-05-30 (Bloque 1 · ítem E)

Prueba de que los backups del 2026-05-30 03:00 son **restaurables** (no solo que existen).
Ninguna prueba tocó las DBs vivas (SQLite → copia a temp; Postgres → DB scratch creada y dropeada).

## SQLite (`restore-verify.js` → copia a %TEMP% + PRAGMA integrity_check + conteos)

| Backup | Proyecto | integrity_check | Tablas | Filas | Muestra |
|---|---|---|---|---|---|
| `kompaws_dev.db` | Kompaws (vertical piloto) | ok | 36 | 3804 | Tenant=5 · Payment=3 · AuditLog=997 |
| `sceptra_dev.db` | RoundTable | ok | 24 | 1972 | Tenant=6 · License=5 |
| `hr_dev.db` | Imperium HR (core) | ok | 13 | 1057 | Tenant=6 · User=4 |

## Postgres (PG16 · localhost:5432 · NO se tocó el 5433 de Obsidia)

| Dump | Método | Resultado |
|---|---|---|
| `ia_hub_db.dump` | createdb `imperium_restore_test` → `pg_restore` → conteo → dropdb | RESTORE REAL ok · 17 tablas restauradas · scratch eliminada |

## Veredicto
✅ Backups restaurables y verificados (SQLite + Postgres). El backup diario 03:00 produce artefactos válidos.
Comando reutilizable SQLite: `node _ops/restore-verify.js <backupDb> <projectServerDir>`
