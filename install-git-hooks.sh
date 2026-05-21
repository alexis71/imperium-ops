#!/bin/bash
# install-git-hooks.sh · instala el pre-commit hook de gitleaks en los repos Imperium locales.
# Idempotente · re-ejecutar tras clonar un repo nuevo.
# El hook NO se versiona dentro de cada repo (.git/hooks/ es local) · este script lo re-aplica.
export PATH="/usr/bin:/bin:/mingw64/bin:/usr/local/bin:$PATH"

HOOK_SRC="/c/Users/Administrator/Desktop/_ops/git-hooks/pre-commit"
ROOT="/c/Users/Administrator/Desktop"
REPOS="Imperium_Forge Kompaws RoundTable_v1 NetKnight_Project_v5/netknight Imperium_Analytics_Admin Imperium_Analytics_Hub Imperium_Hr Imperium_Crm Imperium_Sales Imperium_Finance imperium-core _ops"

[ -f "$HOOK_SRC" ] || { echo "FATAL: no existe $HOOK_SRC"; exit 1; }

echo "=== Instalando pre-commit hook (gitleaks) ==="
ok=0
for r in $REPOS; do
  gitdir="$ROOT/$r/.git"
  if [ -d "$gitdir" ]; then
    cp "$HOOK_SRC" "$gitdir/hooks/pre-commit"
    chmod +x "$gitdir/hooks/pre-commit"
    echo "  ✓ $(basename "$r")"
    ok=$((ok+1))
  else
    echo "  – $(basename "$r") (no es repo git)"
  fi
done
echo "─────────────────────────────"
echo "  $ok repos protegidos"
