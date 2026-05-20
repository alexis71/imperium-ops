# Restaura Windows Time Service para evitar drift que rompe TOTP MFA.
# Configura StartupType Automatic + force resync inicial.
#
# Uso (desde PowerShell elevada):
#   powershell -ExecutionPolicy Bypass -File C:\Users\Administrator\Desktop\_ops\fix-windows-time.ps1

Write-Output "=== Configurando Windows Time Service (w32time) ==="
Write-Output ""

# Asegurar que arranca automáticamente al boot
Set-Service w32time -StartupType Automatic -ErrorAction Stop
Write-Output "✓ StartupType: Automatic"

# Iniciar si está detenido
$svc = Get-Service w32time
if ($svc.Status -ne 'Running') {
    Start-Service w32time
    Start-Sleep -Seconds 2
    Write-Output "✓ Service started"
} else {
    Write-Output "✓ Service already running"
}

# Force resync
Write-Output ""
Write-Output "=== Force resync ==="
w32tm /resync /force

# Verify
Write-Output ""
Write-Output "=== Status post-sync ==="
w32tm /query /status

# Compare against external source
Write-Output ""
Write-Output "=== Drift check vs Google ==="
try {
    $utc = (Get-Date).ToUniversalTime()
    $resp = Invoke-WebRequest -Uri 'https://www.google.com' -Method Head -UseBasicParsing -TimeoutSec 8
    $real = [DateTime]::Parse($resp.Headers.Date).ToUniversalTime()
    $diff = ($utc - $real).TotalSeconds
    Write-Output "Server UTC: $($utc.ToString('yyyy-MM-ddTHH:mm:ss'))Z"
    Write-Output "Google UTC: $($real.ToString('yyyy-MM-ddTHH:mm:ss'))Z"
    Write-Output "Drift:      $([Math]::Round($diff, 2))s"
    if ([Math]::Abs($diff) -lt 30) {
        Write-Output "✅ Reloj OK · MFA TOTP funcionará"
    } else {
        Write-Output "🚨 Drift > 30s · esperar a próxima sync (cada 64s) o aumentar MFA_WINDOW"
    }
} catch {
    Write-Output "⚠️  No se pudo comparar contra Google: $($_.Exception.Message)"
}
