#!/bin/bash
# npm-audit-all.sh · auditoría de vulnerabilidades npm en todos los proyectos Imperium.
# Uso periódico (semanal/manual) · NO en el smoke horario (npm audit es lento y de red).
#
# N°67 · pm2/servicios resuelven `bash` -> WSL · este script usa PATH explícito de Git Bash
# si se invoca desde un servicio. Ver feedback_bash_path_hijack_wsl_windows.
export PATH="/usr/bin:/bin:/mingw64/bin:/usr/local/bin:$PATH"

ROOT="/c/Users/Administrator/Desktop"
PROJECTS="Imperium_Forge Kompaws RoundTable_v1 NetKnight_Project_v5/netknight Imperium_Analytics_Admin Imperium_Analytics_Hub Imperium_Hr Imperium_Crm Imperium_Sales Imperium_Finance imperium-core"

echo "═══════════════════════════════════════════════"
echo "  npm audit · Imperium · $(date '+%Y-%m-%d %H:%M')"
echo "═══════════════════════════════════════════════"

total_crit=0
total_high=0
total_mod=0

audit_dir() {
  local label="$1" dir="$2"
  [ -f "$dir/package.json" ] || return
  [ -f "$dir/package-lock.json" ] || { printf '  %-28s sin lockfile (skip)\n' "$label"; return; }
  local json crit high mod low
  json=$(cd "$dir" && npm audit --json 2>/dev/null)
  crit=$(echo "$json" | grep -o '"critical":[0-9]*' | head -1 | grep -o '[0-9]*')
  high=$(echo "$json" | grep -o '"high":[0-9]*' | head -1 | grep -o '[0-9]*')
  mod=$(echo  "$json" | grep -o '"moderate":[0-9]*' | head -1 | grep -o '[0-9]*')
  low=$(echo  "$json" | grep -o '"low":[0-9]*' | head -1 | grep -o '[0-9]*')
  crit=${crit:-0}; high=${high:-0}; mod=${mod:-0}; low=${low:-0}
  total_crit=$((total_crit+crit)); total_high=$((total_high+high)); total_mod=$((total_mod+mod))
  if [ "$crit" -gt 0 ] || [ "$high" -gt 0 ]; then
    printf '  %-28s 🔴 crit:%s high:%s mod:%s low:%s\n' "$label" "$crit" "$high" "$mod" "$low"
  elif [ "$mod" -gt 0 ]; then
    printf '  %-28s 🟡 mod:%s low:%s\n' "$label" "$mod" "$low"
  else
    printf '  %-28s ✅ limpio\n' "$label"
  fi
}

for p in $PROJECTS; do
  name=$(basename "$p")
  audit_dir "$name/server" "$ROOT/$p/server"
  audit_dir "$name/client" "$ROOT/$p/client"
  # repos sin server/client (imperium-core)
  audit_dir "$name" "$ROOT/$p"
done

echo "───────────────────────────────────────────────"
echo "  TOTAL · crítico:$total_crit · alto:$total_high · moderado:$total_mod"
echo "───────────────────────────────────────────────"
[ "$total_crit" -gt 0 ] && exit 2
[ "$total_high" -gt 0 ] && exit 1
exit 0
