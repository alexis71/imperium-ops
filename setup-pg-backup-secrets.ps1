<#
  setup-pg-backup-secrets.ps1 · N°86 (2026-06-01)
  Cifra los passwords de Postgres del backup con DPAPI scope LocalMachine
  → _ops/pg-backup-secrets.dpapi (gitignored).

  Scope LocalMachine (NO CurrentUser) porque la tarea Imperium-BackupDaily corre
  como SYSTEM: LocalMachine permite que SYSTEM (y Administrator) descifren. Quita
  el password en PLANO del script git-trackeado (objetivo real).

  Uso:
    .\setup-pg-backup-secrets.ps1            # bootstrap: lee los planos del backup-daily.ps1 actual
    .\setup-pg-backup-secrets.ps1 -Prompt    # re-cifrar pidiendo valores (cuando ya no hay plano)

  Rollback: borrar pg-backup-secrets.dpapi y restaurar backup-daily.ps1.bak-n86.
  Nota: el plano YA estuvo en git history → considerar ROTAR los passwords PG (fix completo).
#>
param([switch]$Prompt)
Add-Type -AssemblyName System.Security
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$out = Join-Path $dir 'pg-backup-secrets.dpapi'

if ($Prompt) {
  $a = Read-Host 'Password ia_admin_db' -AsSecureString
  $h = Read-Host 'Password ia_hub_db'   -AsSecureString
  $adminPw = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($a))
  $hubPw   = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($h))
} else {
  $src  = Get-Content (Join-Path $dir 'backup-daily.ps1') -Raw
  $vals = [regex]::Matches($src,'\$env:PGPASSWORD = "([0-9a-f]+)"') | ForEach-Object { $_.Groups[1].Value }
  if ($vals.Count -ne 2) { Write-Error "Esperaba 2 PGPASSWORD en backup-daily.ps1, encontré $($vals.Count). Usá -Prompt."; exit 1 }
  $adminPw = $vals[0]; $hubPw = $vals[1]
}

$plain  = "ia_admin_db=$adminPw`nia_hub_db=$hubPw"
$bytes  = [System.Text.Encoding]::UTF8.GetBytes($plain)
$cipher = [System.Security.Cryptography.ProtectedData]::Protect($bytes,$null,[System.Security.Cryptography.DataProtectionScope]::LocalMachine)
[System.IO.File]::WriteAllBytes($out,$cipher)

# Verificación round-trip SIN imprimir secretos
$rt = [System.Text.Encoding]::UTF8.GetString([System.Security.Cryptography.ProtectedData]::Unprotect([System.IO.File]::ReadAllBytes($out),$null,[System.Security.Cryptography.DataProtectionScope]::LocalMachine))
$map = @{}; ($rt -split "`r?`n") | ForEach-Object { if ($_ -match '^([^=]+)=(.*)$') { $map[$Matches[1]] = $Matches[2] } }
Write-Output "Cifrado OK -> $out ($($cipher.Length) bytes)"
Write-Output "Claves: $($map.Keys -join ', ') | admin_len=$($map['ia_admin_db'].Length) hub_len=$($map['ia_hub_db'].Length)"
Write-Output ("Round-trip match: admin=" + ($map['ia_admin_db'] -eq $adminPw) + " hub=" + ($map['ia_hub_db'] -eq $hubPw))
