# Imperium · Operaciones

> Esqueleto vivo de operación. Cuatro secciones: **Proceso**, **Producción**, **Seguridad**,
> **Errores y Fixes**. Se completa con cada sesión / incidente.
> Para troubleshooting síntoma→fix detallado, ver `_ops/RUNBOOK.md`.
> Creado: 2026-05-20 (N°67).

---

## 1. Proceso

Cómo se trabaja en Imperium.

- **Gate de smoke**: ningún cambio se da por bueno sin `bash _ops/smoke-all.sh` en verde
  (objetivo: "que no rompa"). Baseline actual: **174 passed · 0 failed**.
- **Sesiones numeradas**: cada bloque de trabajo es una sesión N°X · se cierra con memoria.
- **Commits**: uno por repo, mensaje `tipo(scope): N°X · descripción` · identidad git vía `-c`
  inline (nunca config global).
- **Decidir + reportar** sobre preguntar en batch · explicar antes de cambios que toquen 3+ archivos.

### Plantilla · entrada de proceso
```
- [Fecha] · [Práctica o decisión de proceso] · [por qué]
```

---

## 2. Producción

Estado de ejecución del ecosistema.

### Inventario de servicios (9 + framework)

| Servicio | Puerto | DB | Gestor |
|----------|--------|-----|--------|
| NetKnight/Almena | 3001 | PostgreSQL / SQLite | pm2 |
| RoundTable/Sceptra | 3003 | SQLite | pm2 |
| Kompaws | 3006 | SQLite | pm2 |
| Imperium Admin | 3010 | PostgreSQL | pm2 |
| Imperium Hub | 3020 | PostgreSQL | pm2 |
| Imperium Finance | 3030 | PostgreSQL | pm2 |
| Imperium HR | 3040 | SQLite | pm2 |
| Imperium Sales | 3050 | SQLite | pm2 |
| Imperium CRM | 3060 | SQLite | pm2 |
| Imperium Forge | — | — | framework (no runtime) |

- **pm2**: ~19 procesos (backend + client por servicio) + `smoke-cron`.
- **smoke-cron**: cron horario `0 * * * *` · interpreter Git Bash explícito (ver §4 · fix N°67).
- **Backup diario**: `_ops/backup-daily.ps1` vía Task Scheduler (`Imperium-BackupDaily`, 03:00) ·
  9 DBs (3 Postgres dump + 6 SQLite copy) · retención en `_backups/`.
- **Convive con Obsidia** (proyecto paralelo en WSL2+Docker) · NO tocar · ver memoria.

### Plantilla · cambio en producción
```
- [Fecha] · [Servicio] · [Qué cambió] · [Smoke antes/después] · [Commit]
```

---

## 3. Seguridad

Postura de seguridad y registro de hardening.

### Postura base
- **Red**: firewall bloquea acceso público/LAN · solo ZeroTier (21+ reglas `Muselecom-*`, N°37).
- **Datos en reposo**: `currentPassword` cifrado AES-256-GCM en las 6 DBs con `User`/`LicenseActivation`
  (`imperium-core` middleware · N°10 + N°67).
- **Auth**: JWT access+refresh · Admin con MFA TOTP obligatorio.
- **Webhooks**: firmados HMAC-SHA256.
- **Secretos**: `.env` gitignored · backup consolidado en `Desktop/IMPERIUM_SECRETS.txt`.
- **Repos**: 13/13 privados en GitHub · gitleaks 0 leaks (N°67).

### Política npm · cadena de suministro
- **Riesgo**: un `npm install` puede ejecutar malware vía scripts `postinstall`/`preinstall` de un
  paquete comprometido (ataques reales: event-stream, ua-parser-js, node-ipc…).
- **Reglas de operación**:
  1. Para instalar en proyectos estables: usar `npm ci` (reproducible · respeta lockfile · no jala
     versiones nuevas no auditadas).
  2. Para agregar un paquete nuevo o desconocido: `npm install <pkg> --ignore-scripts`, revisar, y
     solo después `npm rebuild` si el paquete legítimamente necesita compilar (ej. better-sqlite3).
  3. NO poner `ignore-scripts=true` global: rompe Prisma (postinstall genera el client) y módulos
     nativos.
  4. Evitar instalar paquetes recién publicados (< 24-48 h) sin revisarlos.
  5. Correr `bash _ops/npm-audit-all.sh` periódicamente (semanal) · NO en el smoke horario.
- **Baseline 2026-05-20**: 0 vulnerabilidades crítico/alto/moderado.
- **pnpm**: evaluado · su `minimumReleaseAge` + bloqueo de scripts es bueno · migración futura
  opcional, piloteada en un repo, NO reacción de pánico.

### Auditoría periódica (cada 3-6 meses)
Firewall · gitleaks · `.env` no trackeados · backup freshness · MFA · encryption · `npm-audit-all.sh`
· visibilidad repos GitHub. Ver roadmap Forge §"Ops · Security audit".

### Plantilla · entrada de hardening
```
- [Fecha · N°X] · [Qué se endureció] · [Por qué] · [Verificación]
```

---

## 4. Errores y Fixes

Registro de incidentes notables con causa raíz. El troubleshooting síntoma→fix operativo vive en
`_ops/RUNBOOK.md`; aquí se anotan los incidentes con su análisis de causa.

### Plantilla · entrada
```
### [Fecha · N°X] · [Título corto]
- Síntoma: ...
- Causa raíz: ...
- Fix: ...
- Prevención: ...
```

### 2026-05-19 · N°67 · smoke-cron caído 4 días sin alerta
- Síntoma: `pm2` mostraba `smoke-cron` stopped · cron escribía headers vacíos sin checks reales.
- Causa raíz: PM2 daemon resolvía `bash` → `C:\Windows\System32\bash.exe` (launcher WSL, instalado
  para Obsidia) en lugar de Git Bash. WSL no entiende rutas `/c/...`.
- Fix: re-registrar pm2 con interpreter explícito `C:\Program Files\Git\usr\bin\bash.exe` +
  `export PATH` MSYS al inicio del script.
- Prevención: en Windows con WSL coinstalado, scripts de servicio SIEMPRE con ruta absoluta de
  Git Bash. Ver memoria `feedback_bash_path_hijack_wsl_windows`.

### 2026-05-19 · N°66 · sync C-arch fallaba silencioso (URLs sin /api/v1)
- Síntoma: `meta.synced.error: "pull 404"` · HR/CRM de Demo 2 con headcount 0.
- Causa raíz: URLs de pull/push en Admin sin prefijo `/api/v1/` · smoke estático grepeaba el nombre
  de variable, no la URL literal.
- Fix: prefijo `/api/v1/` en `PULL_ENDPOINTS` + `TARGET_SYNC` · smoke valida URL literal.
- Prevención: URLs externas requieren smoke con string literal + E2E periódico cross-service.

### 2026-05-19 · N°67 · HR/CRM/Sales sin cifrado de currentPassword
- Síntoma: audit encontró 14 filas `currentPassword` en texto plano.
- Causa raíz: verticales scaffold post-N°54 no heredaron el middleware AES de imperium-core.
- Fix: `lib/crypto.js` + `attachCryptoMiddleware` en los 3 · re-encriptar filas existentes.
- Prevención: checklist de setup de vertical incluye el paso de cifrado (ver
  `feedback_pwd_field_encryption`).
