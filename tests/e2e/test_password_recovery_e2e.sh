#!/bin/bash
# E2E real de recuperación de contraseña (F14) contra el stack vivo:
# GoTrue + Mailpit, sin mocks. Requiere el stack arriba (docker compose up).
set -e
GATEWAY="http://localhost:54321"
MAILPIT="http://localhost:8025"
EMAIL="pwtest-$(date +%s)@nutrifit.local"
OLD_PW="OldPass123!"
NEW_PW="NuevaClave456!"

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; exit 1; }

# 1. Signup con contraseña vieja
code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$GATEWAY/auth/v1/signup" \
  -H "Content-Type: application/json" -d "{\"email\":\"$EMAIL\",\"password\":\"$OLD_PW\"}")
[ "$code" = "200" ] && pass "AC-signup: usuario de prueba creado" || fail "signup devolvió $code"

# 2. Disparar recuperación real
code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$GATEWAY/auth/v1/recover" \
  -H "Content-Type: application/json" -d "{\"email\":\"$EMAIL\"}")
[ "$code" = "200" ] && pass "AC4a: /auth/v1/recover disparó el correo (200)" || fail "recover devolvió $code"

sleep 1
# 3. Extraer el correo REAL de Mailpit (no mock)
MSG_ID=$(curl -s "$MAILPIT/api/v1/search?query=to:$EMAIL" | python -c "import json,sys; d=json.load(sys.stdin); print(d['messages'][0]['ID'] if d.get('messages') else '')")
[ -n "$MSG_ID" ] && pass "AC4b: correo real capturado en Mailpit" || fail "no se encontró el correo en Mailpit"

OTP=$(curl -s "$MAILPIT/api/v1/message/$MSG_ID" | python -c "
import json,sys,re
d = json.load(sys.stdin)
m = re.search(r'code: (\d+)', d.get('Text',''))
print(m.group(1) if m else '')
")
[ -n "$OTP" ] && pass "AC4c: código OTP extraído del correo real" || fail "no se pudo extraer el OTP"

# 4. Verificar el OTP -> sesión de recuperación real
ACCESS_TOKEN=$(curl -s -X POST "$GATEWAY/auth/v1/verify" -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"token\":\"$OTP\",\"type\":\"recovery\"}" | python -c "import json,sys; print(json.load(sys.stdin).get('access_token',''))")
[ -n "$ACCESS_TOKEN" ] && pass "AC4d: sesión de recuperación obtenida" || fail "verify no devolvió access_token"

# 5. Cambiar la contraseña con esa sesión
code=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "$GATEWAY/auth/v1/user" \
  -H "Authorization: Bearer $ACCESS_TOKEN" -H "Content-Type: application/json" -d "{\"password\":\"$NEW_PW\"}")
[ "$code" = "200" ] && pass "AC4e: contraseña actualizada" || fail "PUT /user devolvió $code"

# 6. Login con la contraseña NUEVA debe funcionar
code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$GATEWAY/auth/v1/token?grant_type=password" \
  -H "Content-Type: application/json" -d "{\"email\":\"$EMAIL\",\"password\":\"$NEW_PW\"}")
[ "$code" = "200" ] && pass "AC4f: login con contraseña nueva funciona" || fail "login con nueva devolvió $code"

# 7. Login con la contraseña VIEJA ya no debe funcionar
code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$GATEWAY/auth/v1/token?grant_type=password" \
  -H "Content-Type: application/json" -d "{\"email\":\"$EMAIL\",\"password\":\"$OLD_PW\"}")
[ "$code" = "400" ] && pass "AC4g: login con contraseña vieja ya NO funciona" || fail "login con vieja devolvió $code (esperado 400)"

echo "TODOS LOS TESTS E2E DE RECUPERACIÓN DE CONTRASEÑA (F14) PASARON"
