# =============================================================
# Imperium · Backup diario
# =============================================================
# Ejecutar diariamente vía Scheduled Task (3am)
# - Postgres dump:  ia_admin_db + ia_hub_db
# - SQLite copy:    Kompaws/RoundTable_v1/netknight dev.db
# - Claude config:  ~/.claude (memory, skills, settings, credenciales)
# - Archive:        _archive/ comprimido
# - Retencion:      7 dias (delete folders mas viejos)
# - Log:            _ops/backup.log

$ErrorActionPreference = "Stop"
$timestamp = Get-Date -Format "yyyy-MM-dd"
$timeStart = Get-Date
$backupRoot = "C:\Users\Administrator\Desktop\_backups"
$logFile = "C:\Users\Administrator\Desktop\_ops\backup.log"
$backupDir = Join-Path $backupRoot $timestamp

function Log {
    param($msg)
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') · $msg"
    Add-Content -Path $logFile -Value $line
    Write-Host $line
}

function Try-Step {
    param($stepName, $block)
    try {
        & $block
        Log "  OK · $stepName"
    } catch {
        Log "  FAIL · $stepName · $($_.Exception.Message)"
    }
}

# ── Setup ───────────────────────────────────────────────────
Log "=== Backup start ($timestamp) ==="
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
New-Item -ItemType Directory -Force -Path "$backupDir\postgres" | Out-Null
New-Item -ItemType Directory -Force -Path "$backupDir\sqlite" | Out-Null

# ── Postgres dumps ──────────────────────────────────────────
$pgDump = "C:\Program Files\PostgreSQL\16\bin\pg_dump.exe"

Try-Step "ia_admin_db" {
    $env:PGPASSWORD = "dd3e272a536b7b87cfda730aea540e5f"
    & $pgDump -U ia_admin_user -h localhost -p 5432 `
        -F custom -f "$backupDir\postgres\ia_admin_db.dump" ia_admin_db
    if ($LASTEXITCODE -ne 0) { throw "pg_dump exit $LASTEXITCODE" }
}

Try-Step "ia_hub_db" {
    $env:PGPASSWORD = "dc7a273e7f97c2ff5d5fefbe0e76e5e7"
    & $pgDump -U ia_hub_user -h localhost -p 5432 `
        -F custom -f "$backupDir\postgres\ia_hub_db.dump" ia_hub_db
    if ($LASTEXITCODE -ne 0) { throw "pg_dump exit $LASTEXITCODE" }
}

Remove-Item Env:PGPASSWORD -ErrorAction SilentlyContinue

# ── SQLite hot-backups (VACUUM INTO atómico · seguro durante writes) ────────
$sqliteSources = @{
    "kompaws_dev.db" = @{
        ProjectDir = "C:\Users\Administrator\Desktop\Kompaws\server"
        DbPath     = "./prisma/dev.db"
    }
    "sceptra_dev.db" = @{
        ProjectDir = "C:\Users\Administrator\Desktop\RoundTable_v1\server"
        DbPath     = "./prisma/dev.db"
    }
    "almena_dev.db"  = @{
        ProjectDir = "C:\Users\Administrator\Desktop\NetKnight_Project_v5\netknight\server"
        DbPath     = "./prisma/dev.db"
    }
    # N°66 · cierra deuda backup C-arch · HR/CRM/Sales data NO respaldada pre-N°66 (riesgo pérdida cross-vertical sync N°41-N°62)
    "hr_dev.db" = @{
        ProjectDir = "C:\Users\Administrator\Desktop\Imperium_Hr\server"
        DbPath     = "./prisma/dev.db"
    }
    "crm_dev.db" = @{
        ProjectDir = "C:\Users\Administrator\Desktop\Imperium_Crm\server"
        DbPath     = "./prisma/dev.db"
    }
    "sales_dev.db" = @{
        ProjectDir = "C:\Users\Administrator\Desktop\Imperium_Sales\server"
        DbPath     = "./prisma/dev.db"
    }
}

$hotBackupScript = "C:\Users\Administrator\Desktop\_ops\sqlite-hotbackup.js"

foreach ($sqliteName in $sqliteSources.Keys) {
    $cfg = $sqliteSources[$sqliteName]
    $dest = "$backupDir\sqlite\$sqliteName"
    Try-Step "SQLite hot-backup $sqliteName" {
        $srcAbsolute = Join-Path $cfg.ProjectDir ($cfg.DbPath -replace '/', '\')
        if (-not (Test-Path $srcAbsolute)) {
            throw "source not found: $srcAbsolute"
        }
        # Capture node output sin que $ErrorActionPreference=Stop corte en la primera linea de stderr
        $prevEAP = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        $nodeOut  = (& node $hotBackupScript $cfg.ProjectDir $cfg.DbPath $dest 2>&1) -join " | "
        $nodeExit = $LASTEXITCODE
        $ErrorActionPreference = $prevEAP

        if ($nodeExit -eq 0) { return }
        # VACUUM INTO no disponible (caso comun: el schema.prisma activo del vertical
        # esta apuntando a postgresql, no a sqlite — ej. NetKnight en modo Postgres).
        # Fallback a file-copy: seguro porque el dev.db esta estatico cuando el vertical
        # corre en otro provider. Si flipean a sqlite, VACUUM INTO toma la ruta primaria.
        Copy-Item -Path $srcAbsolute -Destination $dest -Force
        # Log inline: la fn Log no es visible dentro de scriptblocks creados con GetNewClosure()
        $warnLine = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ·   WARN · $sqliteName · VACUUM INTO unavailable, used file-copy fallback ($nodeOut)"
        Add-Content -Path $logFile -Value $warnLine
        Write-Host $warnLine
    }.GetNewClosure()
}

# ── Claude Code config (memoria, skills, settings, credenciales) ─────────
# Excluye cruft efimero (cache/snapshots) · ~135 MB tipicos
Try-Step "claude-config" {
    $claudeSrc  = "C:\Users\Administrator\.claude"
    $claudeDest = "$backupDir\claude-config"
    $claudeLog  = "$backupDir\claude-config-robocopy.log"
    & robocopy $claudeSrc $claudeDest /MIR `
        /XD cache paste-cache shell-snapshots session-env `
        /XF '*.tmp' `
        /R:1 /W:1 /NFL /NDL /NP /LOG:$claudeLog | Out-Null
    # Robocopy: 0-7 = success (1=copied, 2=extras, 3=both, etc) · 8+ = failure
    if ($LASTEXITCODE -ge 8) { throw "robocopy exit $LASTEXITCODE (see $claudeLog)" }
}

# ── Archive _archive/ folder (snapshots historicos) ─────────
Try-Step "_archive snapshot" {
    Compress-Archive -Path "C:\Users\Administrator\Desktop\_archive\*" `
        -DestinationPath "$backupDir\_archive_snapshot.zip" -Force
}

# ── Retention: delete folders older than 7 days ─────────────
Try-Step "Retention cleanup (>7d)" {
    $cutoff = (Get-Date).AddDays(-7)
    Get-ChildItem -Path $backupRoot -Directory | Where-Object {
        $_.Name -match '^\d{4}-\d{2}-\d{2}$' -and $_.LastWriteTime -lt $cutoff
    } | ForEach-Object {
        Remove-Item -Path $_.FullName -Recurse -Force
        Log "  removed old backup: $($_.Name)"
    }
}

# ── Summary ─────────────────────────────────────────────────
$elapsed = (Get-Date) - $timeStart
$size = (Get-ChildItem $backupDir -Recurse | Measure-Object -Property Length -Sum).Sum
$sizeMB = [math]::Round($size / 1MB, 2)
Log "=== Backup done · $sizeMB MB · $($elapsed.TotalSeconds)s ==="
Log ""
