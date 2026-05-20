#!/bin/bash
# Mata el proceso que está bindeando un puerto específico (Windows · proceso zombie pm2)
#
# Uso:
#   bash _ops/kill-port.sh 3006
#   bash _ops/kill-port.sh 3003

PORT="$1"
if [ -z "$PORT" ]; then
  echo "Uso: bash kill-port.sh PORT"
  exit 1
fi

PID=$(netstat -ano | grep -E ":$PORT.*LISTENING" | head -1 | awk '{print $NF}')

if [ -z "$PID" ]; then
  echo "✓ Puerto :$PORT libre · sin procesos listening"
  exit 0
fi

echo "Proceso :$PORT PID=$PID · matando..."
taskkill //F //PID "$PID" 2>&1

echo ""
echo "Verificación post-kill:"
netstat -ano | grep -E ":$PORT.*LISTENING" || echo "✓ Puerto :$PORT ahora libre"
echo ""
echo "Si el servicio era pm2-managed · ejecutá: pm2 restart NAME"
