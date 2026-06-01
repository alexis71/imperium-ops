<#
  decrypt-secrets.ps1 · Bloque 1 (2026-05-30)
  Descifra IMPERIUM_SECRETS.txt.dpapi (cifrado con DPAPI, scope CurrentUser).
  Solo funciona en esta máquina, bajo la cuenta Administrator que lo cifró.

  Uso:
    .\decrypt-secrets.ps1            # imprime el contenido en pantalla
    .\decrypt-secrets.ps1 -ToFile   # lo escribe a IMPERIUM_SECRETS.txt (re-crea el plano temporalmente)

  Nota: el archivo cifrado es una COPIA DE REFERENCIA. Los secretos vivos están en cada
  server/.env (gitignored). Si pierdes acceso a esta cuenta/host, recupera desde los .env.
#>
param([switch]$ToFile)
Add-Type -AssemblyName System.Security
$enc = 'C:\Users\Administrator\Desktop\IMPERIUM_SECRETS.txt.dpapi'
if (-not (Test-Path $enc)) { Write-Error "No existe $enc"; exit 1 }
$cipher = [System.IO.File]::ReadAllBytes($enc)
$plain  = [System.Security.Cryptography.ProtectedData]::Unprotect($cipher, $null, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
$text   = [System.Text.Encoding]::UTF8.GetString($plain)
if ($ToFile) {
  $out = 'C:\Users\Administrator\Desktop\IMPERIUM_SECRETS.txt'
  [System.IO.File]::WriteAllBytes($out, $plain)
  Write-Output "Escrito a $out — BÓRRALO cuando termines (deja solo el .dpapi)."
} else {
  Write-Output $text
}
