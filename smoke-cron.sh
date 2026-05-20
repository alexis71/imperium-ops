#!/bin/bash
# Smoke test horario · escribe resultado en _ops/logs/smoke-YYYY-MM-DD.log
# Pm2 cron lo ejecuta cada hora.
#
# N°67 · pm2 spawn no hereda PATH completo de Git Bash · sin esto date/grep/find
# del MSYS no se encuentran (smoke-all.sh sí funciona porque usa rutas absolutas).
export PATH="/usr/bin:/bin:/mingw64/bin:/usr/local/bin:$PATH"

LOG_DIR="/c/Users/Administrator/Desktop/_ops/logs"
mkdir -p "$LOG_DIR"

DATE=$(date +%Y-%m-%d)
TIME=$(date +%H:%M:%S)
LOG_FILE="$LOG_DIR/smoke-$DATE.log"

echo "" >> "$LOG_FILE"
echo "════════════ $TIME ════════════" >> "$LOG_FILE"

OUTPUT=$(bash /c/Users/Administrator/Desktop/_ops/smoke-all.sh 2>&1)
EXIT_CODE=$?

echo "$OUTPUT" >> "$LOG_FILE"

# Si hay fallas · escribir entry destacada en alerts log
if [ $EXIT_CODE -ne 0 ]; then
  echo "$TIME · FAIL detectado · $(echo "$OUTPUT" | grep -E '❌' | head -3)" >> "$LOG_DIR/alerts.log"
fi

# Cleanup logs viejos > 7 días
find "$LOG_DIR" -name "smoke-*.log" -mtime +7 -delete 2>/dev/null

exit $EXIT_CODE
