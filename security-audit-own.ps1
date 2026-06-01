<#
  security-audit-own.ps1 · 2026-05-30
  Auditoría de seguridad de los repos PROPIOS Imperium.
  trivy  → CVEs en dependencias (lockfiles) + misconfig (Docker/IaC)
  gitleaks → secrets en historial git (¿commiteado algún secreto?)
  NO toca runtime · solo lee. Output JSON por repo + resumen.
#>
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$tools = 'C:\Users\Administrator\Desktop\_ops\sectools'
$trivy = "$tools\trivy.exe"
$gitleaks = "$tools\gitleaks.exe"
$out = 'C:\Users\Administrator\Desktop\_ops\security-audit-own-' + (Get-Date -Format 'yyyy-MM-dd')
New-Item -ItemType Directory -Force -Path $out | Out-Null
$DESK = 'C:\Users\Administrator\Desktop'

$repos = [ordered]@{
  'Kompaws'      = "$DESK\Kompaws"
  'RoundTable'   = "$DESK\RoundTable_v1"
  'NetKnight'    = "$DESK\NetKnight_Project_v5\netknight"
  'Hub'          = "$DESK\Imperium_Analytics_Hub"
  'Admin'        = "$DESK\Imperium_Analytics_Admin"
  'Finance'      = "$DESK\Imperium_Finance"
  'Sales'        = "$DESK\Imperium_Sales"
  'Inventory'    = "$DESK\Imperium_Inventory"
  'Purchasing'   = "$DESK\Imperium_Purchasing"
  'HR'           = "$DESK\Imperium_Hr"
  'CRM'          = "$DESK\Imperium_Crm"
}

$summary = "$out\_SUMMARY.txt"
"== Security audit (propios) 2026-05-30 · trivy + gitleaks ==" | Out-File $summary -Encoding utf8

foreach ($name in $repos.Keys) {
  $path = $repos[$name]
  "`n######## $name ($path) ########" | Tee-Object -FilePath $summary -Append
  if (-not (Test-Path $path)) { "  PATH no existe" | Tee-Object -FilePath $summary -Append; continue }

  # --- trivy: vuln (deps) + misconfig ---
  $tj = "$out\$name.trivy.json"
  & $trivy fs --scanners vuln,misconfig --severity CRITICAL,HIGH --skip-dirs node_modules --no-progress --format json --output $tj $path 2>$null
  if (Test-Path $tj) {
    try {
      $tr = Get-Content $tj -Raw | ConvertFrom-Json
      $vCrit=0; $vHigh=0; $mCrit=0; $mHigh=0
      foreach ($r in $tr.Results) {
        foreach ($v in $r.Vulnerabilities) { if ($v.Severity -eq 'CRITICAL'){$vCrit++} elseif ($v.Severity -eq 'HIGH'){$vHigh++} }
        foreach ($m in $r.Misconfigurations) { if ($m.Severity -eq 'CRITICAL'){$mCrit++} elseif ($m.Severity -eq 'HIGH'){$mHigh++} }
      }
      "  trivy VULN  -> CRITICAL=$vCrit HIGH=$vHigh" | Tee-Object -FilePath $summary -Append
      "  trivy MISCFG-> CRITICAL=$mCrit HIGH=$mHigh" | Tee-Object -FilePath $summary -Append
      # top 8 vuln id+pkg
      $tops = foreach ($r in $tr.Results) { foreach ($v in $r.Vulnerabilities) { "    [$($v.Severity)] $($v.PkgName) $($v.InstalledVersion) -> $($v.VulnerabilityID) (fix: $($v.FixedVersion))" } }
      ($tops | Select-Object -First 8) | Tee-Object -FilePath $summary -Append
    } catch { "  trivy parse error: $($_.Exception.Message)" | Tee-Object -FilePath $summary -Append }
  } else { "  trivy sin output" | Tee-Object -FilePath $summary -Append }

  # --- gitleaks: secrets en historial git ---
  $gj = "$out\$name.gitleaks.json"
  if (Test-Path "$path\.git") {
    & $gitleaks detect --source $path --report-format json --report-path $gj --no-banner --exit-code 0 2>$null
    if (Test-Path $gj) {
      try {
        $gl = Get-Content $gj -Raw | ConvertFrom-Json
        $n = @($gl).Count
        "  gitleaks SECRETS en git -> $n" | Tee-Object -FilePath $summary -Append
        ($gl | Select-Object -First 5 | ForEach-Object { "    $($_.RuleID) · $($_.File):$($_.StartLine)" }) | Tee-Object -FilePath $summary -Append
      } catch { "  gitleaks parse error" | Tee-Object -FilePath $summary -Append }
    }
  } else { "  (no es repo git · skip gitleaks)" | Tee-Object -FilePath $summary -Append }
}
"`n== FIN ==" | Tee-Object -FilePath $summary -Append