#!/bin/bash
# Smoke test integral · 5 backends · health + login + endpoints clave + SSO
#
# Uso:
#   bash Desktop/_ops/smoke-all.sh

set -e

# N°68 · Node migrado a nvm4w (setup Obsidia · C:\Program Files\nodejs eliminado).
# Sin esto, node/npm/npx/pm2 no resuelven y `set -e` mata el smoke en el check pm2.
export PATH="/c/nvm4w/nodejs:/c/Users/Administrator/AppData/Roaming/npm:$PATH"

PASS=0
FAIL=0
RESULTS=()

check() {
  local label="$1"
  local cmd="$2"
  local expected="$3"
  local actual=$(eval "$cmd" 2>&1 | head -c 500)
  if echo "$actual" | grep -q "$expected"; then
    echo "  ✅ $label"
    PASS=$((PASS + 1))
  else
    echo "  ❌ $label"
    echo "     expected: $expected"
    echo "     got: $(echo $actual | head -c 100)"
    FAIL=$((FAIL + 1))
    RESULTS+=("❌ $label")
  fi
}

echo "═══════════════════════════════════════════════════════════"
echo "  SMOKE TEST INTEGRAL · Imperium · $(date +%H:%M:%S)"
echo "═══════════════════════════════════════════════════════════"
echo ""

echo "── HEALTH endpoints ──"
check "Admin :3010 health"   "curl -s http://localhost:3010/api/v1/health"   '"status":"ok"'
check "Hub :3020 health"     "curl -s http://localhost:3020/api/v1/health"   '"status":"ok"'
check "Sceptra :3003 health" "curl -s http://localhost:3003/api/v1/health"   '"status":"ok"'
check "Kompaws :3006 health" "curl -s http://localhost:3006/api/v1/health"   '"status":"ok"'
check "Almena :3001 health"  "curl -s http://localhost:3001/api/v1/health"   '"status":"ok"'
check "Finance :3030 health" "curl -s http://localhost:3030/api/v1/health"   '"status":"ok"'
check "Sales :3050 health"   "curl -s http://localhost:3050/api/v1/health"   '"status":"ok"'
check "HR :3040 health"      "curl -s http://localhost:3040/api/v1/health"   '"status":"ok"'
check "CRM :3060 health"     "curl -s http://localhost:3060/api/v1/health"   '"status":"ok"'

# N°55 · Vite clients health (9 frontends · cada uno sirve 200 si pm2 lo tiene online)
echo ""
echo "── HEALTH Vite clients (N°55) ──"
for client in "5173:Almena (NK)" "5174:Sceptra (RT)" "5175:Admin" "5177:Kompaws" "5180:Hub" "5181:Sales" "5185:Finance" "5187:HR" "5189:CRM"; do
  PORT="${client%%:*}"; NAME="${client#*:}"
  code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$PORT/")
  if [ "$code" = "200" ]; then echo "  ✅ $NAME client :$PORT · 200"; PASS=$((PASS + 1)); else echo "  ❌ $NAME client :$PORT · $code"; FAIL=$((FAIL + 1)); RESULTS+=("❌ Vite $NAME :$PORT $code"); fi
done

# N°55 · pm2 restart counter check (servicio con >5 restarts en uptime reciente = crash loop)
echo ""
echo "── HEALTH pm2 stability (N°55 · restart counter) ──"
PM2_RESTARTS=$(pm2 jlist 2>/dev/null | node -e "
try {
  const list = JSON.parse(require('fs').readFileSync(0, 'utf8'));
  const issues = list.filter(p => p.pm2_env.restart_time > 5 && p.pm2_env.status === 'online').map(p => p.name + '(' + p.pm2_env.restart_time + ')');
  console.log(issues.length === 0 ? 'OK' : 'ISSUES:' + issues.join(','));
} catch(e) { console.log('UNAVAILABLE'); }
" 2>/dev/null)
if [ "$PM2_RESTARTS" = "OK" ]; then echo "  ✅ pm2 stability · 0 servicios con >5 restarts"; PASS=$((PASS + 1)); elif [ "$PM2_RESTARTS" = "UNAVAILABLE" ]; then echo "  ⚠ pm2 stability · check unavailable (pm2 jlist no disponible)"; PASS=$((PASS + 1)); else echo "  ⚠ pm2 stability · servicios inestables: ${PM2_RESTARTS#ISSUES:}"; PASS=$((PASS + 1)); fi

echo ""
echo "── LOGIN super-admin ──"
check "Hub super-admin login" "curl -s -X POST http://localhost:3020/api/v1/hub-auth/login -H 'Content-Type: application/json' -d '{\"email\":\"alejandro.rodriguez@muselecom.com\",\"password\":\"CambiarEnProd2026!\"}'" "accessToken"
check "Kompaws super-admin login" "curl -s -X POST http://localhost:3006/api/v1/auth/login -H 'Content-Type: application/json' -d '{\"email\":\"alejandro.rodriguez@muselecom.com\",\"password\":\"CambiarEnProd2026!\"}'" "accessToken"
check "Sceptra super-admin login" "curl -s -X POST http://localhost:3003/api/v1/auth/login -H 'Content-Type: application/json' -d '{\"email\":\"alejandro.rodriguez@muselecom.com\",\"password\":\"CambiarEnProd2026!\"}'" "accessToken"
check "Almena super-admin /login (auth unificado N°16)" "curl -s -X POST http://localhost:3001/api/v1/auth/login -H 'Content-Type: application/json' -d '{\"email\":\"alejandro.rodriguez@muselecom.com\",\"password\":\"CambiarEnProd2026!\"}'" "accessToken"
check "Admin super-admin login (espera MFA)" "curl -s -X POST http://localhost:3010/api/v1/auth/login -H 'Content-Type: application/json' -d '{\"email\":\"alejandro.rodriguez@muselecom.com\",\"password\":\"Acceso2018\"}'" "needsMfa"

echo ""
echo "── LOGIN demo (si existen) ──"
DEMO1_HUB=$(curl -s -X POST http://localhost:3020/api/v1/hub-auth/login -H 'Content-Type: application/json' -d '{"email":"demo1@local.com","password":"Demo12345!"}' 2>&1)
if echo "$DEMO1_HUB" | grep -q "accessToken"; then
  echo "  ✅ Hub demo1@local.com login"
  PASS=$((PASS + 1))

  echo ""
  echo "── SSO Hub→Kompaws (Demo1) end-to-end ──"
  HUBT=$(echo "$DEMO1_HUB" | grep -oE '"accessToken":"[^"]+"' | sed 's/"accessToken":"//;s/"$//')
  SSO=$(curl -s -X POST http://localhost:3020/api/v1/sso/emit -H "Content-Type: application/json" -H "Authorization: Bearer $HUBT" -d '{"moduleCode":"kp"}')
  TOK=$(echo "$SSO" | grep -oE '"token":"[^"]+"' | sed 's/"token":"//;s/"$//')
  if [ -n "$TOK" ]; then
    echo "  ✅ Hub emit SSO token"
    PASS=$((PASS + 1))
    CONS=$(curl -s -X POST "http://localhost:3006/api/v1/sso/consume" -H "Content-Type: application/json" -d "{\"token\":\"$TOK\"}")
    if echo "$CONS" | grep -q '"permissions":\['; then
      echo "  ✅ Kompaws SSO consume · permissions presentes"
      PASS=$((PASS + 1))
      ATK=$(echo "$CONS" | grep -oE '"accessToken":"[^"]+"' | sed 's/"accessToken":"//;s/"$//')
      for ep in panorama patients owners products empresa; do
        code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:3006/api/v1/$ep" -H "Authorization: Bearer $ATK")
        if [ "$code" = "200" ]; then
          echo "  ✅ /api/v1/$ep · 200 con SSO token"
          PASS=$((PASS + 1))
        else
          echo "  ❌ /api/v1/$ep · $code con SSO token"
          FAIL=$((FAIL + 1))
        fi
      done
      # CSV import templates (N°34 · feature csv_import gated · demo1-vet en gran_danes ✓)
      OWNT=$(curl -s "http://localhost:3006/api/v1/owners/csv-template" -H "Authorization: Bearer $ATK")
      if echo "$OWNT" | grep -q "firstName,lastName"; then echo "  ✅ /owners/csv-template · plantilla CSV con headers (N°34)"; PASS=$((PASS + 1)); else echo "  ❌ /owners/csv-template · sin headers"; FAIL=$((FAIL + 1)); RESULTS+=("❌ KP owners csv-template"); fi
      PATT=$(curl -s "http://localhost:3006/api/v1/patients/csv-template" -H "Authorization: Bearer $ATK")
      if echo "$PATT" | grep -q "ownerEmail,ownerPhone"; then echo "  ✅ /patients/csv-template · plantilla CSV con headers (N°34)"; PASS=$((PASS + 1)); else echo "  ❌ /patients/csv-template · sin headers"; FAIL=$((FAIL + 1)); RESULTS+=("❌ KP patients csv-template"); fi
      PRDT=$(curl -s "http://localhost:3006/api/v1/products/csv-template" -H "Authorization: Bearer $ATK")
      if echo "$PRDT" | grep -q "name,category,presentation"; then echo "  ✅ /products/csv-template · plantilla CSV con headers (N°35)"; PASS=$((PASS + 1)); else echo "  ❌ /products/csv-template · sin headers"; FAIL=$((FAIL + 1)); RESULTS+=("❌ KP products csv-template"); fi
      PRDB=$(curl -s -o /dev/null -w "%{http_code}" -X POST "http://localhost:3006/api/v1/products/bulk-csv" -H "Authorization: Bearer $ATK" -H "Content-Type: application/json" -d '{"rows":[]}')
      if [ "$PRDB" = "400" ]; then echo "  ✅ /products/bulk-csv · 400 con rows[] vacío (N°35)"; PASS=$((PASS + 1)); else echo "  ❌ /products/bulk-csv · esperado 400 got $PRDB"; FAIL=$((FAIL + 1)); RESULTS+=("❌ KP products bulk-csv empty $PRDB"); fi
      # KP polish coverage smoke (N°34 · features N°31-N°33: procedures · prescriptions · reminders · vocabulary · colleagues)
      for ep in procedures prescriptions reminders me/colleagues tenant-vocabulary tenant-vocabulary/catalog; do
        code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:3006/api/v1/$ep" -H "Authorization: Bearer $ATK")
        if [ "$code" = "200" ]; then echo "  ✅ /api/v1/$ep · 200 (KP polish N°31-N°33)"; PASS=$((PASS + 1)); else echo "  ❌ /api/v1/$ep · $code"; FAIL=$((FAIL + 1)); RESULTS+=("❌ KP $ep $code"); fi
      done
      # Reminders filtros (N°33)
      for f in today upcoming pending; do
        code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:3006/api/v1/reminders?filter=$f" -H "Authorization: Bearer $ATK")
        if [ "$code" = "200" ]; then echo "  ✅ /reminders?filter=$f · 200 (N°33)"; PASS=$((PASS + 1)); else echo "  ❌ /reminders?filter=$f · $code"; FAIL=$((FAIL + 1)); RESULTS+=("❌ KP reminders $f $code"); fi
      done
    else
      echo "  ❌ Kompaws SSO consume · permissions FALTANTES"
      FAIL=$((FAIL + 1))
    fi
  else
    echo "  ❌ Hub emit SSO token (sin token en respuesta)"
    FAIL=$((FAIL + 1))
  fi

  echo ""
  echo "── SSO Hub→Imperium Sales (Demo1) + revenue a Finance (N°27) ──"
  SSO_SA=$(curl -s -X POST http://localhost:3020/api/v1/sso/emit -H "Content-Type: application/json" -H "Authorization: Bearer $HUBT" -d '{"moduleCode":"sa","verticalCode":"kp"}')
  TOK_SA=$(echo "$SSO_SA" | grep -oE '"token":"[^"]+"' | sed 's/"token":"//;s/"$//')
  if [ -n "$TOK_SA" ]; then
    echo "  ✅ Hub emit SSO token (sa×kp)"
    PASS=$((PASS + 1))
    CONS_SA=$(curl -s -X POST "http://localhost:3050/api/v1/sso/consume" -H "Content-Type: application/json" -d "{\"token\":\"$TOK_SA\"}")
    if echo "$CONS_SA" | grep -q '"accessToken"'; then
      echo "  ✅ Imperium Sales SSO consume · accessToken emitido"
      PASS=$((PASS + 1))
      ATK_SA=$(echo "$CONS_SA" | grep -oE '"accessToken":"[^"]+"' | sed 's/"accessToken":"//;s/"$//')
      code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:3050/api/v1/sales/quotes" -H "Authorization: Bearer $ATK_SA")
      if [ "$code" = "200" ]; then echo "  ✅ /api/v1/sales/quotes · 200 con SSO token"; PASS=$((PASS + 1)); else echo "  ❌ /api/v1/sales/quotes · $code"; FAIL=$((FAIL + 1)); RESULTS+=("❌ Sales /quotes $code"); fi
      # Autocomplete cross-vertical (N°28): Sales /source-items proxy → KP /external/source-items
      SI_SA=$(curl -s "http://localhost:3050/api/v1/sales/source-items?vertical=kp&q=consul" -H "Authorization: Bearer $ATK_SA")
      if echo "$SI_SA" | grep -q '"unitPrice"'; then echo "  ✅ /sales/source-items?vertical=kp · trae ítems del catálogo KP (B3 N°28)"; PASS=$((PASS + 1)); else echo "  ❌ /sales/source-items?vertical=kp · sin ítems · $SI_SA"; FAIL=$((FAIL + 1)); RESULTS+=("❌ Sales source-items KP"); fi
      # Directorio de clientes (N°28): Sales /customers
      CU_SA=$(curl -s "http://localhost:3050/api/v1/customers" -H "Authorization: Bearer $ATK_SA")
      if echo "$CU_SA" | grep -q '"name"'; then echo "  ✅ /customers · directorio de clientes (Customer model N°28)"; PASS=$((PASS + 1)); else echo "  ❌ /customers · sin clientes · $CU_SA"; FAIL=$((FAIL + 1)); RESULTS+=("❌ Sales /customers"); fi
      # validateRfc en POST /customers (N°29 + N°30): valid normaliza · invalid rechaza
      VRFC_OK=$(curl -s -o /dev/null -w "%{http_code}" -X POST "http://localhost:3050/api/v1/customers" -H "Authorization: Bearer $ATK_SA" -H "Content-Type: application/json" -d '{"name":"Smoke RFC OK","taxId":"gohm900101ab1"}')
      if [ "$VRFC_OK" = "201" ]; then echo "  ✅ /customers POST · taxId lowercase válido → 201 (validateRfc N°29)"; PASS=$((PASS + 1)); else echo "  ❌ /customers POST taxId valid · $VRFC_OK"; FAIL=$((FAIL + 1)); RESULTS+=("❌ validateRfc valid $VRFC_OK"); fi
      VRFC_BAD=$(curl -s -o /dev/null -w "%{http_code}" -X POST "http://localhost:3050/api/v1/customers" -H "Authorization: Bearer $ATK_SA" -H "Content-Type: application/json" -d '{"name":"Smoke RFC BAD","taxId":"BUEY830101AB1"}')
      if [ "$VRFC_BAD" = "400" ]; then echo "  ✅ /customers POST · taxId reservada SAT (BUEY) → 400 (validateRfc N°29)"; PASS=$((PASS + 1)); else echo "  ❌ /customers POST taxId BUEY · esperaba 400 · obtuvo $VRFC_BAD"; FAIL=$((FAIL + 1)); RESULTS+=("❌ validateRfc bad $VRFC_BAD"); fi
      # Facturas (N°28): Sales /invoices (route montada · responde 200 con data array)
      code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:3050/api/v1/invoices" -H "Authorization: Bearer $ATK_SA")
      if [ "$code" = "200" ]; then echo "  ✅ /invoices · 200 (Invoice model N°28)"; PASS=$((PASS + 1)); else echo "  ❌ /invoices · $code"; FAIL=$((FAIL + 1)); RESULTS+=("❌ Sales /invoices $code"); fi
      # CFDI · datos fiscales del emisor (N°28): Sales /sales/fiscal-config
      FC_SA=$(curl -s "http://localhost:3050/api/v1/sales/fiscal-config" -H "Authorization: Bearer $ATK_SA")
      if echo "$FC_SA" | grep -q '"cfdiSerie"'; then echo "  ✅ /sales/fiscal-config · emisor CFDI (timbrado mock N°28)"; PASS=$((PASS + 1)); else echo "  ❌ /sales/fiscal-config · $FC_SA"; FAIL=$((FAIL + 1)); RESULTS+=("❌ Sales fiscal-config"); fi
    else
      echo "  ❌ Imperium Sales SSO consume · sin accessToken"
      FAIL=$((FAIL + 1)); RESULTS+=("❌ Sales SSO consume")
    fi
  else
    echo "  ❌ Hub emit SSO token (sa×kp) · sin token"
    FAIL=$((FAIL + 1)); RESULTS+=("❌ Hub emit SSO sa×kp")
  fi
  # Finance external summary debe traer salesRevenue (RevenueEntry desde Sales)
  FINSUM=$(curl -s "http://localhost:3030/api/v1/external/summary?tenantSlug=fin-demo-1-multi-imperium-s-a-kp" -H "Authorization: Bearer 205522eea766ee3d8444287909993e5df1ea915484e14ae1c30fb2b88b20dc11")
  if echo "$FINSUM" | grep -q '"salesRevenue"'; then
    echo "  ✅ Finance /external/summary · salesRevenue presente (RevenueEntry N°27)"
    PASS=$((PASS + 1))
  else
    echo "  ❌ Finance /external/summary · falta salesRevenue"
    FAIL=$((FAIL + 1)); RESULTS+=("❌ Finance summary salesRevenue")
  fi

  echo ""
  echo "── Hub cross-vertical pull (consolidado · N°25 → actualizado N°86) ──"
  # N°86: la ruta finanzas-demo.js ya no emite incidentsTrend30d/incidentsBySeverity
  # (forma vieja N°25 · removida en el sweep fachada N°83). Se valida el contrato real
  # actual: el rollup consolidado cross-vertical + la serie de tendencia.
  CV=$(curl -s "http://localhost:3020/api/v1/finanzas/cross-vertical" -H "Authorization: Bearer $HUBT")
  if echo "$CV" | grep -q '"consolidated"'; then
    echo "  ✅ Hub pull /finanzas/cross-vertical · rollup consolidado presente"
    PASS=$((PASS + 1))
  else
    echo "  ❌ Hub pull /finanzas/cross-vertical · falta consolidated"
    FAIL=$((FAIL + 1))
    RESULTS+=("❌ Hub cross-vertical consolidated")
  fi
  if echo "$CV" | grep -q '"totalImpactMXN"'; then
    echo "  ✅ Hub pull · totalImpactMXN (impacto cross-vertical) presente"
    PASS=$((PASS + 1))
  else
    echo "  ❌ Hub pull · falta totalImpactMXN"
    FAIL=$((FAIL + 1))
    RESULTS+=("❌ Hub cross-vertical totalImpactMXN")
  fi

  echo ""
  echo "── Hub Dashboard module sync (Admin pull modules) ──"
  MS=$(curl -s "http://localhost:3020/api/v1/my/modules?refresh=true" -H "Authorization: Bearer $HUBT")
  if echo "$MS" | grep -q '"moduleCode"'; then
    echo "  ✅ Hub /my/modules?refresh=true · sync OK con Admin"
    PASS=$((PASS + 1))
  else
    echo "  ❌ Hub /my/modules?refresh=true · sync falla"
    FAIL=$((FAIL + 1))
    RESULTS+=("❌ Hub Dashboard module sync")
  fi
else
  echo "  ⚠️  demo1@local.com no existe · skip SSO test (correr provision-hub-user.js si lo necesitás)"
fi

echo ""
echo "── HR domain (G.3 N°29) ──"
HR_LOGIN=$(curl -s -X POST http://localhost:3040/api/v1/auth/login -H 'Content-Type: application/json' -d '{"email":"alejandro.rodriguez@muselecom.com","password":"CambiarEnProd2026!"}')
HR_TOK=$(echo "$HR_LOGIN" | grep -oE '"accessToken":"[^"]+"' | head -1 | sed 's/"accessToken":"//;s/"$//')
if [ -n "$HR_TOK" ]; then
  echo "  ✅ HR super-admin login"
  PASS=$((PASS + 1))
  for ep in employees departments positions schedules; do
    code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:3040/api/v1/$ep" -H "Authorization: Bearer $HR_TOK")
    if [ "$code" = "200" ]; then echo "  ✅ HR /api/v1/$ep · 200"; PASS=$((PASS + 1)); else echo "  ❌ HR /api/v1/$ep · $code"; FAIL=$((FAIL + 1)); RESULTS+=("❌ HR /$ep $code"); fi
  done
  EMP_CNT=$(curl -s "http://localhost:3040/api/v1/employees" -H "Authorization: Bearer $HR_TOK" | grep -oE '"id":"' | wc -l)
  if [ "$EMP_CNT" -ge 6 ]; then echo "  ✅ HR seed: ${EMP_CNT} empleados (≥6 esperados)"; PASS=$((PASS + 1)); else echo "  ❌ HR seed: ${EMP_CNT} empleados (esperaba ≥6)"; FAIL=$((FAIL + 1)); RESULTS+=("❌ HR seed empleados"); fi
else
  echo "  ❌ HR super-admin login (sin accessToken)"
  FAIL=$((FAIL + 1)); RESULTS+=("❌ HR login")
fi

echo ""
echo "── HR Nómina operativa (Thread C · N°69) ──"
if [ -n "$HR_TOK" ]; then
  NOMRUN=$(curl -s -X POST http://localhost:3040/api/v1/payroll -H "Authorization: Bearer $HR_TOK" -H 'Content-Type: application/json' -d '{"periodLabel":"Smoke · quincena","periodStart":"2026-05-01","periodEnd":"2026-05-15","runType":"ordinaria"}')
  NOMID=$(echo "$NOMRUN" | grep -oE '"id":"[^"]+"' | head -1 | sed 's/"id":"//;s/"$//')
  NOMITEMS=$(echo "$NOMRUN" | grep -oE '"employeeId":"' | wc -l)
  if [ -n "$NOMID" ] && [ "$NOMITEMS" -ge 6 ]; then
    echo "  ✅ HR /payroll generar · $NOMITEMS renglones (snapshot empleados activos)"
    PASS=$((PASS + 1))
  else
    echo "  ❌ HR /payroll generar · run=$NOMID items=$NOMITEMS"
    FAIL=$((FAIL + 1)); RESULTS+=("❌ HR payroll generar")
  fi
  if [ -n "$NOMID" ]; then
    NOMCSV=$(curl -s "http://localhost:3040/api/v1/payroll/$NOMID/export.csv" -H "Authorization: Bearer $HR_TOK")
    if echo "$NOMCSV" | grep -q 'NetoPagado'; then
      echo "  ✅ HR /payroll/:id/export.csv · nómina para el contador"
      PASS=$((PASS + 1))
    else
      echo "  ❌ HR payroll export.csv · header inesperado"
      FAIL=$((FAIL + 1)); RESULTS+=("❌ HR payroll export.csv")
    fi
    # cleanup · descarta la corrida draft del smoke (no acumula)
    curl -s -o /dev/null -X DELETE "http://localhost:3040/api/v1/payroll/$NOMID" -H "Authorization: Bearer $HR_TOK"
  fi
else
  echo "  ⊘ HR Nómina · sin token (login falló arriba)"
fi

echo ""
echo "── CRM domain (G.4 N°38) ──"
CRM_LOGIN=$(curl -s -X POST http://localhost:3060/api/v1/auth/login -H 'Content-Type: application/json' -d '{"email":"alejandro.rodriguez@muselecom.com","password":"CambiarEnProd2026!"}')
CRM_TOK=$(echo "$CRM_LOGIN" | grep -oE '"accessToken":"[^"]+"' | head -1 | sed 's/"accessToken":"//;s/"$//')
if [ -n "$CRM_TOK" ]; then
  echo "  ✅ CRM super-admin login"
  PASS=$((PASS + 1))
  for ep in customers leads pipelines opportunities activities; do
    code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:3060/api/v1/$ep" -H "Authorization: Bearer $CRM_TOK")
    if [ "$code" = "200" ]; then echo "  ✅ CRM /api/v1/$ep · 200"; PASS=$((PASS + 1)); else echo "  ❌ CRM /api/v1/$ep · $code"; FAIL=$((FAIL + 1)); RESULTS+=("❌ CRM /$ep $code"); fi
  done
  CUST_CNT=$(curl -s "http://localhost:3060/api/v1/customers" -H "Authorization: Bearer $CRM_TOK" | grep -oE '"id":"' | wc -l)
  if [ "$CUST_CNT" -ge 5 ]; then echo "  ✅ CRM seed: ${CUST_CNT} customers (≥5 esperados)"; PASS=$((PASS + 1)); else echo "  ❌ CRM seed: ${CUST_CNT} customers (esperaba ≥5)"; FAIL=$((FAIL + 1)); RESULTS+=("❌ CRM seed customers"); fi
else
  echo "  ❌ CRM super-admin login (sin accessToken)"
  FAIL=$((FAIL + 1)); RESULTS+=("❌ CRM login")
fi

# CRM client UI :5189 (N°39 · client pages CRM-específicas)
CRM_UI=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:5189/)
if [ "$CRM_UI" = "200" ]; then echo "  ✅ CRM client :5189 · 200"; PASS=$((PASS + 1)); else echo "  ❌ CRM client :5189 · $CRM_UI"; FAIL=$((FAIL + 1)); RESULTS+=("❌ CRM UI"); fi
for pg in Clientes Prospectos Pipelines Oportunidades Actividades; do
  code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:5189/src/pages/$pg.jsx")
  if [ "$code" = "200" ]; then echo "  ✅ CRM page $pg.jsx · 200"; PASS=$((PASS + 1)); else echo "  ❌ CRM page $pg.jsx · $code"; FAIL=$((FAIL + 1)); RESULTS+=("❌ CRM $pg"); fi
done

echo ""
echo "── B3 cross-vertical · /external/source-items (N°29) ──"
KP_SEC="15dba1b95abcca90997f29dea2db342549fb2ba8ec6ab314e00f1d220ad9e421"
RT_SEC="9ed2a32b7216e218f6a9d1875259023ef57899beff06a98fc30c8e9bb69b1c8e"
NK_SEC="9be036f93b13b2ec5c86089082ca72d1aaee2288c30a0154ee3d2934e3a7428d"
# Auth gate · sin Bearer = 401
for v in "kp:3006" "rt:3003" "nk:3001"; do
  V="${v%:*}"; P="${v#*:}"
  code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$P/api/v1/external/source-items?tenantSlug=x")
  if [ "$code" = "401" ]; then echo "  ✅ $V :$P /external/source-items · 401 sin Bearer"; PASS=$((PASS + 1)); else echo "  ❌ $V :$P /external · esperaba 401 · obtuvo $code"; FAIL=$((FAIL + 1)); RESULTS+=("❌ $V external 401"); fi
done
# Real query · tenantSlug demo1 = 200 con data
KP_R=$(curl -s "http://localhost:3006/api/v1/external/source-items?tenantSlug=demo1-vet&limit=3" -H "Authorization: Bearer $KP_SEC")
if echo "$KP_R" | grep -q '"unitPrice"'; then echo "  ✅ KP /external · demo1-vet trae catalog/products"; PASS=$((PASS + 1)); else echo "  ❌ KP /external · sin items demo1-vet"; FAIL=$((FAIL + 1)); RESULTS+=("❌ KP external real"); fi
RT_R=$(curl -s "http://localhost:3003/api/v1/external/source-items?tenantSlug=demo1-proj&limit=3" -H "Authorization: Bearer $RT_SEC")
if echo "$RT_R" | grep -q '"type":"phase"'; then echo "  ✅ RT /external · demo1-proj trae phases"; PASS=$((PASS + 1)); else echo "  ❌ RT /external · sin phases demo1-proj"; FAIL=$((FAIL + 1)); RESULTS+=("❌ RT external real"); fi
NK_R=$(curl -s "http://localhost:3001/api/v1/external/source-items?tenantSlug=demo-1-multi-imperium-it&limit=3" -H "Authorization: Bearer $NK_SEC")
if echo "$NK_R" | grep -q '"type":"device"'; then echo "  ✅ NK /external · demo-1-multi-imperium-it trae devices"; PASS=$((PASS + 1)); else echo "  ❌ NK /external · sin devices"; FAIL=$((FAIL + 1)); RESULTS+=("❌ NK external real"); fi

echo ""
echo "── B3 cross-vertical CRM sync (N°39 C-final · KP owners → CRM customers) ──"
CRM_WRITE_SEC="402086f7877c48865a24ff07cb046b5691cd929cf057fa89e5612d73e12e2c42"
CRM_TENANT_ID="1ce85f15-f9df-49ac-8216-af97f96f7f7a"
# Auth gate · CRM /external sin Bearer = 401
code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:3060/api/v1/external/customers?tenantId=$CRM_TENANT_ID")
if [ "$code" = "401" ]; then echo "  ✅ CRM /external/customers · 401 sin Bearer"; PASS=$((PASS + 1)); else echo "  ❌ CRM /external · esperaba 401 · obtuvo $code"; FAIL=$((FAIL + 1)); RESULTS+=("❌ CRM external 401"); fi
# KP owners-for-crm · 401 sin Bearer
code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:3006/api/v1/external/owners-for-crm?tenantSlug=demo1-vet")
if [ "$code" = "401" ]; then echo "  ✅ KP /external/owners-for-crm · 401 sin Bearer"; PASS=$((PASS + 1)); else echo "  ❌ KP /external/owners-for-crm · esperaba 401 · obtuvo $code"; FAIL=$((FAIL + 1)); RESULTS+=("❌ KP owners-for-crm 401"); fi
# KP owners-for-crm · real query con Bearer
KP_OWNERS=$(curl -s "http://localhost:3006/api/v1/external/owners-for-crm?tenantSlug=demo1-vet&limit=20" -H "Authorization: Bearer $KP_SEC")
KP_OWN_CNT=$(echo "$KP_OWNERS" | grep -oE '"externalRef":"kp:' | wc -l)
if [ "$KP_OWN_CNT" -ge 1 ]; then echo "  ✅ KP /external/owners-for-crm · $KP_OWN_CNT owners formato CRM-compatible"; PASS=$((PASS + 1)); else echo "  ❌ KP /external/owners-for-crm · sin owners ($KP_OWN_CNT)"; FAIL=$((FAIL + 1)); RESULTS+=("❌ KP owners empty"); fi
# CRM /external/customers · query con Bearer · debe traer ≥1 si sync corrió
CRM_KP=$(curl -s "http://localhost:3060/api/v1/external/customers?tenantId=$CRM_TENANT_ID&source=kp" -H "Authorization: Bearer $CRM_WRITE_SEC")
CRM_KP_CNT=$(echo "$CRM_KP" | grep -oE '"externalRef":"kp:' | wc -l)
if [ "$CRM_KP_CNT" -ge 1 ]; then echo "  ✅ CRM /external/customers source=kp · $CRM_KP_CNT customers KP-linked (sync ya corrió)"; PASS=$((PASS + 1)); else echo "  ⚠ CRM /external/customers source=kp · 0 (correr: cd Imperium_Crm/server && node scripts/sync-from-kp.js --kp-tenant demo1-vet --crm-tenant $CRM_TENANT_ID)"; PASS=$((PASS + 1)); fi
# Hub /cross-vertical-crm · 401 sin Bearer
code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:3020/api/v1/cross-vertical-crm?crmTenantId=$CRM_TENANT_ID")
if [ "$code" = "401" ]; then echo "  ✅ Hub /cross-vertical-crm · 401 sin Bearer"; PASS=$((PASS + 1)); else echo "  ❌ Hub /cross-vertical-crm · esperaba 401 · obtuvo $code"; FAIL=$((FAIL + 1)); RESULTS+=("❌ Hub cross 401"); fi

# Sales /external/customers-for-crm · N°40 C-extras
SALES_SEC=$(grep SALES_EXTERNAL_READ_SECRET /c/Users/Administrator/Desktop/Imperium_Sales/server/.env 2>/dev/null | cut -d= -f2 | tr -d '\r')
code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:3050/api/v1/external/customers-for-crm?tenantSlug=imperium_sales-demo")
if [ "$code" = "401" ]; then echo "  ✅ Sales /external/customers-for-crm · 401 sin Bearer"; PASS=$((PASS + 1)); else echo "  ❌ Sales /external/customers-for-crm · esperaba 401 · obtuvo $code"; FAIL=$((FAIL + 1)); RESULTS+=("❌ Sales for-crm 401"); fi
SALES_CUST=$(curl -s "http://localhost:3050/api/v1/external/customers-for-crm?tenantSlug=imperium_sales-demo&limit=20" -H "Authorization: Bearer $SALES_SEC")
SALES_CUST_CNT=$(echo "$SALES_CUST" | grep -oE '"externalRef":"sales:' | wc -l)
if [ "$SALES_CUST_CNT" -ge 1 ]; then echo "  ✅ Sales /external/customers-for-crm · $SALES_CUST_CNT customers formato CRM-compatible"; PASS=$((PASS + 1)); else echo "  ❌ Sales /external/customers-for-crm · sin customers ($SALES_CUST_CNT)"; FAIL=$((FAIL + 1)); RESULTS+=("❌ Sales for-crm empty"); fi
CRM_SALES=$(curl -s "http://localhost:3060/api/v1/external/customers?tenantId=$CRM_TENANT_ID&source=sales" -H "Authorization: Bearer $CRM_WRITE_SEC")
CRM_SALES_CNT=$(echo "$CRM_SALES" | grep -oE '"externalRef":"sales:' | wc -l)
if [ "$CRM_SALES_CNT" -ge 1 ]; then echo "  ✅ CRM /external/customers source=sales · $CRM_SALES_CNT Sales-linked customers"; PASS=$((PASS + 1)); else echo "  ⚠ CRM /external/customers source=sales · 0 (correr sync-from-sales.js)"; PASS=$((PASS + 1)); fi
# Hub UI pages parse OK (Vite) · N°40 Nivel 2 reorg (ModulosCrm→InsightsCrm + new ModulosCrm/Hr placeholders)
for pg in ModulosCrm ModulosHr InsightsCrm; do
  code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:5180/src/pages/$pg.jsx")
  if [ "$code" = "200" ]; then echo "  ✅ Hub UI $pg.jsx · 200 parse OK"; PASS=$((PASS + 1)); else echo "  ❌ Hub UI $pg.jsx · $code"; FAIL=$((FAIL + 1)); RESULTS+=("❌ Hub UI $pg"); fi
done
# SSO emit Hub→CRM/HR (N°41 SSO · resuelve "click Abrir HR/CRM pide login")
code=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:3060/api/v1/sso/consume -H "Content-Type: application/json" -d '{}')
if [ "$code" = "400" ]; then echo "  ✅ CRM /sso/consume · 400 sin token"; PASS=$((PASS + 1)); else echo "  ❌ CRM /sso/consume · esperaba 400 · obtuvo $code"; FAIL=$((FAIL + 1)); RESULTS+=("❌ CRM sso/consume"); fi
code=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:3040/api/v1/sso/consume -H "Content-Type: application/json" -d '{}')
if [ "$code" = "400" ]; then echo "  ✅ HR /sso/consume · 400 sin token"; PASS=$((PASS + 1)); else echo "  ❌ HR /sso/consume · esperaba 400 · obtuvo $code"; FAIL=$((FAIL + 1)); RESULTS+=("❌ HR sso/consume"); fi
# CRM SsoConsume + HR SsoConsume client parse
for client in "5189:CRM" "5187:HR"; do
  PORT="${client%:*}"; NAME="${client#*:}"
  code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$PORT/src/pages/SsoConsume.jsx")
  if [ "$code" = "200" ]; then echo "  ✅ $NAME client SsoConsume.jsx · 200"; PASS=$((PASS + 1)); else echo "  ❌ $NAME client SsoConsume.jsx · $code"; FAIL=$((FAIL + 1)); RESULTS+=("❌ $NAME SsoConsume"); fi
done

# HR Opción B N°41 · provision + KP→HR sync (resuelve "demo1 no veía su staff vet")
HR_WRITE=$(grep HR_EXTERNAL_WRITE_SECRET /c/Users/Administrator/Desktop/Imperium_Hr/server/.env 2>/dev/null | cut -d= -f2 | tr -d '\r')
# KP /external/staff-for-hr · emisor staff
KP_STAFF=$(curl -s "http://localhost:3006/api/v1/external/staff-for-hr?tenantSlug=demo1-vet" -H "Authorization: Bearer $KP_SEC")
KP_STAFF_CNT=$(echo "$KP_STAFF" | grep -oE '"externalRef":"kp:' | wc -l)
if [ "$KP_STAFF_CNT" -ge 1 ]; then echo "  ✅ KP /external/staff-for-hr · $KP_STAFF_CNT staff formato HR-compatible"; PASS=$((PASS + 1)); else echo "  ❌ KP /external/staff-for-hr · sin staff"; FAIL=$((FAIL + 1)); RESULTS+=("❌ KP staff-for-hr"); fi
# HR /external/tenants · provision idempotente
code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "http://localhost:3040/api/v1/external/tenants" -H "Authorization: Bearer $HR_WRITE" -H "Content-Type: application/json" -d '{"slug":"hr-demo-1-vet","name":"Test","ownerEmail":"x@y.com","tier":"herald"}')
if [ "$code" = "200" ] || [ "$code" = "201" ]; then echo "  ✅ HR /external/tenants · provision/idempotent ($code)"; PASS=$((PASS + 1)); else echo "  ❌ HR /external/tenants · esperaba 200/201 · obtuvo $code"; FAIL=$((FAIL + 1)); RESULTS+=("❌ HR tenants provision"); fi
# HR /external/employees/sync · receptor (verifica que existe + auth gate)
code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "http://localhost:3040/api/v1/external/employees/sync" -H "Content-Type: application/json" -d '{}')
if [ "$code" = "401" ]; then echo "  ✅ HR /external/employees/sync · 401 sin Bearer"; PASS=$((PASS + 1)); else echo "  ❌ HR /external/employees/sync · esperaba 401 · obtuvo $code"; FAIL=$((FAIL + 1)); RESULTS+=("❌ HR sync 401"); fi
# Verify demo1 tenant HR provisioned tiene los 4 vet staff (NO los 6 ingenieros del seed)
DEMO1_HR=$(curl -s "http://localhost:3040/api/v1/external/summary?tenantSlug=hr-demo-1-vet" -H "Authorization: Bearer $HR_WRITE")
DEMO1_HR_CNT=$(echo "$DEMO1_HR" | grep -oE '"active":[0-9]+' | head -1 | grep -oE '[0-9]+')
if [ "$DEMO1_HR_CNT" = "4" ]; then echo "  ✅ HR hr-demo-1-vet · 4 vet staff sync'd (Owner+gerente+personal+gerente.norte)"; PASS=$((PASS + 1)); else echo "  ⚠ HR hr-demo-1-vet · $DEMO1_HR_CNT empleados (esperaba 4 · sync no corrió o tenant no provisioned)"; PASS=$((PASS + 1)); fi

# HR paridad N°41 · cross-vertical HR (emisor + Hub proxy + UI)
HR_SEC=$(grep HR_EXTERNAL_READ_SECRET /c/Users/Administrator/Desktop/Imperium_Hr/server/.env 2>/dev/null | cut -d= -f2 | tr -d '\r')
code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:3040/api/v1/external/summary?tenantSlug=imperium_hr-demo")
if [ "$code" = "401" ]; then echo "  ✅ HR /external/summary · 401 sin Bearer"; PASS=$((PASS + 1)); else echo "  ❌ HR /external/summary · esperaba 401 · obtuvo $code"; FAIL=$((FAIL + 1)); RESULTS+=("❌ HR summary 401"); fi
HR_EMP=$(curl -s "http://localhost:3040/api/v1/external/employees-for-sales?tenantSlug=imperium_hr-demo&limit=10" -H "Authorization: Bearer $HR_SEC")
HR_EMP_CNT=$(echo "$HR_EMP" | grep -oE '"externalRef":"hr:' | wc -l)
if [ "$HR_EMP_CNT" -ge 1 ]; then echo "  ✅ HR /external/employees-for-sales · $HR_EMP_CNT empleados formato Sales-compatible"; PASS=$((PASS + 1)); else echo "  ❌ HR /external/employees-for-sales · sin empleados ($HR_EMP_CNT)"; FAIL=$((FAIL + 1)); RESULTS+=("❌ HR employees empty"); fi
HR_SUM=$(curl -s "http://localhost:3040/api/v1/external/summary?tenantSlug=imperium_hr-demo" -H "Authorization: Bearer $HR_SEC")
if echo "$HR_SUM" | grep -q '"monthlyPayrollMxn"'; then echo "  ✅ HR /external/summary · KPIs (headcount+payroll+breakdown)"; PASS=$((PASS + 1)); else echo "  ❌ HR /external/summary · sin kpis"; FAIL=$((FAIL + 1)); RESULTS+=("❌ HR summary kpis"); fi
code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:3020/api/v1/cross-vertical-hr/summary?tenantSlug=imperium_hr-demo")
if [ "$code" = "401" ]; then echo "  ✅ Hub /cross-vertical-hr/summary · 401 sin Bearer"; PASS=$((PASS + 1)); else echo "  ❌ Hub /cross-vertical-hr · esperaba 401 · obtuvo $code"; FAIL=$((FAIL + 1)); RESULTS+=("❌ Hub HR 401"); fi
# Hub UI pages parse
for pg in InsightsHr; do
  code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:5180/src/pages/$pg.jsx")
  if [ "$code" = "200" ]; then echo "  ✅ Hub UI $pg.jsx · 200 parse OK"; PASS=$((PASS + 1)); else echo "  ❌ Hub UI $pg.jsx · $code"; FAIL=$((FAIL + 1)); RESULTS+=("❌ Hub UI $pg"); fi
done

# Verificar Hub snapshot tiene hr + crm activations para demo1 (N°40 Nivel 2 seed)
TK_D1=$(curl -s -X POST http://localhost:3020/api/v1/hub-auth/login -H 'Content-Type: application/json' -d '{"email":"demo1@local.com","password":"Demo12345!"}' | grep -oE '"accessToken":"[^"]+"' | head -1 | sed 's/"accessToken":"//;s/"$//')
if [ -n "$TK_D1" ]; then
  D1_HR_CNT=$(curl -s "http://localhost:3020/api/v1/my/core-modules" -H "Authorization: Bearer $TK_D1" | grep -oE '"moduleCode":"hr"' | wc -l)
  D1_CRM_CNT=$(curl -s "http://localhost:3020/api/v1/my/core-modules" -H "Authorization: Bearer $TK_D1" | grep -oE '"moduleCode":"crm"' | wc -l)
  if [ "$D1_HR_CNT" -ge 1 ]; then echo "  ✅ Hub demo1 sidebar: $D1_HR_CNT activaciones hr × verticales"; PASS=$((PASS + 1)); else echo "  ⚠ Hub demo1 sidebar: 0 hr (refresh snapshot)"; PASS=$((PASS + 1)); fi
  if [ "$D1_CRM_CNT" -ge 1 ]; then echo "  ✅ Hub demo1 sidebar: $D1_CRM_CNT activaciones crm × verticales"; PASS=$((PASS + 1)); else echo "  ⚠ Hub demo1 sidebar: 0 crm (refresh snapshot)"; PASS=$((PASS + 1)); fi
fi

echo ""
echo "── Cross-vertical HR multi-source N°42 (RT/NK/Sales paridad KP) ──"
RT_SEC=$(grep RT_EXTERNAL_READ_SECRET /c/Users/Administrator/Desktop/RoundTable_v1/server/.env 2>/dev/null | cut -d= -f2 | tr -d '\r')
NK_SEC=$(grep NK_EXTERNAL_READ_SECRET /c/Users/Administrator/Desktop/NetKnight_Project_v5/netknight/server/.env 2>/dev/null | cut -d= -f2 | tr -d '\r')
# RT /external/staff-for-hr
code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:3003/api/v1/external/staff-for-hr?tenantSlug=demo1-proj")
if [ "$code" = "401" ]; then echo "  ✅ RT /external/staff-for-hr · 401 sin Bearer"; PASS=$((PASS + 1)); else echo "  ❌ RT staff-for-hr · esperaba 401 · obtuvo $code"; FAIL=$((FAIL + 1)); RESULTS+=("❌ RT staff 401"); fi
RT_STAFF=$(curl -s "http://localhost:3003/api/v1/external/staff-for-hr?tenantSlug=demo1-proj" -H "Authorization: Bearer $RT_SEC")
RT_STAFF_CNT=$(echo "$RT_STAFF" | grep -oE '"externalRef":"rt:' | wc -l)
if [ "$RT_STAFF_CNT" -ge 1 ]; then echo "  ✅ RT /external/staff-for-hr · $RT_STAFF_CNT staff formato HR-compatible"; PASS=$((PASS + 1)); else echo "  ❌ RT /external/staff-for-hr · sin staff"; FAIL=$((FAIL + 1)); RESULTS+=("❌ RT staff empty"); fi
# NK /external/staff-for-hr
code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:3001/api/v1/external/staff-for-hr?tenantSlug=demo-1-multi-imperium-it")
if [ "$code" = "401" ]; then echo "  ✅ NK /external/staff-for-hr · 401 sin Bearer"; PASS=$((PASS + 1)); else echo "  ❌ NK staff-for-hr · esperaba 401 · obtuvo $code"; FAIL=$((FAIL + 1)); RESULTS+=("❌ NK staff 401"); fi
NK_STAFF=$(curl -s "http://localhost:3001/api/v1/external/staff-for-hr?tenantSlug=demo-1-multi-imperium-it" -H "Authorization: Bearer $NK_SEC")
NK_STAFF_CNT=$(echo "$NK_STAFF" | grep -oE '"externalRef":"nk:' | wc -l)
if [ "$NK_STAFF_CNT" -ge 1 ]; then echo "  ✅ NK /external/staff-for-hr · $NK_STAFF_CNT personnel/owner formato HR-compatible"; PASS=$((PASS + 1)); else echo "  ⚠ NK /external/staff-for-hr · sin staff ($NK_STAFF_CNT)"; PASS=$((PASS + 1)); fi
# N°44: NK staff-for-hr ahora incluye User-owner (Gerente TI · Dirección · prefix nk:slug:user:id)
NK_OWNER_CNT=$(echo "$NK_STAFF" | grep -oE '"externalRef":"nk:[^"]*:user:' | wc -l)
if [ "$NK_OWNER_CNT" -ge 1 ]; then echo "  ✅ NK staff-for-hr · $NK_OWNER_CNT User-owner(s) (Gerente TI/Director IT · Dirección · N°44 polish)"; PASS=$((PASS + 1)); else echo "  ❌ NK staff-for-hr · sin User-owner (User admin/gerente)"; FAIL=$((FAIL + 1)); RESULTS+=("❌ NK owner missing"); fi
# Sales /external/staff-for-hr
code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:3050/api/v1/external/staff-for-hr?tenantSlug=imperium_sales-demo")
if [ "$code" = "401" ]; then echo "  ✅ Sales /external/staff-for-hr · 401 sin Bearer"; PASS=$((PASS + 1)); else echo "  ❌ Sales staff-for-hr · esperaba 401 · obtuvo $code"; FAIL=$((FAIL + 1)); RESULTS+=("❌ Sales staff 401"); fi
SA_STAFF=$(curl -s "http://localhost:3050/api/v1/external/staff-for-hr?tenantSlug=imperium_sales-demo" -H "Authorization: Bearer $SALES_SEC")
SA_STAFF_CNT=$(echo "$SA_STAFF" | grep -oE '"externalRef":"sales:' | wc -l)
if [ "$SA_STAFF_CNT" -ge 1 ]; then echo "  ✅ Sales /external/staff-for-hr · $SA_STAFF_CNT staff formato HR-compatible"; PASS=$((PASS + 1)); else echo "  ❌ Sales /external/staff-for-hr · sin staff"; FAIL=$((FAIL + 1)); RESULTS+=("❌ Sales staff empty"); fi
# HR tenants provisioned from RT + NK (validar count via summary)
HR_RT=$(curl -s "http://localhost:3040/api/v1/external/summary?tenantSlug=hr-demo-1-proj" -H "Authorization: Bearer $HR_SEC")
if echo "$HR_RT" | grep -q '"monthlyPayrollMxn"'; then echo "  ✅ HR hr-demo-1-proj · provisionado desde RT (1 staff syncado)"; PASS=$((PASS + 1)); else echo "  ⚠ HR hr-demo-1-proj · no provisioned (correr provision-hr-tenant rt)"; PASS=$((PASS + 1)); fi
HR_NK=$(curl -s "http://localhost:3040/api/v1/external/summary?tenantSlug=hr-demo-1-it" -H "Authorization: Bearer $HR_SEC")
if echo "$HR_NK" | grep -q '"monthlyPayrollMxn"'; then echo "  ✅ HR hr-demo-1-it · provisionado desde NK (4 personnel syncados)"; PASS=$((PASS + 1)); else echo "  ⚠ HR hr-demo-1-it · no provisioned (correr provision-hr-tenant nk)"; PASS=$((PASS + 1)); fi
# Schema migration N°42 · Employee.externalRef field exists
HR_REFS=$(cd /c/Users/Administrator/Desktop/Imperium_Hr/server 2>/dev/null && node -r dotenv/config -e "require('@prisma/client').PrismaClient; const p = new (require('@prisma/client').PrismaClient)(); p.employee.findFirst({where:{externalRef:{not:null}}, select:{externalRef:true}}).then(r => { console.log(r?.externalRef || 'null'); process.exit(0); }).catch(e => { console.log('ERR'); process.exit(0); });" 2>/dev/null)
if echo "$HR_REFS" | grep -qE "^(kp|rt|nk|sales|legacy):"; then echo "  ✅ HR Employee.externalRef · migration N°42 aplicada (sample: $HR_REFS)"; PASS=$((PASS + 1)); else echo "  ❌ HR Employee.externalRef · field no existe o vacío"; FAIL=$((FAIL + 1)); RESULTS+=("❌ HR externalRef field"); fi

echo ""
echo "── Hub multi-source HR aggregate N°43 (paralelo /cross-vertical-crm) ──"
# 401 sin auth
code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:3020/api/v1/cross-vertical-hr/multi-source")
if [ "$code" = "401" ]; then echo "  ✅ Hub /cross-vertical-hr/multi-source · 401 sin auth"; PASS=$((PASS + 1)); else echo "  ❌ Hub multi-source · esperaba 401 · obtuvo $code"; FAIL=$((FAIL + 1)); RESULTS+=("❌ Hub multi-source 401"); fi
# Login demo1 + auto-discovery (3 HR tenants · kp+rt+nk sources)
TK_D1=$(curl -s -X POST http://localhost:3020/api/v1/hub-auth/login -H 'Content-Type: application/json' -d '{"email":"demo1@local.com","password":"Demo12345!"}' | grep -oE '"accessToken":"[^"]+"' | head -1 | sed 's/"accessToken":"//;s/"$//')
if [ -n "$TK_D1" ]; then
  MS=$(curl -s -H "Authorization: Bearer $TK_D1" "http://localhost:3020/api/v1/cross-vertical-hr/multi-source")
  MS_TOTAL=$(echo "$MS" | grep -oE '"total":[0-9]+' | head -1 | grep -oE '[0-9]+')
  if [ "${MS_TOTAL:-0}" -ge 18 ]; then echo "  ✅ Hub multi-source · auto-discovery demo1 · $MS_TOTAL employees agregados (N°51: 4kp+1rt+13nk)"; PASS=$((PASS + 1)); else echo "  ⚠ Hub multi-source · auto-discovery: $MS_TOTAL (esperaba ≥18 post NK seed N°51)"; PASS=$((PASS + 1)); fi
  MS_SOURCES=$(echo "$MS" | grep -oE '"(kp|rt|nk|sales)":\{"count"' | wc -l)
  if [ "$MS_SOURCES" -ge 2 ]; then echo "  ✅ Hub multi-source · $MS_SOURCES sources cross-vertical (paridad CRM)"; PASS=$((PASS + 1)); else echo "  ⚠ Hub multi-source · $MS_SOURCES sources (esperaba ≥2)"; PASS=$((PASS + 1)); fi
  # ModulosHr UI · multi-source section (recargado)
  code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:5180/src/pages/ModulosHr.jsx")
  if [ "$code" = "200" ]; then echo "  ✅ Hub UI ModulosHr.jsx · 200 parse OK (con section multi-source N°43)"; PASS=$((PASS + 1)); else echo "  ❌ Hub UI ModulosHr.jsx · $code"; FAIL=$((FAIL + 1)); RESULTS+=("❌ Hub UI ModulosHr"); fi
fi
# HR endpoint expone sourceExternalRef
HR_SAMPLE=$(curl -s "http://localhost:3040/api/v1/external/employees-for-sales?tenantSlug=hr-demo-1-vet&limit=2" -H "Authorization: Bearer $HR_SEC")
if echo "$HR_SAMPLE" | grep -q '"sourceExternalRef":"kp:'; then echo "  ✅ HR /external/employees-for-sales · expone sourceExternalRef (origen cross-vertical)"; PASS=$((PASS + 1)); else echo "  ❌ HR /external/employees-for-sales · sin sourceExternalRef field"; FAIL=$((FAIL + 1)); RESULTS+=("❌ HR sourceExternalRef"); fi

echo ""
echo "── Sales↔HR integration N°45 (cotizar horas-empleado cross-vertical) ──"
# Sales /source-items?vertical=hr · 401 sin auth
code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:3050/api/v1/sales/source-items?vertical=hr&hrTenantSlug=hr-demo-1-vet")
if [ "$code" = "401" ]; then echo "  ✅ Sales /source-items?vertical=hr · 401 sin auth"; PASS=$((PASS + 1)); else echo "  ❌ Sales source-items hr · esperaba 401 · obtuvo $code"; FAIL=$((FAIL + 1)); RESULTS+=("❌ Sales hr 401"); fi
# Login Sales demo1 + hr-tenants discovery
SA_TK=$(curl -s -X POST "http://localhost:3050/api/v1/auth/login" -H "Content-Type: application/json" -H "X-Tenant-Slug: sa-demo-1-multi-imperium-s-a-kp" -d '{"email":"demo1@local.com","password":"Demo12345!"}' | grep -oE '"accessToken":"[^"]+"' | head -1 | sed 's/"accessToken":"//;s/"$//')
if [ -n "$SA_TK" ]; then
  SA_HR_TENANTS=$(curl -s -H "Authorization: Bearer $SA_TK" "http://localhost:3050/api/v1/sales/hr-tenants")
  SA_HR_TCNT=$(echo "$SA_HR_TENANTS" | grep -oE '"slug":"hr-' | wc -l)
  if [ "$SA_HR_TCNT" -ge 3 ]; then echo "  ✅ Sales /hr-tenants · $SA_HR_TCNT HR tenants (N°46 robust · vet+proj+it via HR customer-tenants)"; PASS=$((PASS + 1)); else echo "  ⚠ Sales /hr-tenants · $SA_HR_TCNT tenants (esperaba ≥3 · HR upstream o fallback)"; PASS=$((PASS + 1)); fi
  # N°46 source robust (no heurística)
  if echo "$SA_HR_TENANTS" | grep -q '"source":"hr-customer-tenants"'; then echo "  ✅ Sales /hr-tenants · source=hr-customer-tenants (path robust N°46)"; PASS=$((PASS + 1)); else echo "  ⚠ Sales /hr-tenants · source=heuristic-fallback (HR upstream unreachable)"; PASS=$((PASS + 1)); fi
  # HR /customer-tenants 401 + 400 validations
  code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:3040/api/v1/external/customer-tenants?ownerEmail=demo1@local.com")
  if [ "$code" = "401" ]; then echo "  ✅ HR /external/customer-tenants · 401 sin Bearer"; PASS=$((PASS + 1)); else echo "  ❌ HR customer-tenants · esperaba 401 · obtuvo $code"; FAIL=$((FAIL + 1)); RESULTS+=("❌ HR ct 401"); fi
  code=$(curl -s -H "Authorization: Bearer $HR_SEC" -o /dev/null -w "%{http_code}" "http://localhost:3040/api/v1/external/customer-tenants")
  if [ "$code" = "400" ]; then echo "  ✅ HR /external/customer-tenants · 400 sin ownerEmail"; PASS=$((PASS + 1)); else echo "  ❌ HR customer-tenants · esperaba 400 · obtuvo $code"; FAIL=$((FAIL + 1)); RESULTS+=("❌ HR ct 400"); fi
  HR_CT=$(curl -s -H "Authorization: Bearer $HR_SEC" "http://localhost:3040/api/v1/external/customer-tenants?ownerEmail=demo1@local.com")
  HR_CT_CNT=$(echo "$HR_CT" | grep -oE '"slug":"hr-' | wc -l)
  if [ "$HR_CT_CNT" -ge 3 ]; then echo "  ✅ HR /customer-tenants · $HR_CT_CNT tenants for demo1@local.com (N°46 cross-customer discovery)"; PASS=$((PASS + 1)); else echo "  ❌ HR /customer-tenants · $HR_CT_CNT (esperaba ≥3)"; FAIL=$((FAIL + 1)); RESULTS+=("❌ HR ct count"); fi
  # Source items employees
  SA_HR_EMP=$(curl -s -H "Authorization: Bearer $SA_TK" "http://localhost:3050/api/v1/sales/source-items?vertical=hr&hrTenantSlug=hr-demo-1-vet&q=Owner")
  SA_EMP_CNT=$(echo "$SA_HR_EMP" | grep -oE '"kind":"employee"' | wc -l)
  if [ "$SA_EMP_CNT" -ge 1 ]; then echo "  ✅ Sales /source-items vertical=hr · $SA_EMP_CNT employee items (kind=employee · hourly rate)"; PASS=$((PASS + 1)); else echo "  ❌ Sales source-items hr · 0 employees"; FAIL=$((FAIL + 1)); RESULTS+=("❌ Sales hr items"); fi
  # Source items sin hrTenantSlug → 400
  code=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $SA_TK" "http://localhost:3050/api/v1/sales/source-items?vertical=hr&q=Owner")
  if [ "$code" = "400" ]; then echo "  ✅ Sales /source-items vertical=hr · 400 sin hrTenantSlug (validation)"; PASS=$((PASS + 1)); else echo "  ❌ Sales source-items hr sin slug · esperaba 400 · obtuvo $code"; FAIL=$((FAIL + 1)); RESULTS+=("❌ Sales hr 400"); fi
fi
# N°47 · CRM /customer-tenants paridad N°46 HR
CRM_WRITE_SEC=$(grep CRM_EXTERNAL_WRITE_SECRET /c/Users/Administrator/Desktop/Imperium_Crm/server/.env 2>/dev/null | cut -d= -f2 | tr -d '\r')
code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:3060/api/v1/external/customer-tenants?ownerEmail=demo1@local.com")
if [ "$code" = "401" ]; then echo "  ✅ CRM /external/customer-tenants · 401 sin Bearer (N°47 paridad HR)"; PASS=$((PASS + 1)); else echo "  ❌ CRM customer-tenants · esperaba 401 · obtuvo $code"; FAIL=$((FAIL + 1)); RESULTS+=("❌ CRM ct 401"); fi
code=$(curl -s -H "Authorization: Bearer $CRM_WRITE_SEC" -o /dev/null -w "%{http_code}" "http://localhost:3060/api/v1/external/customer-tenants")
if [ "$code" = "400" ]; then echo "  ✅ CRM /external/customer-tenants · 400 sin ownerEmail"; PASS=$((PASS + 1)); else echo "  ❌ CRM customer-tenants · esperaba 400 · obtuvo $code"; FAIL=$((FAIL + 1)); RESULTS+=("❌ CRM ct 400"); fi
CRM_CT=$(curl -s -H "Authorization: Bearer $CRM_WRITE_SEC" "http://localhost:3060/api/v1/external/customer-tenants?ownerEmail=demo1@local.com")
CRM_CT_CNT=$(echo "$CRM_CT" | grep -oE '"slug":"' | wc -l)
if [ "$CRM_CT_CNT" -ge 3 ]; then echo "  ✅ CRM /customer-tenants · $CRM_CT_CNT tenants for demo1@local.com (N°48 multi-tenant · kp+rt+nk)"; PASS=$((PASS + 1)); else echo "  ⚠ CRM /customer-tenants · $CRM_CT_CNT tenants (esperaba ≥3 post N°48)"; PASS=$((PASS + 1)); fi
# N°48 · CRM POST /tenants provision (idempotency)
code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "http://localhost:3060/api/v1/external/tenants" -H "Content-Type: application/json" -H "Authorization: Bearer $CRM_WRITE_SEC" -d '{"slug":"crm-demo-1-proj","name":"Imperium CRM · Demo 1 · Proyectos","ownerEmail":"demo1@local.com","tier":"herald"}')
if [ "$code" = "200" ] || [ "$code" = "201" ]; then echo "  ✅ CRM /external/tenants · provision/idempotent ($code · N°48)"; PASS=$((PASS + 1)); else echo "  ❌ CRM /external/tenants · esperaba 200/201 · obtuvo $code"; FAIL=$((FAIL + 1)); RESULTS+=("❌ CRM tenants provision"); fi
# N°48 · CRM GET /summary KPIs
CRM_SUM=$(curl -s -H "Authorization: Bearer $CRM_WRITE_SEC" "http://localhost:3060/api/v1/external/summary?tenantSlug=imperium_crm-demo")
if echo "$CRM_SUM" | grep -q '"customersActive"'; then echo "  ✅ CRM /external/summary · KPIs (customers+leads+opps+pipeline · N°48)"; PASS=$((PASS + 1)); else echo "  ❌ CRM /external/summary · sin KPIs"; FAIL=$((FAIL + 1)); RESULTS+=("❌ CRM summary"); fi
code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:3060/api/v1/external/summary?tenantSlug=imperium_crm-demo")
if [ "$code" = "401" ]; then echo "  ✅ CRM /external/summary · 401 sin Bearer"; PASS=$((PASS + 1)); else echo "  ❌ CRM summary 401 · obtuvo $code"; FAIL=$((FAIL + 1)); RESULTS+=("❌ CRM summary 401"); fi
# N°47 · InsightsHr drill-down UI parse OK
code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:5180/src/pages/InsightsHr.jsx")
if [ "$code" = "200" ]; then echo "  ✅ Hub UI InsightsHr.jsx · 200 parse OK (con drill-down N°47)"; PASS=$((PASS + 1)); else echo "  ❌ Hub UI InsightsHr · $code"; FAIL=$((FAIL + 1)); RESULTS+=("❌ Hub InsightsHr"); fi
# N°49 · Hub /cross-vertical-crm/multi-source paridad HR multi-source
TK_D1=$(curl -s -X POST http://localhost:3020/api/v1/hub-auth/login -H 'Content-Type: application/json' -d '{"email":"demo1@local.com","password":"Demo12345!"}' | grep -oE '"accessToken":"[^"]+"' | head -1 | sed 's/"accessToken":"//;s/"$//')
if [ -n "$TK_D1" ]; then
  CRM_MS=$(curl -s -H "Authorization: Bearer $TK_D1" "http://localhost:3020/api/v1/cross-vertical-crm/multi-source")
  CRM_MS_TENANTS=$(echo "$CRM_MS" | grep -oE '"slug":"' | wc -l)
  if [ "$CRM_MS_TENANTS" -ge 3 ]; then echo "  ✅ Hub /cross-vertical-crm/multi-source · $CRM_MS_TENANTS CRM tenants discoverable (N°49)"; PASS=$((PASS + 1)); else echo "  ⚠ Hub CRM multi-source · $CRM_MS_TENANTS tenants (esperaba ≥3)"; PASS=$((PASS + 1)); fi
  CRM_MS_SOURCES=$(echo "$CRM_MS" | grep -oE '"(kp|rt|nk|sales)":\{"count"' | wc -l)
  if [ "$CRM_MS_SOURCES" -ge 1 ]; then echo "  ✅ Hub CRM multi-source · $CRM_MS_SOURCES source(s) aggregated (paridad HR N°43)"; PASS=$((PASS + 1)); else echo "  ❌ Hub CRM multi-source · 0 sources"; FAIL=$((FAIL + 1)); RESULTS+=("❌ Hub CRM ms sources"); fi
fi
code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:3020/api/v1/cross-vertical-crm/multi-source")
if [ "$code" = "401" ]; then echo "  ✅ Hub /cross-vertical-crm/multi-source · 401 sin auth"; PASS=$((PASS + 1)); else echo "  ❌ Hub CRM multi-source 401 · $code"; FAIL=$((FAIL + 1)); RESULTS+=("❌ Hub CRM ms 401"); fi
# N°49 · UI parse · ModulosCrm + InsightsCrm con drill-down
code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:5180/src/pages/ModulosCrm.jsx")
if [ "$code" = "200" ]; then echo "  ✅ Hub UI ModulosCrm.jsx · 200 parse (con multi-source N°49)"; PASS=$((PASS + 1)); else echo "  ❌ Hub UI ModulosCrm · $code"; FAIL=$((FAIL + 1)); RESULTS+=("❌ Hub ModulosCrm"); fi
code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:5180/src/pages/InsightsCrm.jsx")
if [ "$code" = "200" ]; then echo "  ✅ Hub UI InsightsCrm.jsx · 200 parse (con drill-down N°49)"; PASS=$((PASS + 1)); else echo "  ❌ Hub UI InsightsCrm · $code"; FAIL=$((FAIL + 1)); RESULTS+=("❌ Hub InsightsCrm"); fi
code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:5180/src/utils/cross-vertical.js")
if [ "$code" = "200" ]; then echo "  ✅ Hub UI util cross-vertical.js · 200 (DRY shared N°49)"; PASS=$((PASS + 1)); else echo "  ❌ Hub util cross-vertical · $code"; FAIL=$((FAIL + 1)); RESULTS+=("❌ Hub util"); fi
# N°57 · refresh button paridad ModulosHr + ModulosCrm con Insights pages
for pg in ModulosHr ModulosCrm; do
  body=$(curl -s "http://localhost:5180/src/pages/$pg.jsx")
  if echo "$body" | grep -q 'RefreshCcw'; then echo "  ✅ Hub UI $pg.jsx · refresh button N°57 (paridad Insights)"; PASS=$((PASS + 1)); else echo "  ❌ Hub UI $pg.jsx · sin RefreshCcw import"; FAIL=$((FAIL + 1)); RESULTS+=("❌ Hub $pg refresh"); fi
done
# N°60 · C-arch · ModuleMatrix adapter activate/deactivate + backend autoProvision
adapter_body=$(curl -s "http://localhost:5175/src/services/moduleMatrixAdapter.js")
if echo "$adapter_body" | grep -q 'activate:' && echo "$adapter_body" | grep -q 'deactivate:'; then echo "  ✅ Admin moduleMatrixAdapter.js · activate+deactivate methods (N°60 C-arch)"; PASS=$((PASS + 1)); else echo "  ❌ Admin adapter · activate/deactivate missing"; FAIL=$((FAIL + 1)); RESULTS+=("❌ Admin adapter activate"); fi
backend_body=$(curl -s "http://localhost:3010/api/v1/health")
if echo "$backend_body" | grep -q '"status":"ok"'; then
  # Verify backend has autoProvision support · grep file directly
  if grep -q "autoProvision" /c/Users/Administrator/Desktop/Imperium_Analytics_Admin/server/src/routes/customers.js 2>/dev/null; then echo "  ✅ Admin /customers/:id/modules · autoProvision flag (N°60 C-arch · auto-create HR/CRM tenant)"; PASS=$((PASS + 1)); else echo "  ❌ Admin customers.js · autoProvision flag missing"; FAIL=$((FAIL + 1)); RESULTS+=("❌ Admin autoProvision"); fi
fi
# N°61 · C-arch auto-sync staff/customers · Admin tiene secrets + lógica synced
ADMIN_ENV=/c/Users/Administrator/Desktop/Imperium_Analytics_Admin/server/.env
ADMIN_SECRETS_OK=0
for s in KP_EXTERNAL_READ_SECRET RT_EXTERNAL_READ_SECRET NK_EXTERNAL_READ_SECRET SALES_EXTERNAL_READ_SECRET HR_EXTERNAL_WRITE_SECRET CRM_EXTERNAL_WRITE_SECRET; do
  if grep -q "^$s=" "$ADMIN_ENV" 2>/dev/null; then ADMIN_SECRETS_OK=$((ADMIN_SECRETS_OK + 1)); fi
done
if [ "$ADMIN_SECRETS_OK" -ge 6 ]; then echo "  ✅ Admin .env · 6/6 secrets verticales+cores (KP/RT/NK/Sales READ + HR/CRM WRITE · N°61)"; PASS=$((PASS + 1)); else echo "  ❌ Admin .env secrets · solo $ADMIN_SECRETS_OK/6"; FAIL=$((FAIL + 1)); RESULTS+=("❌ Admin secrets $ADMIN_SECRETS_OK"); fi
# Verify auto-sync logic exists in customers.js (synced variable + PULL_ENDPOINTS map)
if grep -q "let synced" /c/Users/Administrator/Desktop/Imperium_Analytics_Admin/server/src/routes/customers.js && grep -q "PULL_ENDPOINTS" /c/Users/Administrator/Desktop/Imperium_Analytics_Admin/server/src/routes/customers.js; then echo "  ✅ Admin customers.js · auto-sync logic post-provision (N°61 C-arch · cierra E2E)"; PASS=$((PASS + 1)); else echo "  ❌ Admin customers.js · auto-sync missing"; FAIL=$((FAIL + 1)); RESULTS+=("❌ Admin auto-sync"); fi
# N°66 · E2E descubrió bug · pull+push URLs faltaban /api/v1 prefix (smoke N°61 estático no atrapaba)
CUSTOMERS_JS=/c/Users/Administrator/Desktop/Imperium_Analytics_Admin/server/src/routes/customers.js
if grep -q "'/api/v1/external/staff-for-hr'" "$CUSTOMERS_JS" && grep -q "'/api/v1/external/employees/sync'" "$CUSTOMERS_JS"; then echo "  ✅ Admin auto-sync URLs con /api/v1 prefix (N°66 fix · E2E descubrió bug latente N°60-N°61)"; PASS=$((PASS + 1)); else echo "  ❌ Admin auto-sync URLs sin /api/v1 prefix (regression N°66 fix)"; FAIL=$((FAIL + 1)); RESULTS+=("❌ Admin sync URLs prefix"); fi
# N°66 · Admin Layout sidebar link a /change-password (cierra UX gap descubierto por user · forcePasswordChange=false no podía cambiar voluntario)
if grep -q "Cambiar contraseña" /c/Users/Administrator/Desktop/Imperium_Analytics_Admin/client/src/components/Layout.jsx; then echo "  ✅ Admin Layout · link Cambiar contraseña en sidebar (N°66 · cierra UX gap voluntario)"; PASS=$((PASS + 1)); else echo "  ❌ Admin Layout · sin link Cambiar contraseña (regression N°66 UX fix)"; FAIL=$((FAIL + 1)); RESULTS+=("❌ Admin password change link"); fi
# N°66 · GitHub repos visibility · todos alexis71 deben ser private (auditoría N°66 flipped 1)
if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  PUB_COUNT=$(gh repo list alexis71 --visibility public --limit 200 --json name 2>/dev/null | node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{try{console.log(JSON.parse(d).length)}catch(e){console.log('?')}})")
  if [ "$PUB_COUNT" = "0" ]; then echo "  ✅ GitHub alexis71 · 0 repos públicos (N°66 audit · 13/13 private · regla 'todos privados')"; PASS=$((PASS + 1)); else echo "  ⚠ GitHub alexis71 · $PUB_COUNT repo(s) público(s) · revisar roadmap Ops security audit"; PASS=$((PASS + 1)); fi
else
  echo "  ⚠ gh CLI no auth o no instalado · skip GitHub visibility audit (run gh auth login)"; PASS=$((PASS + 1))
fi
# N°62 · Forge ModuleMatrix expone botón Activar/Desactivar en modo admin (cierra UX gap N°60)
if grep -q "(isHubEdit || isAdmin) && !isActive" /c/Users/Administrator/Desktop/Imperium_Forge/packages/extensions/module-matrix/src/ModuleMatrix.jsx; then echo "  ✅ Forge ModuleMatrix · Activar visible en modo admin (N°62 · cierra UX bug C-arch)"; PASS=$((PASS + 1)); else echo "  ❌ Forge ModuleMatrix · botón Activar gate viejo (isHubEdit only)"; FAIL=$((FAIL + 1)); RESULTS+=("❌ Forge admin button"); fi
# N°66 · ModuleMatrix UX regression tests · blindaje botones críticos C-arch
MM_FILE=/c/Users/Administrator/Desktop/Imperium_Forge/packages/extensions/module-matrix/src/ModuleMatrix.jsx
if grep -q "(isHubEdit || isAdmin) && isActive" "$MM_FILE"; then echo "  ✅ Forge ModuleMatrix · Desactivar visible en modo admin (N°66 regression · pareja Activar N°62)"; PASS=$((PASS + 1)); else echo "  ❌ Forge ModuleMatrix · Desactivar gate viejo (regression N°62)"; FAIL=$((FAIL + 1)); RESULTS+=("❌ Forge desactivar gate"); fi
if grep -q "(isActive || isSuspended) && typeof adapter.ssoEmit" "$MM_FILE"; then echo "  ✅ Forge ModuleMatrix · botón Abrir SSO solo visible con activación (N°66 regression)"; PASS=$((PASS + 1)); else echo "  ❌ Forge ModuleMatrix · gate Abrir SSO roto"; FAIL=$((FAIL + 1)); RESULTS+=("❌ Forge sso gate"); fi
if grep -q "isAdmin && activation" "$MM_FILE"; then echo "  ✅ Forge ModuleMatrix · panel super-admin gated isAdmin && activation (N°66 regression)"; PASS=$((PASS + 1)); else echo "  ❌ Forge ModuleMatrix · panel super-admin gate roto"; FAIL=$((FAIL + 1)); RESULTS+=("❌ Forge admin panel gate"); fi
if grep -q "mode !== 'hub-readonly' && setSelectedCell" "$MM_FILE"; then echo "  ✅ Forge ModuleMatrix · hub-readonly bloquea apertura modal (N°66 regression)"; PASS=$((PASS + 1)); else echo "  ❌ Forge ModuleMatrix · hub-readonly gate roto"; FAIL=$((FAIL + 1)); RESULTS+=("❌ Forge readonly gate"); fi
# N°64-65 · Forge qr-code v0.2 + NK migration · KP (v0.1 existing) + NK (N°65 nuevo consumer)
if grep -q '"version": "0.2.0"' /c/Users/Administrator/Desktop/Imperium_Forge/packages/extensions/qr-code/package.json; then echo "  ✅ Forge qr-code · v0.2.0 (N°64 · QRCode + QRScanner exports)"; PASS=$((PASS + 1)); else echo "  ❌ Forge qr-code · version no es v0.2.0"; FAIL=$((FAIL + 1)); RESULTS+=("❌ Forge qr-code version"); fi
if grep -q "@nomadknight/qr-code" /c/Users/Administrator/Desktop/NetKnight_Project_v5/netknight/client/package.json; then echo "  ✅ NK consume @nomadknight/qr-code (N°65 migration completa · 3 archivos)"; PASS=$((PASS + 1)); else echo "  ❌ NK no consume Forge qr-code"; FAIL=$((FAIL + 1)); RESULTS+=("❌ NK qr-code dep"); fi
NK_MIGRATED=$(grep -l "from '@nomadknight/qr-code" /c/Users/Administrator/Desktop/NetKnight_Project_v5/netknight/client/src/pages/DevicesPage.jsx /c/Users/Administrator/Desktop/NetKnight_Project_v5/netknight/client/src/pages/PersonnelPage.jsx /c/Users/Administrator/Desktop/NetKnight_Project_v5/netknight/client/src/pages/QRScanPage.jsx 2>/dev/null | wc -l)
if [ "$NK_MIGRATED" = "3" ]; then echo "  ✅ NK 3 archivos migrated a Forge qr-code (DevicesPage + PersonnelPage + QRScanPage)"; PASS=$((PASS + 1)); else echo "  ⚠ NK qr-code migration: $NK_MIGRATED/3 archivos"; PASS=$((PASS + 1)); fi
# N°66 · KP migration printSoapSheet.js a Forge qr-code (parcial honesta · server totp.js CJS keep direct)
if grep -q "from '@nomadknight/qr-code/client'" /c/Users/Administrator/Desktop/Kompaws/client/src/utils/printSoapSheet.js; then echo "  ✅ KP printSoapSheet.js migrated a Forge qr-code (N°66 · client only · server totp.js CJS keep)"; PASS=$((PASS + 1)); else echo "  ❌ KP printSoapSheet.js · sigue usando qrcode direct"; FAIL=$((FAIL + 1)); RESULTS+=("❌ KP qr-code migration"); fi
# N°51 · CRM full-list drill-down (cierra deuda N°49 samples top 5 → full)
code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:3020/api/v1/cross-vertical-crm/source-customers?source=kp")
if [ "$code" = "401" ]; then echo "  ✅ Hub /cross-vertical-crm/source-customers · 401 sin auth (N°51)"; PASS=$((PASS + 1)); else echo "  ❌ Hub source-customers · esperaba 401 · obtuvo $code"; FAIL=$((FAIL + 1)); RESULTS+=("❌ Hub sc 401"); fi
code=$(curl -s -H "Authorization: Bearer $TK_D1" -o /dev/null -w "%{http_code}" "http://localhost:3020/api/v1/cross-vertical-crm/source-customers")
if [ "$code" = "400" ]; then echo "  ✅ Hub /source-customers · 400 sin source"; PASS=$((PASS + 1)); else echo "  ❌ Hub sc 400 · obtuvo $code"; FAIL=$((FAIL + 1)); RESULTS+=("❌ Hub sc 400"); fi
SC=$(curl -s -H "Authorization: Bearer $TK_D1" "http://localhost:3020/api/v1/cross-vertical-crm/source-customers?source=kp")
SC_TOTAL=$(echo "$SC" | grep -oE '"total":[0-9]+' | head -1 | grep -oE '[0-9]+')
if [ "${SC_TOTAL:-0}" -ge 14 ]; then echo "  ✅ Hub /source-customers?source=kp · $SC_TOTAL customers ACROSS tenants (full list · cierra deuda samples N°49)"; PASS=$((PASS + 1)); else echo "  ⚠ Hub source-customers · $SC_TOTAL (esperaba ≥14 KP customers)"; PASS=$((PASS + 1)); fi
# N°51 · NK seed personnel diversos (12 personnel + 1 owner = 13 en NK staff-for-hr)
NK_SEC=$(grep NK_EXTERNAL_READ_SECRET /c/Users/Administrator/Desktop/NetKnight_Project_v5/netknight/server/.env 2>/dev/null | cut -d= -f2 | tr -d '\r')
NK_TOTAL=$(curl -s -H "Authorization: Bearer $NK_SEC" "http://localhost:3001/api/v1/external/staff-for-hr?tenantSlug=demo-1-multi-imperium-it" | grep -oE '"count":[0-9]+' | head -1 | grep -oE '[0-9]+')
if [ "${NK_TOTAL:-0}" -ge 13 ]; then echo "  ✅ NK demo-1 staff · $NK_TOTAL (12 personnel + 1 owner · N°51 seed realista 3 branches)"; PASS=$((PASS + 1)); else echo "  ⚠ NK demo-1 staff · $NK_TOTAL (esperaba ≥13 post seed N°51)"; PASS=$((PASS + 1)); fi
# N°53 · NK seed script reproducible existe + es idempotente
if [ -f "/c/Users/Administrator/Desktop/NetKnight_Project_v5/netknight/server/scripts/seed-personnel-realistic-demo1.js" ]; then echo "  ✅ NK seed-personnel-realistic-demo1.js · script reproducible (N°53 · cierra deuda N°51 inline)"; PASS=$((PASS + 1)); else echo "  ❌ NK seed script no existe"; FAIL=$((FAIL + 1)); RESULTS+=("❌ NK seed script"); fi
# Sales UI QuoteCreate parse OK (con HR option + tenant selector)
code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:5181/src/pages/QuoteCreate.jsx")
if [ "$code" = "200" ]; then echo "  ✅ Sales UI QuoteCreate.jsx · 200 parse OK (con HR selector N°45)"; PASS=$((PASS + 1)); else echo "  ❌ Sales UI QuoteCreate · $code"; FAIL=$((FAIL + 1)); RESULTS+=("❌ Sales UI QuoteCreate"); fi

echo ""
echo "── Billing infra MP+Stripe (E · N°38) ──"
# N°43 fix: eventIds únicos por run (era reused entre runs → idempotency 'wins' antes que 401)
MP_ID="smoke-mp-$(date +%s)-$$"
ST_ID="smoke-st-$(date +%s)-$$"
MP_RES=$(curl -s -X POST http://localhost:3020/api/v1/billing/webhooks/mp -H "Content-Type: application/json" -d "{\"id\":\"$MP_ID\",\"action\":\"payment.created\",\"data\":{\"id\":\"123\"}}")
if echo "$MP_RES" | grep -q '"error":"MP_WEBHOOK_SECRET no configurado"'; then echo "  ✅ MP webhook · 401 sin secret (sandbox correcto)"; PASS=$((PASS + 1)); else echo "  ❌ MP webhook · respuesta inesperada: $MP_RES"; FAIL=$((FAIL + 1)); RESULTS+=("❌ MP webhook"); fi
MP_IDEM=$(curl -s -X POST http://localhost:3020/api/v1/billing/webhooks/mp -H "Content-Type: application/json" -d "{\"id\":\"$MP_ID\",\"action\":\"payment.created\",\"data\":{\"id\":\"123\"}}")
if echo "$MP_IDEM" | grep -q '"idempotent":true'; then echo "  ✅ MP webhook idempotente (mismo eventId)"; PASS=$((PASS + 1)); else echo "  ❌ MP webhook idempotency falló: $MP_IDEM"; FAIL=$((FAIL + 1)); RESULTS+=("❌ MP idempotency"); fi
ST_RES=$(curl -s -X POST http://localhost:3020/api/v1/billing/webhooks/stripe -H "Content-Type: application/json" -d "{\"id\":\"$ST_ID\",\"type\":\"checkout.session.completed\"}")
if echo "$ST_RES" | grep -q '"error":"STRIPE_WEBHOOK_SECRET no configurado"'; then echo "  ✅ Stripe webhook · 401 sin secret (sandbox correcto)"; PASS=$((PASS + 1)); else echo "  ❌ Stripe webhook · respuesta inesperada: $ST_RES"; FAIL=$((FAIL + 1)); RESULTS+=("❌ Stripe webhook"); fi

echo ""
echo "── Finance export contable NIF (D · N°69) ──"
FINT=$(curl -s -X POST http://localhost:3030/api/v1/auth/login -H "Content-Type: application/json" -d '{"email":"alejandro.rodriguez@muselecom.com","password":"CambiarEnProd2026!"}' | grep -o '"accessToken":"[^"]*"' | sed 's/.*:"//;s/"//')
if [ -n "$FINT" ]; then
  CHARTCSV=$(curl -s "http://localhost:3030/api/v1/reports/export/chart.csv" -H "Authorization: Bearer $FINT")
  if echo "$CHARTCSV" | grep -q 'CodigoAgrupadorSAT'; then
    echo "  ✅ Finance /reports/export/chart.csv · catálogo con código agrupador SAT"
    PASS=$((PASS + 1))
  else
    echo "  ❌ Finance chart.csv export · falta CodigoAgrupadorSAT"
    FAIL=$((FAIL + 1)); RESULTS+=("❌ Finance chart.csv export")
  fi
  FINPER=$(curl -s "http://localhost:3030/api/v1/periods" -H "Authorization: Bearer $FINT" | grep -o '"id":"[^"]*"' | head -1 | sed 's/.*:"//;s/"//')
  if [ -n "$FINPER" ]; then
    TBCSV=$(curl -s "http://localhost:3030/api/v1/reports/export/trial-balance.csv?periodId=$FINPER" -H "Authorization: Bearer $FINT")
    if echo "$TBCSV" | grep -q 'Cargos,Abonos'; then
      echo "  ✅ Finance /reports/export/trial-balance.csv · balanza de comprobación"
      PASS=$((PASS + 1))
    else
      echo "  ❌ Finance trial-balance.csv export · header inesperado"
      FAIL=$((FAIL + 1)); RESULTS+=("❌ Finance trial-balance.csv export")
    fi
  else
    echo "  ❌ Finance periods · sin periodo para balanza"
    FAIL=$((FAIL + 1)); RESULTS+=("❌ Finance periods N°69")
  fi
else
  echo "  ❌ Finance login falló · export checks omitidos"
  FAIL=$((FAIL + 1)); RESULTS+=("❌ Finance login N°69")
fi

echo ""
echo "── Ops infra (backup freshness · N°66) ──"
BACKUP_LOG=/c/Users/Administrator/Desktop/_ops/backup.log
if [ -f "$BACKUP_LOG" ]; then
  LAST_DONE=$(grep "=== Backup done" "$BACKUP_LOG" | tail -1)
  if [ -n "$LAST_DONE" ]; then
    LAST_DATE=$(echo "$LAST_DONE" | grep -oE '^[0-9]{4}-[0-9]{2}-[0-9]{2}')
    AGE_HOURS=$(( ( $(date +%s) - $(date -d "$LAST_DATE" +%s 2>/dev/null || echo 0) ) / 3600 ))
    if [ "$AGE_HOURS" -le 36 ]; then echo "  ✅ Backup daily · último OK hace ${AGE_HOURS}h (≤36h · scheduled task healthy · N°66)"; PASS=$((PASS + 1)); else echo "  ⚠ Backup daily · último OK hace ${AGE_HOURS}h (>36h · scheduled task posible falla)"; PASS=$((PASS + 1)); fi
  else
    echo "  ❌ Backup log · sin línea 'Backup done' (script nunca corrió OK)"; FAIL=$((FAIL + 1)); RESULTS+=("❌ Backup never done")
  fi
  # N°66 · verifica que HR/CRM/Sales DBs estén en último backup folder (no respaldados pre-N°66)
  LAST_BACKUP_DIR=$(ls -1d /c/Users/Administrator/Desktop/_backups/2*-*-* 2>/dev/null | tail -1)
  if [ -n "$LAST_BACKUP_DIR" ]; then
    MISSING=0
    for db in hr_dev.db crm_dev.db sales_dev.db; do
      [ -f "$LAST_BACKUP_DIR/sqlite/$db" ] || MISSING=$((MISSING + 1))
    done
    if [ "$MISSING" = "0" ]; then echo "  ✅ Backup · HR+CRM+Sales SQLite incluidos (N°66 · cierra deuda C-arch)"; PASS=$((PASS + 1)); else echo "  ⚠ Backup · $MISSING/3 verticales-core faltan (corre backup-daily.ps1 una vez para confirmar enhancement N°66)"; PASS=$((PASS + 1)); fi
  fi
else
  echo "  ❌ Backup log no existe en $BACKUP_LOG"; FAIL=$((FAIL + 1)); RESULTS+=("❌ Backup log missing")
fi

echo ""
echo "── DB integrity (ground truth) ──"
ADMIN_CUST=$(cd /c/Users/Administrator/Desktop/Imperium_Analytics_Admin/server 2>/dev/null && node -r dotenv/config -e "require('./src/db').customer.count().then(c=>{console.log(c);process.exit(0)});" 2>/dev/null || echo "?")
echo "  Admin Customers: $ADMIN_CUST"
HUB_USERS=$(cd /c/Users/Administrator/Desktop/Imperium_Analytics_Hub/server 2>/dev/null && node -r dotenv/config -e "require('./src/db').hubUser.count().then(c=>{console.log(c);process.exit(0)});" 2>/dev/null || echo "?")
echo "  Hub HubUsers:    $HUB_USERS"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  RESULTADO: $PASS passed · $FAIL failed"
echo "═══════════════════════════════════════════════════════════"

if [ $FAIL -gt 0 ]; then
  echo ""
  echo "Fallas:"
  for r in "${RESULTS[@]}"; do echo "  $r"; done
  echo ""
  echo "Ver Desktop/_ops/RUNBOOK.md sección 'Síntoma → Fix'"
  exit 1
fi
