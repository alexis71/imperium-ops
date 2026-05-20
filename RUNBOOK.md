# Imperium · Runbook de Troubleshooting

> **Single source of truth** · síntomas conocidos · scripts fix · checklists por escenario.
> Actualizado: 2026-05-13 · sesión N°27+
>
> **Filosofía:** todo problema documentado aquí debe tener (1) síntoma observable · (2) causa raíz · (3) script fix ejecutable · (4) verificación.

---

## 🚨 Tabla rápida · Síntoma → Fix

| Síntoma | Causa raíz | Fix script · ubicación |
|---|---|---|
| `dueno@demo.local` no entra a Kompaws | Email no existe · usar `dueno@kompaws.demo` o `demo1@local.com` por convención | Ver § Convenciones de email |
| `mvz@kompaws.demo` rechaza Demo12345! | Password fue cambiado externamente · seed no resetea existentes | `Kompaws/server/scripts/reset-demo-passwords.js` |
| Kompaws · panorama 8 patients vs overview 0 | Registros con `branchId: null` huérfanos | `Kompaws/server/scripts/migrate-orphans-to-branch.js` |
| "Too many requests" en dev tras pocos requests | Rate limit cap 200-300/15min | Set env `RATE_LIMIT_DISABLED=true` o `NODE_ENV !== 'production'` |
| Backend EADDRINUSE :3001/3003/3006/3010/3020 | Proceso zombie · pm2 no logró matarlo | `_ops/kill-port.sh PORT` |
| Imperium Admin · "credenciales inválidas" pero password correcto | `forcePasswordChange: true` o `mfaEnabled: false` con bypass roto | `Imperium_Analytics_Admin/server/scripts/reset-admin-password.js` |
| Imperium Admin · MFA TOTP rechaza códigos válidos | Server clock drift · w32time stopped | `_ops/fix-windows-time.ps1` |
| Imperium Admin · MFA app desincronizada · sin recovery codes | Secret quedó perdido | `Imperium_Analytics_Admin/server/scripts/reset-admin-mfa.js` |
| Hub Dashboard "Cargando tu ecosistema..." infinito | `Module[code]` faltante en Admin DB → 502 silencioso | `Imperium_Analytics_Admin/server/scripts/register-hub-module.js` |
| Empresa creada en vertical pero NO visible en Hub | Sin Customer en Admin · sin CustomerModule link | `Imperium_Analytics_Admin/server/scripts/reconcile-empresa.js` |
| Owner entra al vertical pero sidebar muestra solo Dashboard+Cuenta | Usuario sin UserRole asignado · 0 permisos | `Kompaws/server/scripts/seed-tenant-roles.js TENANT_SLUG OWNER_EMAIL` |
| SSO Hub→Kompaws funciona pero contenido "Cargando..." infinito | JWT del SSO sin claim `permissions` · middleware da 403 | Ya parchado · ver § Default integración SSO |
| Login directo OK pero SSO Hub→Vertical da pantalla en blanco | Email mismatch entre HubUser y vertical User | Ver § Convenciones de email |
| Almena super-admin password perdido | User table tiene el hash · no se puede recuperar plano | `cd NetKnight_Project_v5/netknight/server && node scripts/migrate-super-admin-from-env.js --password "NewPass!"` |
| Almena · ¿cómo creo empresa nueva? | Diseño key-based · NO se crea como en KP/Sceptra · super-admin genera key, cliente la activa | UI tab Empresas · botón "+ Generar licencia" · O CLI `tools/keygen/generate.js --tier X --company "..."` |
| Almena cliente da "Licencia inválida" al activar | Key generada con NK_SECRET diferente · O key copiada incompleta (truncada) | Re-generar key desde super-admin UI · usar **Copiar clave** del modal (evita typos) |
| Almena empresa generada no aparece en tab Empresas | El cliente debe ACTIVAR la key primero · /admin/generate-license solo crea la key · LicenseActivation se crea al activate | Esperar a que cliente ejecute "Activar licencia" en su Almena · O usar `curl /auth/activate` con la key |
| Almena gerente cliente NO entra con email/password | Almena usa **pbkdf2** custom (NO bcrypt) en LicenseActivation.gerenteHash · si se creó con bcrypt → falla | Usar `hashPw()` pbkdf2 de auth.js · ver § Almena auth gotcha |
| Almena super-admin no ve tab "Empresas" post-login | role en User table debe ser 'admin' · si se creó sin role correcto, redirect a /dashboard | `node scripts/migrate-super-admin-from-env.js` (corrige role) |
| Backup diario · `WARN · <name>_dev.db · VACUUM INTO unavailable, used file-copy fallback` | Vertical corre en modo Postgres · su `schema.prisma` declara `provider = "postgresql"` y Prisma rechaza URL `file:` · fallback a Copy-Item es **seguro y esperado** | Ver § Caso crónico #6 · solo investigar si vertical debería estar en modo SQLite |

---

## 📋 Convenciones de Default · seguir SIEMPRE al agregar vertical/empresa

### Convenciones de email (cliente)

```
Email canónico (Hub + verticales · MISMO):
  demo1@local.com
  cliente.real@empresa.com.mx

NO usar:
  ❌ dueno@demo.local      (genérico · ambiguo · no scope)
  ❌ dueno@vertical1.local (rompe SSO · email Hub ≠ email vertical)
```

**Regla:** el email del HubUser debe coincidir EXACTAMENTE con el email del User en cada vertical · porque el SSO consume busca al User por email dentro del tenant.

### Convenciones de provisión empresa (orden obligatorio)

```
1. Admin ── crear Customer (legalName + contactEmail canónico)
2. Vertical ── crear Tenant (slug derivado de empresa · ej. cliente1-vet)
3. Vertical ── crear User owner con email canónico
4. Vertical ── seedear Roles (Dueño/Gerente/Colaborador) y asignar Dueño al owner
5. Admin ── reconcile-empresa.js para vincular CustomerModule + License
6. Hub ── provision-hub-user.js con customerIdInAdmin
```

Si saltás pasos 4 o 5 → "permisos insuficientes" o Hub vacío.

### Convenciones rate limit (dev)

```javascript
// En cada server/src/index.js
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: process.env.NODE_ENV === 'production' ? 300 : 2000,
  skip: () => process.env.RATE_LIMIT_DISABLED === 'true',
});
```

### Convenciones SSO consume (cuando agregás vertical nuevo)

El JWT que emite el `/sso/consume` DEBE incluir las MISMAS claims que `/auth/login`:

```javascript
{
  userId, name, email, role,
  tenantId, branchId,
  tier, limits,
  permissions  // ← CRÍTICO · sin esto requirePermission da 403
}
```

Y la response del endpoint debe tener idéntico shape al login:

```javascript
{
  data: {
    accessToken, refreshToken,
    user: { id, email, name, role, jobTitle, tenantId, branchId, tier, limits, permissions }
  }
}
```

---

## 🛠️ Scripts fix · catálogo completo

### Imperium Admin

| Script | Cuándo usar |
|---|---|
| `server/scripts/register-hub-module.js` | Hub Dashboard atascado en "Cargando" · falta `Module[iahb]` |
| `server/scripts/seed-demo-customers.js` | Resembrar 3 customers demo · idempotente |
| `server/scripts/seed-demo-customer-modules.js` | Poblar CustomerModule + License demo |
| `server/scripts/reconcile-empresa.js` | Vincular empresa creada en verticales con Customer en Admin |
| `server/scripts/reset-admin-password.js` | Reset password super-admin si bcrypt falla |
| `server/scripts/reset-admin-mfa.js` | Regenerar MFA secret + recovery codes |

### Kompaws

| Script | Cuándo usar |
|---|---|
| `server/scripts/migrate-orphans-to-branch.js` | Registros con branchId=null · panorama vs overview difieren |
| `server/scripts/reset-demo-passwords.js` | Resetear passwords de los 4 demo users |
| `server/scripts/seed-tenant-roles.js TENANT_SLUG OWNER_EMAIL` | Sembrar roles + asignar Dueño a owner |

### Imperium Hub

| Script | Cuándo usar |
|---|---|
| `server/scripts/provision-hub-user.js --email X --name Y --customer-id UUID` | Crear HubUser para Customer existente |
| `server/scripts/relink-hubusers-customers.js` | Rebind HubUsers → Customer si IDs cambiaron |

### Operacional cross-system

| Script | Cuándo usar |
|---|---|
| `_ops/smoke-all.sh` | Smoke test integral · 5 backends · health + login + endpoints |
| `_ops/kill-port.sh PORT` | Matar proceso zombie en puerto específico |
| `_ops/fix-windows-time.ps1` | Restaurar Windows Time Service auto-sync |
| `_ops/backup-daily.ps1` | Backup diario · ya scheduled · ejecutar manual si lo necesitás |
| `_ops/sqlite-hotbackup.js` | Hot-backup de SQLite (atómico via VACUUM INTO) |
| `_ops/smoke-test.sh` | 15 checks integrales · CI mini |

---

## 📝 Checklist · Agregar nuevo vertical Imperium (Fase futura)

> Cada item evita un problema documentado. Saltar uno = bug en producción.

```
PRE-CONSTRUCCIÓN
[ ] Reservar puerto en Desktop/PORTS.md (rango 3030-3080 backend, 5181-5190 client)
[ ] Reservar moduleCode (3-letras únicas · ej. fin, hr, sal)
[ ] Validar nombre comercial vía búsqueda IMPI clases 9 + 42

GENERATOR
[ ] Ejecutar Imperium_Forge/scripts/create-imperium-vertical.js NOMBRE
[ ] Buscar+reemplazar nombre-con-guion → forma limpia (Layout/PublicLayout/Login/index.html)
[ ] cd nuevo-vertical/server && npm install && npx prisma migrate dev

CONFIGURACIÓN
[ ] .env · agregar IMPERIUM_WEBHOOK_SECRET (único · 32 hex)
[ ] .env · PASSWORD_FIELD_KEY (único · 64 hex)
[ ] .env · NODE_ENV controlable
[ ] index.js · rate limit con NODE_ENV gate (ver Convenciones)
[ ] index.js · helmet + CORS whitelist con origins del Hub

INTEGRACIÓN ADMIN
[ ] Agregar entry en seed.js de Admin · Module table
[ ] Verificar pull funciona: curl -H "X-Imperium-Admin-Key: SECRET" http://vertical/api/v1/admin/tenants

INTEGRACIÓN HUB (si aplica)
[ ] Crear server/src/routes/sso.js · IMITAR el de Kompaws (con permissions array)
[ ] CRITICAL · JWT debe incluir { userId, name, email, role, tenantId, branchId, tier, limits, permissions }
[ ] CRITICAL · response.data.user debe tener todos los campos arriba (no solo {id,email,name,role})
[ ] client/src/pages/SsoConsume.jsx · imitar pattern Kompaws
[ ] Hub server/src/utils/sso-modules.js · agregar moduleCode al map

PERMISOS (si vertical usa permission system)
[ ] server/src/permissions.catalog.js · listar permission codes
[ ] server/src/lib/permissions/config/default-roles.json · definir 3 roles default
[ ] seed.js · llamar seedPermissions + seedDefaultRoles + assignRoleToUser para demo users

POST-DEPLOY
[ ] Agregar pm2 process en ecosystem.config.js
[ ] Smoke test: bash _ops/smoke-all.sh
[ ] Reseed Admin con nuevo Module via register-hub-module.js
[ ] Provisionar 1 cliente demo end-to-end (Customer + CustomerModule + HubUser)
```

---

## 📝 Checklist · Agregar empresa Almena (flujo key-based · diferente de KP/Sceptra)

> Almena tiene auth model único: empresas se crean vía license key HMAC firmada.
> El super-admin **genera** la key · el cliente la **activa**.

```
SUPER-ADMIN (Muselecom) genera la key
[ ] Login Almena http://localhost:5173 con super-admin
[ ] Click tab "Empresas" en sidebar
[ ] Click botón "+ Generar licencia" (esquina superior derecha · ámbar)
[ ] Llenar form:
    - Razón social del cliente
    - Tier (trial · starter · pro · business · enterprise)
    - Duración (1/3/6/12 meses)
[ ] Click "Generar clave"
[ ] Click "Copiar clave" (evita typos al copiar/pegar manual)
[ ] Enviar la clave al cliente vía email/WhatsApp/canal seguro

ALTERNATIVA · CLI desde terminal:
[ ] cd Desktop/NetKnight_Project_v5/netknight/tools/keygen
[ ] NK_SECRET="<secret>" node generate.js --tier pro --company "Cliente X" --months 12

CLIENTE recibe la key y activa su Almena
[ ] Cliente abre Almena en su servidor (http://servidor:5173)
[ ] Pestaña "Activar licencia"
[ ] Llenar:
    - Nombre del Gerente TI
    - Pegar la clave (NK-XXXX-...)
    - Crear contraseña (mín 6 caracteres)
[ ] Aceptar términos LFPDPPP
[ ] Click "Activar licencia"
[ ] Cliente entra como rol "gerente" · puede crear sucursales · devices · personal · staff users

VERIFICAR (super-admin)
[ ] Refrescar tab Empresas en Almena
[ ] La nueva empresa aparece en la lista con tier · email gerente · daysRemaining
[ ] Click empresa para ver detalle + acciones (suspender · cambiar tier · extender)
```

⚠️ **IMPORTANTE:** Almena NO se crea desde Imperium Hub directamente como Kompaws/Sceptra. El cliente Almena debe entrar a SU Almena local (modo cliente · puerto 5173 desde su VPN ZeroTier o servidor) y activar la key ahí. El Hub solo muestra el card después de que el cliente activó.

Si querés vincular esa empresa Almena al Customer Imperium (para que aparezca también en Hub):

```
[ ] Después de activar (cliente ya está dentro de Almena):
[ ] cd Desktop/Imperium_Analytics_Admin/server
[ ] node scripts/reconcile-empresa.js \
    --name "Cliente X" --email gerente@cliente.com \
    --slug clientex --tier knight --price 999
[ ] Provisionar HubUser:
[ ] cd Desktop/Imperium_Analytics_Hub/server
[ ] node scripts/provision-hub-user.js --email gerente@cliente.com --name "Owner X" --customer-id UUID
```

---

## 📝 Checklist · Agregar nueva empresa cliente (KP/Sceptra · flujo directo)

```
[ ] Definir email canónico (mismo en Admin + Hub + cada vertical · ej. cliente@empresa.com)
[ ] Decidir verticales contratados (kp · rt · nk · futuros)
[ ] Decidir tier por vertical (trial/scribe/herald/steward/regent o equivalentes)

ADMIN
[ ] Login Admin :5175 · Tab Empresas · Nueva empresa
   ó: cd Imperium_Analytics_Admin/server && node scripts/seed-customer-manual.js EMAIL "Razón Social"

VERTICALES (uno por uno)
[ ] Login super-admin del vertical · Tab Empresas · Nueva
[ ] Crear Tenant (slug derivado: cliente1-vet, cliente1-proj, etc.)
[ ] Crear User owner con email canónico + password
[ ] Sembrar Roles del tenant: node scripts/seed-tenant-roles.js TENANT_SLUG OWNER_EMAIL
[ ] Generar datos iniciales si demo (pacientes/proyectos/devices)

VINCULAR
[ ] cd Imperium_Analytics_Admin/server
[ ] node scripts/reconcile-empresa.js --name "Razón" --email cliente@empresa.com --slug clienteX --tier herald --price 449
[ ] Repetir reconcile con cada slug (un slug por vertical contratado)

HUB
[ ] cd Imperium_Analytics_Hub/server
[ ] node scripts/provision-hub-user.js --email cliente@empresa.com --name "Owner X" --customer-id UUID --password Demo12345!

VERIFICAR
[ ] Login Hub con cliente@empresa.com → Dashboard muestra N cards (1 por vertical)
[ ] Click "Acceder" en cada card → SSO entra · sidebar completo · contenido carga
[ ] Login directo a cada vertical con mismo email → entra OK · sidebar completo
```

---

## 🚨 Casos crónicos · sin solución definitiva en código (workarounds)

### Almena auth gotcha · pbkdf2 NO bcrypt

**Símtoma:** crear LicenseActivation programáticamente con `gerenteHash: bcrypt.hash(pwd)` → login devuelve "Credenciales inválidas".

**Causa:** Almena usa función custom pbkdf2:
```javascript
const hashPw = pw => {
  const s = crypto.randomBytes(16).toString('hex');
  return s + ':' + crypto.pbkdf2Sync(pw, s, 1e5, 64, 'sha512').toString('hex');
};
```

Formato: `salt:hash` (NO `$2a$10$...` de bcrypt).

**Fix programático:**
```javascript
// Al crear LicenseActivation
const crypto = require('crypto');
const hashPw = pw => {
  const s = crypto.randomBytes(16).toString('hex');
  return s + ':' + crypto.pbkdf2Sync(pw, s, 1e5, 64, 'sha512').toString('hex');
};
await prisma.licenseActivation.create({
  data: {
    // ... otros campos
    gerenteHash: hashPw('PasswordPlano'),  // ✅ pbkdf2 format
    // gerenteHash: await bcrypt.hash(pwd, 10),  // ❌ NO funcionará
  },
});
```

**Login client-side:** el field se llama `username` no `email` · acepta el email del gerente:
```javascript
POST /api/v1/auth/login
{ "username": "demo1@local.com", "password": "Demo12345!" }
```

En el frontend Login form: usar pestaña "Usuario y contraseña" · NO la pestaña "Admin" (esa es para Muselecom · password .env).

---

### 1. ~~Almena auth bifurcado~~ ✅ RESUELTO Fase 3 (2026-04-27)

**Estado:** unified · super-admin migrado a User table · `/login` acepta email+password universal · `/admin-login` removido · LicenseActivation/StaffUser intactos para offline. Ver `scripts/migrate-super-admin-from-env.js` para reset.

### 2. Windows Time Service detenida tras reboot raro

**Por qué pasa:** Servicio puede caer si hay update de Windows o cambio de timezone.

**Workaround:** ejecutar `bash _ops/fix-windows-time.ps1` (configura StartupType Automatic + resync).

### 3. Pm2 zombie en :PORT post-crash

**Por qué pasa:** Node node-windows ocasional · señales SIGTERM no llegan.

**Workaround:** `bash _ops/kill-port.sh PORT && pm2 restart NAME`.

### 4. Resend sandbox + DNS pendiente (3 TXT ClouDNS)

**Por qué no se arregla en código:** depende de propagación DNS externa.

**Workaround:** flip `EMAIL_SANDBOX=false` cuando los 3 TXT verifiquen en ClouDNS dashboard.

### 5. SQLite write lock under load

**Por qué no se arregla en SQLite:** limitación de motor.

**Workaround:** migrar a Postgres pre-prod (cierra OV-04). Mientras tanto · max ~20-50 writes concurrentes.

### 6. Backup diario · VACUUM INTO falla en verticales con dual-schema Prisma

**Síntoma:** En `_ops/backup.log` aparece `WARN · <name>_dev.db · VACUUM INTO unavailable, used file-copy fallback (...provider = "postgresql"...)` seguido inmediatamente de `OK · SQLite hot-backup <name>_dev.db`. El backup está completo, no es un fallo.

**Por qué pasa:** El script `_ops/sqlite-hotbackup.js` carga `@prisma/client` desde el projectDir del vertical y le pide `VACUUM INTO 'destino.db'` con datasource override `file:dev.db`. Cuando el vertical está en modo Postgres (caso de NetKnight desde 2026-05-04 · `select-db-provider.js` apunta `schema.prisma` → `schema-postgres.prisma`), Prisma valida la URL contra el `provider` declarado y rechaza `file:` con `Error validating datasource db: the URL must start with the protocol postgresql://`.

**Por qué no se "arregla" en código:** No es un bug · es la consecuencia esperada del modelo dual-schema. El cliente Prisma se genera para UN provider; un cliente generado para postgresql físicamente no puede ejecutar contra una URL sqlite.

**Mitigación automática (ya en `backup-daily.ps1`):** cuando `node sqlite-hotbackup.js` retorna exit ≠ 0, el script cae a `Copy-Item` directo del `dev.db`. Es seguro porque cuando el vertical corre en otro provider, **nadie escribe al `dev.db`** → archivo estático → file-copy es atómico de hecho. Si flipean el vertical de vuelta a SQLite con `select-db-provider.js sqlite`, VACUUM INTO retoma la ruta primaria automáticamente sin tocar el script de backup.

**Cuándo SÍ preocuparse:**
- WARN aparece para un vertical que **debería** estar en modo SQLite (ej. Kompaws o Sceptra) → verificar `prisma/schema.prisma:11` · si dice `provider = "postgresql"` cuando esperabas `sqlite`, alguien corrió `select-db-provider.js postgres` por error · ejecutar `node select-db-provider.js sqlite` desde el server del vertical
- El log NO muestra `OK · SQLite hot-backup <name>_dev.db` después del WARN → falló también el Copy-Item · revisar permisos del path destino y que el `dev.db` source exista

**Verificación rápida:**
```powershell
# Ver provider activo de cada vertical
Select-String -Path "C:\Users\Administrator\Desktop\*\server\prisma\schema.prisma","C:\Users\Administrator\Desktop\*\netknight\server\prisma\schema.prisma" -Pattern 'provider\s*=\s*"(postgresql|sqlite)"'

# Ver los 3 SQLite del último backup
Get-ChildItem (Join-Path 'C:\Users\Administrator\Desktop\_backups' (Get-Date -Format 'yyyy-MM-dd')) -Recurse -Filter *.db | Select-Object Name, @{N='SizeKB';E={[math]::Round($_.Length/1KB,1)}}, LastWriteTime | Format-Table
```

---

## 🩺 Health check rápido · 30 segundos

```bash
# 1. PM2 procesos online (esperar 11/11)
pm2 list

# 2. Smoke test integral
bash Desktop/_ops/smoke-all.sh

# 3. Time sync
powershell -Command "w32tm /query /status | Select-String LastSuccessfulSync"

# 4. DBs accesibles
psql -U ia_admin_user -h localhost -d ia_admin_db -c "SELECT COUNT(*) FROM \"Customer\";"
```

Si los 4 pasan · sistema sano. Si alguno falla · ver tabla síntomas arriba.

---

## 🧪 E2E manual C-arch · Activar módulo desde Admin (N°66 runbook)

> **Propósito**: validar end-to-end el flujo N°60-N°62 (UI runtime activación per customer × módulo × vertical) + N°61 auto-sync post-provision. Cierra ciclo de 3 sesiones.
> **Pre-requisito**: Admin/Hub/HR/CRM/Sales corriendo (`pm2 status` debe mostrar 6+ procesos online).

### Paso 1 · Abrir Admin UI

1. Browser → `http://localhost:5175`
2. Login:
   - Email: `alejandro.rodriguez@muselecom.com`
   - Password: ver `_ops/CREDENCIALES.txt` (línea `Admin · super-admin`)
   - Si pide MFA TOTP: usar app authenticator vinculada al setup inicial

### Paso 2 · Identificar Customer candidato (Demo 2 o similar)

1. Sidebar → **Empresas** (o `/empresas`)
2. Buscar customer con **al menos un vertical activo** (KP/RT/NK/Sales) pero **NO todos los cores** (HR/CRM)
3. Recomendado: **Demo 2** (multi-imperium · ya tiene KP+RT vinculados)
4. Click en el customer → abre detalle

### Paso 3 · Activar módulo core desde ModuleMatrix

1. En el detalle del customer, scroll a **Matriz de módulos** (componente `ModuleMatrix`)
2. Esperar tabla render: filas = verticales contratados (KP, RT, NK, Sales) · columnas = cores (HR, CRM, Sales, Finance, etc.)
3. Click en celda **HR × KP** (debería mostrar "○ No activo" inicialmente)
4. Modal abre con detalle + botón verde **`+ Activar · $99/mes`** (visible por fix N°62: `isHubEdit || isAdmin`)
5. **Click Activar**
6. Observar:
   - Spinner brevemente (~5-15s)
   - Mensaje verde "HR activado en Kompaws"
   - Modal cierra automático
   - Celda ahora muestra "✓ Activo" badge verde

### Paso 4 · Verificar provision automática (N°61)

**Backend logs Admin** (terminal donde corre Admin · o `pm2 logs ia-admin-server`):
```
POST /api/v1/admin/customers/<id>/modules · autoProvision=true · moduleCode=hr
  → POST http://localhost:3030/api/v1/external/tenants (HR upsert)
  → HR tenant created/upserted: hr:kp:<customer_slug>
  → Pull-then-push staff-for-hr:
    · Pull GET http://localhost:3006/api/v1/external/staff-for-hr → 4 employees
    · Push POST http://localhost:3030/api/v1/external/sync → 4 employees synced
```

Si ves `synced: { hr: { ok: 4, failed: 0 } }` → ✅ funciona.

### Paso 5 · Verificar visibilidad en Hub (SSO)

1. Browser nuevo tab → `http://localhost:5180` (Hub)
2. Login con owner del customer (`demo2@local.com` o equivalente · ver `_ops/CREDENCIALES.txt`)
3. Sidebar debería listar **RH** ahora (no estaba pre-test)
4. Click **RH** → SSO redirige a `http://localhost:5179` (HR UI)
5. Verificar tabla Empleados muestra 4 employees sincronizados con `sourceExternalRef: kp:tenant:userId`

### Resultado esperado

- ✅ Botón Activar visible en modo admin (N°62)
- ✅ HR tenant auto-creado vía `/external/tenants` (N°60)
- ✅ Staff KP auto-sincronizado a HR (N°61)
- ✅ Hub muestra módulo RH activado · SSO funciona

### Fallas conocidas a vigilar

| Síntoma | Causa probable | Fix |
|---|---|---|
| Botón Activar no aparece | `mode` no es `admin` ni `hub-edit` · adapter no expuso `activate` | Verificar `Imperium_Analytics_Admin/client/src/services/moduleMatrixAdapter.js` tiene `activate:` method (N°60) |
| 502 al activar | HR server :3030 caído · firewall bloquea entre puertos locales | `pm2 restart ia-hr-server` · revisar firewall N°37 |
| `synced.failed > 0` | Secret KP/HR mismatch · KP env tiene diferente `KP_EXTERNAL_READ_SECRET` que Admin esperaba | Comparar `.env` KP server vs Admin `KP_EXTERNAL_READ_SECRET` (debe match) |
| Hub no muestra RH post-activación | Cache cliente · navegador no refrescó CustomerModule | Hub UI · botón **Recargar** (N°57 refresh button) |

---

## 📚 Referencias cruzadas

- Memorias activas: `feedback_admin_module_seeding` · `feedback_audit_pulido_sistematico` · `feedback_servers_separados_por_programa`
- Docs maestras: `Desktop/00-DOCS-MAESTRAS/` · arquitectura · ADRs
- Security overrides: `.claude/security-rules/OVERRIDES.md` por proyecto
- Backup status: `_backups/YYYY-MM-DD/` · retención 7d
- HANDOFF actual: `Desktop/HANDOFF.md`

---

## 🔄 Cómo extender este runbook

Cada vez que resuelvas un bug nuevo:

1. Agregar fila a tabla **Síntoma → Fix** arriba
2. Si el bug puede reaparecer (default) · crear script en el `scripts/` correspondiente
3. Documentar en sección **Convenciones de Default** si aplica a futuros verticales
4. Si es crónico sin fix definitivo · agregar a **Casos crónicos**
5. Actualizar fecha al inicio del archivo

**Regla:** un bug encontrado dos veces = entry obligatoria aquí.
