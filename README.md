# `_ops/` · Operaciones del servidor Imperium

Documentación y scripts de mantenimiento del server. Sesión N°13 · 2026-04-25.

---

## 📋 Índice

1. [Backup diario](#1--backup-diario-postgres--sqlite--archive)
2. [PM2 auto-boot](#2--pm2-auto-boot)
3. [GitHub credentials](#3--github-credentials)
4. [Recuperación · descifrar PASSWORD_FIELD_KEYS](#4--recuperación--descifrar-password_field_keys)
5. [Comandos de rutina](#5--comandos-de-rutina)

---

## 1 · Backup diario · Postgres + SQLite + `_archive/`

**Script**: `_ops/backup-daily.ps1`
**Schedule**: Windows Scheduled Task `Imperium-BackupDaily` · todos los días 3:00 AM
**Output**: `_backups/YYYY-MM-DD/`
**Retención**: 7 días (folders más viejos se borran automáticamente)
**Log**: `_ops/backup.log`

### ¿Qué backupea?
| Tipo | Origen | Destino en backup |
|---|---|---|
| Postgres dump | `ia_admin_db` | `_backups/<fecha>/postgres/ia_admin_db.dump` |
| Postgres dump | `ia_hub_db` | `_backups/<fecha>/postgres/ia_hub_db.dump` |
| SQLite copy | `Kompaws/server/prisma/dev.db` | `_backups/<fecha>/sqlite/kompaws_dev.db` |
| SQLite copy | `RoundTable_v1/server/prisma/dev.db` | `_backups/<fecha>/sqlite/sceptra_dev.db` |
| SQLite copy | `netknight/server/prisma/dev.db` | `_backups/<fecha>/sqlite/almena_dev.db` |
| Zip | `_archive/` (todo) | `_backups/<fecha>/_archive_snapshot.zip` |

Tamaño típico: ~1.8 MB por día. 7 días = ~12 MB en disco.

### Correr manual
```bash
powershell -ExecutionPolicy Bypass -File C:\Users\Administrator\Desktop\_ops\backup-daily.ps1
```

### Verificar próxima ejecución
```powershell
Get-ScheduledTaskInfo -TaskName "Imperium-BackupDaily" | Select-Object NextRunTime, LastRunTime, LastTaskResult
```

### Restore de un Postgres dump
```bash
# Ejemplo: restaurar ia_admin_db a una DB temporal
$env:PGPASSWORD = "dd3e272a536b7b87cfda730aea540e5f"
& "C:\Program Files\PostgreSQL\16\bin\pg_restore.exe" `
  -U ia_admin_user -h localhost -p 5432 `
  -d ia_admin_db_restored --clean --if-exists `
  "C:\Users\Administrator\Desktop\_backups\2026-04-25\postgres\ia_admin_db.dump"
```

### Restore de un SQLite
Solo copia: `Copy-Item _backups/<fecha>/sqlite/<archivo>.db -Destination <ubicacion-original>`. **Antes**: `pm2 stop <vertical>-backend` para evitar lock.

---

## 2 · PM2 auto-boot

**Estado actual**: `pm2-windows-startup` instalado · registry entry `HKCU:\...\Run\PM2` configurado.

**Cómo funciona**: cuando el user `Administrator` se loguea (interactive o RDP), Windows ejecuta `pm2 resurrect` que restaura los procesos guardados en `dump.pm2`.

### ⚠️ Limitación actual
Si el server **reinicia y nadie se loguea**, PM2 NO arranca. Hay que loguearse al menos una vez post-reboot.

### Mitigaciones disponibles (no aplicadas aún · decidir cuándo haya cliente real)

**Opción A · AutoAdminLogon** (rápido · 5min)
Activar login automático del user `Administrator` al boot.
```powershell
# Usar Sysinternals AutoLogon (descargar de https://learn.microsoft.com/sysinternals/downloads/autologon)
# Más seguro que editar registry directamente porque cifra password en LSA
.\Autologon.exe
```
Riesgo: si alguien tiene acceso físico al server, entra como Administrator. Aceptable solo en datacenter.

**Opción B · jessety/pm2-installer** (robusto · 30min)
Crea un Windows Service real "PM2" que arranca pre-login.
```bash
git clone https://github.com/jessety/pm2-installer "C:\Users\Administrator\pm2-installer"
cd C:\Users\Administrator\pm2-installer
npm run configure-policy
npm run setup
npm run install
```
Funciona sin login activo. Recomendado para producción.

### Guardar nuevos procesos en el dump
```bash
pm2 save
```
Hacer esto SIEMPRE después de agregar/quitar procesos para que pm2-startup los restaure correctamente al boot.

---

## 3 · GitHub credentials

**Configurado**: Windows Credential Manager (sesión N°13 · 2026-04-25).
**Helper**: `manager` (`git config --global credential.helper`)
**User**: `alexis71`
**Password**: PAT activo guardado en Credential Manager (no en disco plano)

### Para ver/borrar credentials
```powershell
cmdkey /list  # listar credentials guardados
cmdkey /delete:git:https://github.com  # borrar el de github
```

### Cuando rotás el PAT (cada 90 días)
```bash
PAT="ghp_..."  # nuevo PAT generado
printf "protocol=https\nhost=github.com\nusername=alexis71\npassword=%s\n\n" "$PAT" | git credential approve
```

### Si Credential Manager pierde el credential
Cualquier `git push` va a abrir popup pidiendo username + password. User: `alexis71` · Password: PAT actual.

---

## 4 · Recuperación · descifrar PASSWORD_FIELD_KEYS

Backup cifrado en `_archive/PASSWORD_FIELD_KEYS_2026-04-25.enc` (AES-256-CBC + PBKDF2).

Ver instrucciones completas en `_archive/README_DECRYPT_KEYS.md`.

```bash
openssl enc -d -aes-256-cbc -pbkdf2 -iter 100000 \
  -in _archive/PASSWORD_FIELD_KEYS_2026-04-25.enc \
  -out PASSWORD_FIELD_KEYS.txt \
  -pass pass:'<TU_PASSWORD>'
```

Password en password manager · entry: `Imperium · PASSWORD_FIELD_KEYS · 2026-04-25`.

---

## 5 · Comandos de rutina

### Backup ahora (no esperar 3am)
```bash
powershell -ExecutionPolicy Bypass -File C:\Users\Administrator\Desktop\_ops\backup-daily.ps1
```

### Ver tamaño de backups acumulados
```powershell
Get-ChildItem C:\Users\Administrator\Desktop\_backups\ -Recurse | Measure-Object Length -Sum | Select-Object @{N='MB';E={[math]::Round($_.Sum / 1MB, 2)}}
```

### Ver log de backups
```bash
tail -50 C:\Users\Administrator\Desktop\_ops\backup.log
```

### Ver scheduled task
```powershell
Get-ScheduledTask -TaskName "Imperium-BackupDaily" | Get-ScheduledTaskInfo
```

### Restaurar PM2 procesos (post reboot)
```bash
pm2 resurrect
pm2 list
```

### Push a GitHub (sin embedded token · usa Credential Manager)
```bash
git push origin master
```

---

## Histórico de cambios

| Fecha | Sesión | Cambio |
|---|---|---|
| 2026-04-25 | N°13 | Initial setup · backup script + schedule + PM2 startup + Credential Manager + README |
