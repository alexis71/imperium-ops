# Imperium · Firewall Hardening · 2026-05-15
# Extiende el pattern Muselecom-Block-Public/LAN + Allow-ZeroTier a los 7 backends
# que hoy NO tienen regla explícita (3003 RT · 3006 KP · 3010 Admin · 3020 Hub · 3030 Finance · 3040 HR · 3050 Sales)
#
# Estado actual (verificado 2026-05-15):
#   Profile Public default Block · Ethernet0 (IP pública) ya protegida por default
#   Profile Private default Allow · Ethernet1 (192.168.1.x LAN) + ZeroTier expuestos
#   Reglas existentes solo cubren :3001-3002 (NK)
#
# Patrón replicado de las reglas existentes de NK:
#   Muselecom-Block-<PORT>-Public · Profile=Any · Action=Block · RemoteAddress=Internet
#   Muselecom-Block-<PORT>-LAN    · Profile=Any · Action=Block · RemoteAddress=192.168.1.0/24
#   Muselecom-Allow-<PORT>-ZeroTier · Profile=Any · Action=Allow · RemoteAddress=192.168.193.0/24,192.168.195.0/24
#
# Uso:
#   Revisa primero (dry-run): .\firewall-harden-imperium-ports.ps1 -DryRun
#   Aplica:                   .\firewall-harden-imperium-ports.ps1 -Apply
#
# Rollback:
#   Get-NetFirewallRule -DisplayName "Muselecom-*-30*" | Where { $_.DisplayName -notmatch "300[12]" } | Remove-NetFirewallRule

param(
    [switch]$DryRun = $true,
    [switch]$Apply
)

if ($Apply) { $DryRun = $false }

$ports = @(
    @{ Port = 3003; Name = "RT (Sceptra)" },
    @{ Port = 3006; Name = "KP (Kompaws)" },
    @{ Port = 3010; Name = "Admin (Imperium)" },
    @{ Port = 3020; Name = "Hub (Imperium)" },
    @{ Port = 3030; Name = "Finance (G.1)" },
    @{ Port = 3040; Name = "HR (G.3)" },
    @{ Port = 3050; Name = "Sales (G.2)" }
)

# Ranges ZeroTier reales detectados N°37 · ARRAY (PowerShell New-NetFirewallRule requiere array, no string con coma)
$zerotierRanges = @("192.168.193.0/24", "192.168.195.0/24")
# Tu LAN local (ajustar si cambia)
$lanRange = "192.168.1.0/24"

Write-Host ""
Write-Host "=== Imperium Firewall Hardening ===" -ForegroundColor Cyan
Write-Host "Mode: $(if ($DryRun) {'DRY-RUN (preview)'} else {'APPLY'})" -ForegroundColor $(if ($DryRun) {'Yellow'} else {'Green'})
Write-Host ""

foreach ($p in $ports) {
    $port = $p.Port
    $name = $p.Name

    $rules = @(
        @{ DisplayName = "Muselecom-Block-$port-Public"; Action = "Block"; Profile = "Any"; RemoteAddress = "Internet" },
        @{ DisplayName = "Muselecom-Block-$port-LAN";    Action = "Block"; Profile = "Any"; RemoteAddress = $lanRange },
        @{ DisplayName = "Muselecom-Allow-$port-ZeroTier"; Action = "Allow"; Profile = "Any"; RemoteAddress = $zerotierRanges }
    )

    Write-Host "Port $port ($name):" -ForegroundColor White

    foreach ($r in $rules) {
        $exists = Get-NetFirewallRule -DisplayName $r.DisplayName -ErrorAction SilentlyContinue
        if ($exists) {
            Write-Host "  [SKIP] $($r.DisplayName) ya existe" -ForegroundColor DarkGray
            continue
        }

        if ($DryRun) {
            $raStr = if ($r.RemoteAddress -is [array]) { ($r.RemoteAddress -join ',') } else { $r.RemoteAddress }
            Write-Host "  [PREVIEW] New-NetFirewallRule -DisplayName '$($r.DisplayName)' -Direction Inbound -Action $($r.Action) -Protocol TCP -LocalPort $port -RemoteAddress $raStr -Profile $($r.Profile) -Enabled True" -ForegroundColor Yellow
        } else {
            try {
                New-NetFirewallRule `
                    -DisplayName $r.DisplayName `
                    -Direction Inbound `
                    -Action $r.Action `
                    -Protocol TCP `
                    -LocalPort $port `
                    -RemoteAddress $r.RemoteAddress `
                    -Profile $r.Profile `
                    -Enabled True `
                    -ErrorAction Stop | Out-Null
                Write-Host "  [OK]   $($r.DisplayName) creada" -ForegroundColor Green
            } catch {
                Write-Host "  [FAIL] $($r.DisplayName) - $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
}

Write-Host ""
if ($DryRun) {
    Write-Host "Dry-run completo. Re-correr con -Apply para crear las reglas." -ForegroundColor Yellow
} else {
    Write-Host "Hardening aplicado. Verifica con:" -ForegroundColor Green
    Write-Host "  Get-NetFirewallRule -DisplayName 'Muselecom-*' | Select DisplayName, Action, Enabled | ft -AutoSize"
}

Write-Host ""
Write-Host "=== Tests post-apply sugeridos ===" -ForegroundColor Cyan
Write-Host "Desde Server288 (debe responder · ZeroTier overlay):"
Write-Host "  curl http://192.168.193.34:3010/healthz   # Admin via ZeroTier"
Write-Host ""
Write-Host "Desde dispositivo en LAN 192.168.1.x (debe TIMEOUT post-apply):"
Write-Host "  curl http://192.168.1.35:3010/healthz"
Write-Host ""
Write-Host "Desde teléfono con datos móviles (debe TIMEOUT siempre · Public default Block):"
Write-Host "  curl http://104.167.196.240:3010/healthz"
