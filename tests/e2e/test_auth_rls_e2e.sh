#!/usr/bin/env bash
# Test de Simulación de Usuario — T10.2.1 + T10.2.2 (Fase F10, Autenticación Real).
#
# Simula el flujo real de dos usuarios finales contra el stack levantado
# (gateway :54321 -> GoTrue /auth/v1 + PostgREST /rest/v1):
#   1) Ambos se registran (signup) via GoTrue y obtienen un JWT real.
#   2) A crea su perfil y un registro de comida.
#   3) A solo ve su propia fila; B no ve nada de A (aislamiento RLS real,
#      no simulado con SET request.jwt.claims).
#   4) El catálogo de ejercicios sigue siendo público (sin token).
#
# Requiere el stack arriba: docker compose up -d (gateway en localhost:54321).
# Uso: bash tests/e2e/test_auth_rls_e2e.sh

set -euo pipefail

GATEWAY="http://localhost:54321"
FAIL=0

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAIL=1; }

# Emails únicos por corrida para poder re-ejecutar el test sin colisionar.
STAMP=$(date +%s%N)
EMAIL_A="e2e-rls-a-${STAMP}@nutrifit.local"
EMAIL_B="e2e-rls-b-${STAMP}@nutrifit.local"

signup() {
  curl -s -X POST "$GATEWAY/auth/v1/signup" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$1\",\"password\":\"password123\"}"
}

RESP_A=$(signup "$EMAIL_A")
RESP_B=$(signup "$EMAIL_B")

TOKEN_A=$(echo "$RESP_A" | python -c "import sys,json;print(json.load(sys.stdin)['access_token'])")
TOKEN_B=$(echo "$RESP_B" | python -c "import sys,json;print(json.load(sys.stdin)['access_token'])")
SUB_A=$(echo "$RESP_A" | python -c "import sys,json;print(json.load(sys.stdin)['user']['id'])")

[ -n "$TOKEN_A" ] && [ -n "$TOKEN_B" ] && pass "AC-signup: ambos usuarios obtuvieron access_token real" \
  || fail "AC-signup: no se obtuvo access_token para A y/o B"

# --- A crea su perfil ---
INSERT_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$GATEWAY/rest/v1/users" \
  -H "Authorization: Bearer $TOKEN_A" -H "Content-Type: application/json" \
  -d "{\"id\":\"$SUB_A\",\"name\":\"A\",\"birth_date\":\"1990-01-01\",\"gender\":\"M\",\"height_cm\":170}")
[ "$INSERT_STATUS" = "201" ] && pass "AC1: A pudo crear su propio perfil (201)" \
  || fail "AC1: INSERT de perfil propio devolvió $INSERT_STATUS (esperado 201)"

# --- A crea un food_log ---
curl -s -o /dev/null -X POST "$GATEWAY/rest/v1/food_logs" \
  -H "Authorization: Bearer $TOKEN_A" -H "Content-Type: application/json" -H "Content-Profile: nutrition" \
  -d "{\"user_id\":\"$SUB_A\",\"meal_type\":\"breakfast\",\"food_name\":\"Avena\",\"calories\":300,\"protein_g\":10,\"carbs_g\":50,\"fat_g\":5,\"serving_size_g\":100}"

# --- AC2: A ve exactamente su fila en users ---
BODY_A=$(curl -s "$GATEWAY/rest/v1/users" -H "Authorization: Bearer $TOKEN_A")
COUNT_A=$(echo "$BODY_A" | python -c "import sys,json;print(len(json.load(sys.stdin)))")
[ "$COUNT_A" = "1" ] && pass "AC2: A ve exactamente 1 fila (la propia) en users" \
  || fail "AC2: A vio $COUNT_A filas en users (esperado 1)"

# --- AC3: B no ve el perfil de A ---
BODY_B=$(curl -s "$GATEWAY/rest/v1/users" -H "Authorization: Bearer $TOKEN_B")
COUNT_B=$(echo "$BODY_B" | python -c "import sys,json;print(len(json.load(sys.stdin)))")
[ "$COUNT_B" = "0" ] && pass "AC3: B ve 0 filas en users (no ve el perfil de A)" \
  || fail "AC3: B vio $COUNT_B filas en users (esperado 0)"

# --- AC4: B no ve el food_log de A ---
BODY_LOGS_B=$(curl -s "$GATEWAY/rest/v1/food_logs" -H "Authorization: Bearer $TOKEN_B" -H "Accept-Profile: nutrition")
COUNT_LOGS_B=$(echo "$BODY_LOGS_B" | python -c "import sys,json;print(len(json.load(sys.stdin)))")
[ "$COUNT_LOGS_B" = "0" ] && pass "AC4: B ve 0 food_logs de A" \
  || fail "AC4: B vio $COUNT_LOGS_B food_logs (esperado 0)"

# --- AC5: catálogo de ejercicios público, sin token ---
EXO_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$GATEWAY/rest/v1/exercises?limit=1" -H "Accept-Profile: training")
[ "$EXO_STATUS" = "200" ] && pass "AC5: catálogo training.exercises accesible sin token (200)" \
  || fail "AC5: GET exercises sin token devolvió $EXO_STATUS (esperado 200)"

if [ "$FAIL" = "0" ]; then
  echo "TODOS LOS TESTS E2E DE T10.2.1/T10.2.2 PASARON"
  exit 0
else
  echo "HAY TESTS E2E FALLIDOS — ver arriba"
  exit 1
fi
