#!/usr/bin/env bash
# ============================================================
# Imperium · smoke-test integral
# Valida flows clave end-to-end · ~20s ejecución total
# ============================================================
# Programas testeados (5):
#   - Almena   :3001  (admin login)
#   - Sceptra  :3003  (auth login + admin pull desde Admin)
#   - Kompaws  :3006  (auth login + admin pull desde Admin)
#   - Admin    :3010  (super-admin login)
#   - Hub      :3020  (HubUser login + dashboard endpoints + reset password sandbox)
#
# Salida: códigos HTTP por endpoint · 0 si todos OK · 1 si alguno falla.

set +e

PASS=0
FAIL=0

check() {
    local name="$1"
    local expected="$2"
    local actual="$3"
    if [ "$expected" = "$actual" ]; then
        printf "  \033[32m✓\033[0m  %-50s HTTP %s\n" "$name" "$actual"
        PASS=$((PASS + 1))
    else
        printf "  \033[31m✗\033[0m  %-50s HTTP %s (esperado %s)\n" "$name" "$actual" "$expected"
        FAIL=$((FAIL + 1))
    fi
}

http_code() {
    curl -s -o /dev/null -w "%{http_code}" -m 5 "$@"
}

echo "════════════════════════════════════════════════════════════"
echo "  Imperium smoke-test · $(date +%Y-%m-%d\ %H:%M:%S)"
echo "════════════════════════════════════════════════════════════"

# ── Health endpoints ────────────────────────────────────────
echo ""
echo "▶ Health checks"
check "Almena   /health"     "200" "$(http_code http://localhost:3001/api/v1/health)"
check "Sceptra  /health"     "200" "$(http_code http://localhost:3003/api/v1/health)"
check "Kompaws  /health"     "200" "$(http_code http://localhost:3006/api/v1/health)"
check "Admin    /health"     "200" "$(http_code http://localhost:3010/api/v1/health)"
check "Hub      /health"     "200" "$(http_code http://localhost:3020/api/v1/health)"

# ── Login flows ─────────────────────────────────────────────
echo ""
echo "▶ Login flows"

KP_LOGIN=$(curl -s -X POST http://localhost:3006/api/v1/auth/login \
    -H "Content-Type: application/json" \
    -d '{"email":"alejandro.rodriguez@muselecom.com","password":"CambiarEnProd2026!"}')
KP_TOKEN=$(echo "$KP_LOGIN" | grep -oE '"accessToken":"[^"]+"' | sed 's/"accessToken":"//;s/"$//')
[ -n "$KP_TOKEN" ] && check "Kompaws  super-admin login" "200" "200" || check "Kompaws  super-admin login" "200" "FAIL"

RT_LOGIN=$(curl -s -X POST http://localhost:3003/api/v1/auth/login \
    -H "Content-Type: application/json" \
    -d '{"email":"alejandro.rodriguez@muselecom.com","password":"CambiarEnProd2026!"}')
RT_TOKEN=$(echo "$RT_LOGIN" | grep -oE '"accessToken":"[^"]+"' | sed 's/"accessToken":"//;s/"$//')
[ -n "$RT_TOKEN" ] && check "Sceptra  super-admin login" "200" "200" || check "Sceptra  super-admin login" "200" "FAIL"

HUB_LOGIN=$(curl -s -X POST http://localhost:3020/api/v1/hub-auth/login \
    -H "Content-Type: application/json" \
    -d '{"email":"dueno@kompaws.demo","password":"HubDemo2026!"}')
HUB_TOKEN=$(echo "$HUB_LOGIN" | grep -oE '"accessToken":"[^"]+"' | sed 's/"accessToken":"//;s/"$//')
[ -n "$HUB_TOKEN" ] && check "Hub      HubUser login" "200" "200" || check "Hub      HubUser login" "200" "FAIL"

# ── Hub Dashboard endpoints (depende de Module[iahb] + CustomerModule poblado) ──
echo ""
echo "▶ Hub dashboard endpoints"
if [ -n "$HUB_TOKEN" ]; then
    check "Hub /my/modules?refresh=true" "200" "$(http_code -H "Authorization: Bearer $HUB_TOKEN" 'http://localhost:3020/api/v1/my/modules?refresh=true')"
    check "Hub /my/summary"              "200" "$(http_code -H "Authorization: Bearer $HUB_TOKEN" 'http://localhost:3020/api/v1/my/summary')"
    check "Hub /my/invoices/summary"     "200" "$(http_code -H "Authorization: Bearer $HUB_TOKEN" 'http://localhost:3020/api/v1/my/invoices/summary')"
fi

# ── Hub D.3 self-service password reset (sandbox) ───────────
echo ""
echo "▶ Hub D.3 password reset (sandbox)"
FORGOT_REAL=$(http_code -X POST http://localhost:3020/api/v1/hub-auth/forgot-password \
    -H "Content-Type: application/json" \
    -d '{"email":"dueno@kompaws.demo"}')
check "POST /hub-auth/forgot-password" "200" "$FORGOT_REAL"

FORGOT_FAKE=$(http_code -X POST http://localhost:3020/api/v1/hub-auth/forgot-password \
    -H "Content-Type: application/json" \
    -d '{"email":"noexiste@nada.com"}')
check "POST /hub-auth/forgot (anti-enum)" "200" "$FORGOT_FAKE"

# ── SSO emit + consume ──────────────────────────────────────
echo ""
echo "▶ SSO Hub → Kompaws"
if [ -n "$HUB_TOKEN" ]; then
    EMIT=$(curl -s -X POST http://localhost:3020/api/v1/sso/emit \
        -H "Authorization: Bearer $HUB_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{"moduleCode":"kp"}')
    SSO_TOKEN=$(echo "$EMIT" | grep -oE '"token":"[a-f0-9]+"' | head -1 | sed 's/"token":"//;s/"$//')
    [ -n "$SSO_TOKEN" ] && check "Hub /sso/emit (KP token)" "200" "200" || check "Hub /sso/emit (KP token)" "200" "FAIL"

    if [ -n "$SSO_TOKEN" ]; then
        CONSUME=$(curl -s -w "%{http_code}" -X POST http://localhost:3006/api/v1/sso/consume \
            -H "Content-Type: application/json" -d "{\"token\":\"$SSO_TOKEN\"}")
        CCODE="${CONSUME: -3}"
        check "KP /sso/consume (Hub token)" "200" "$CCODE"
    fi
fi

# ── Pulls Admin → verticales ────────────────────────────────
echo ""
echo "▶ Pulls Admin → verticales (X-Imperium-Admin-Key)"
ADMIN_PULLS=$(cd /c/Users/Administrator/Desktop/Imperium_Analytics_Admin/server 2>/dev/null && node -e "
const { pull } = require('./src/utils/vertical-client');
(async () => {
  for (const code of ['rt','kp','nk']) {
    try { await pull(code, '/api/v1/admin/tenants'); console.log(code + ':OK'); }
    catch (e) { console.log(code + ':FAIL'); }
  }
})();
" 2>&1)
echo "$ADMIN_PULLS" | while read line; do
    name=$(echo "$line" | cut -d: -f1)
    status=$(echo "$line" | cut -d: -f2)
    if [ "$status" = "OK" ]; then
        printf "  \033[32m✓\033[0m  Admin → %-43s OK\n" "$name"
        PASS=$((PASS + 1))
    else
        printf "  \033[31m✗\033[0m  Admin → %-43s %s\n" "$name" "$status"
        FAIL=$((FAIL + 1))
    fi
done

# ── Resumen ─────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════════"
TOTAL=$((PASS + FAIL))
if [ $FAIL -eq 0 ]; then
    echo -e "  \033[32mPASS\033[0m · $PASS/$TOTAL checks OK"
    exit 0
else
    echo -e "  \033[31mFAIL\033[0m · $PASS OK · $FAIL FAIL · $TOTAL total"
    exit 1
fi
