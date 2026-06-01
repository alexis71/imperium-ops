#!/bin/bash
# Imperium auto-heal · health probe + auto-restart vía pm2
#
# Resuelve I1 N°71: pm2-nodemon silent crash pattern donde pm2 reporta "online"
# pero el child node murió. Smoke-cron horario los detecta (alerts.log) pero no remediaba.
# Este script complementa: cada 5 min hace health probe, si falla → pm2 restart.
#
# Diferencia con smoke-cron.sh (horario):
#   - smoke-cron · 1/h · 178 tests integrales · cobertura comprehensiva (login + SSO + CSV + etc)
#   - auto-heal  · 1/5min · 9 health probes · velocidad de detección/remediación
#
# Uso:
#   bash Desktop/_ops/auto-heal.sh
# PM2:
#   pm2 start Desktop/_ops/auto-heal.sh --name imperium-heal --cron-restart "*/5 * * * *" --no-autorestart

export PATH="/usr/bin:/bin:/mingw64/bin:/c/nvm4w/nodejs:/c/Users/Administrator/AppData/Roaming/npm:$PATH"

LOG_DIR="/c/Users/Administrator/Desktop/_ops/logs"
mkdir -p "$LOG_DIR"
HEAL_LOG="$LOG_DIR/auto-heal.log"
HEARTBEAT_LOG="$LOG_DIR/auto-heal-heartbeat.log"
DATE_TS=$(date '+%Y-%m-%d %H:%M:%S')

# N°77 close · heartbeat para verificar cron firing (cron-restart pm2 puede fallar silente)
echo "$DATE_TS · fired" >> "$HEARTBEAT_LOG"
# Cleanup heartbeat > 100 líneas
if [ "$(wc -l < "$HEARTBEAT_LOG" 2>/dev/null || echo 0)" -gt 100 ]; then
  tail -50 "$HEARTBEAT_LOG" > "$HEARTBEAT_LOG.tmp" && mv "$HEARTBEAT_LOG.tmp" "$HEARTBEAT_LOG"
fi

# Pares backend pm2-name:port (lo que verificó N°71)
SERVICES=(
  "nk-backend:3001"
  "rt-backend:3003"
  "kompaws-backend:3006"
  "admin-backend:3010"
  "hub-backend:3020"
  "finance-backend:3030"
  "hr-backend:3040"
  "sales-backend:3050"
  "crm-backend:3060"
  "inventory-backend:3070"
  "purchasing-backend:3080"
)

RESTARTED=()
HEALTHY=0
FAILED_AND_DEAD=()

for entry in "${SERVICES[@]}"; do
  NAME="${entry%:*}"
  PORT="${entry#*:}"

  # Health probe · timeout 5s
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://localhost:$PORT/api/v1/health" 2>/dev/null)

  if [ "$HTTP_CODE" = "200" ]; then
    HEALTHY=$((HEALTHY + 1))
    continue
  fi

  # Health failed · ver qué dice pm2
  PM2_STATUS=$(pm2 jlist 2>/dev/null | node -e "
    try {
      const list = JSON.parse(require('fs').readFileSync(0, 'utf8'));
      const p = list.find(x => x.name === '$NAME');
      if (!p) { console.log('NOTFOUND'); }
      else { console.log(p.pm2_env.status + '|' + p.pm2_env.restart_time); }
    } catch(e) { console.log('ERROR'); }
  " 2>/dev/null)

  STATUS="${PM2_STATUS%|*}"
  RESTARTS="${PM2_STATUS#*|}"

  echo "$DATE_TS · $NAME :$PORT · http=$HTTP_CODE · pm2=$STATUS · restarts=$RESTARTS" >> "$HEAL_LOG"

  # I1 fingerprint: pm2 says online but health fails · ZOMBIE detection
  ZOMBIE_PID=""
  if [ "$STATUS" = "online" ]; then
    # Bloqueando IPv4 o IPv6 con node "fantasma" (no del pm2 actual)
    # Buscar el PID del listener actual en el puerto, ver si pm2 lo reconoce
    LISTENER_PID=$(powershell.exe -NoProfile -Command "(Get-NetTCPConnection -LocalPort $PORT -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1).OwningProcess" 2>/dev/null | tr -d '[:space:]')
    if [ -n "$LISTENER_PID" ] && [ "$LISTENER_PID" != "0" ]; then
      # Si hay un PID listening pero pm2 online no responde, el listener es zombie
      PM2_OWNS=$(pm2 jlist 2>/dev/null | node -e "
        try {
          const list = JSON.parse(require('fs').readFileSync(0, 'utf8'));
          const owners = list.filter(p => p.pid === $LISTENER_PID).map(p => p.name);
          console.log(owners.length ? owners.join(',') : 'ORPHAN');
        } catch(e) { console.log('UNKNOWN'); }
      " 2>/dev/null)
      if [ "$PM2_OWNS" = "ORPHAN" ]; then
        ZOMBIE_PID="$LISTENER_PID"
        echo "$DATE_TS · $NAME :$PORT · 🧟 zombie PID=$ZOMBIE_PID bloqueando puerto · matando" >> "$HEAL_LOG"
        powershell.exe -NoProfile -Command "Stop-Process -Id $ZOMBIE_PID -Force -ErrorAction SilentlyContinue" 2>/dev/null
        sleep 2
      fi
    fi
  fi

  # Restart vía pm2
  pm2 restart "$NAME" --update-env >/dev/null 2>&1
  sleep 4
  RECHECK=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://localhost:$PORT/api/v1/health" 2>/dev/null)

  if [ "$RECHECK" = "200" ]; then
    RESTARTED+=("$NAME :$PORT")
    echo "$DATE_TS · $NAME :$PORT · ✅ recuperado tras pm2 restart (zombie=$ZOMBIE_PID)" >> "$HEAL_LOG"
  else
    FAILED_AND_DEAD+=("$NAME :$PORT (post-restart http=$RECHECK)")
    echo "$DATE_TS · $NAME :$PORT · ❌ NO recuperó · post-restart http=$RECHECK" >> "$HEAL_LOG"
  fi
done

# Resumen una línea si todo OK · destacado si hubo intervención
if [ ${#RESTARTED[@]} -gt 0 ] || [ ${#FAILED_AND_DEAD[@]} -gt 0 ]; then
  {
    echo ""
    echo "════════════ AUTO-HEAL $DATE_TS ════════════"
    echo "  Healthy: $HEALTHY/${#SERVICES[@]}"
    if [ ${#RESTARTED[@]} -gt 0 ]; then
      echo "  Restarted (I1 silent crash detected):"
      for r in "${RESTARTED[@]}"; do echo "    ↻ $r"; done
    fi
    if [ ${#FAILED_AND_DEAD[@]} -gt 0 ]; then
      echo "  STILL DEAD after restart attempt:"
      for d in "${FAILED_AND_DEAD[@]}"; do echo "    ❌ $d"; done
      echo "  → escalación manual requerida"
    fi
  } >> "$LOG_DIR/alerts.log"
fi

# Cleanup heal log > 14 días
find "$LOG_DIR" -name "auto-heal.log" -mtime +14 -delete 2>/dev/null

# Exit code: 0 todo healthy o todo recuperado · 1 si quedó algo dead
if [ ${#FAILED_AND_DEAD[@]} -gt 0 ]; then exit 1; fi
exit 0
