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

# --- T13.1.1 (Fase F13, Rutinas Guardables) — A crea una rutina ---
ROUTINE_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$GATEWAY/rest/v1/routines" \
  -H "Authorization: Bearer $TOKEN_A" -H "Content-Type: application/json" -H "Content-Profile: training" \
  -d "{\"user_id\":\"$SUB_A\",\"name\":\"Test\",\"items\":[{\"exercise_id\":1,\"name\":\"Test Ex\",\"sets\":3,\"reps\":10,\"rpe\":8}]}")
[ "$ROUTINE_STATUS" = "201" ] && pass "AC6: A pudo crear su propia rutina (201)" \
  || fail "AC6: INSERT de rutina propia devolvió $ROUTINE_STATUS (esperado 201)"

# --- AC7: A ve su rutina ---
BODY_ROUTINES_A=$(curl -s "$GATEWAY/rest/v1/routines" -H "Authorization: Bearer $TOKEN_A" -H "Accept-Profile: training")
COUNT_ROUTINES_A=$(echo "$BODY_ROUTINES_A" | python -c "import sys,json;print(len(json.load(sys.stdin)))")
[ "$COUNT_ROUTINES_A" = "1" ] && pass "AC7: A ve exactamente 1 rutina (la propia)" \
  || fail "AC7: A vio $COUNT_ROUTINES_A rutinas (esperado 1)"

# --- AC8: B no ve la rutina de A ---
BODY_ROUTINES_B=$(curl -s "$GATEWAY/rest/v1/routines" -H "Authorization: Bearer $TOKEN_B" -H "Accept-Profile: training")
COUNT_ROUTINES_B=$(echo "$BODY_ROUTINES_B" | python -c "import sys,json;print(len(json.load(sys.stdin)))")
[ "$COUNT_ROUTINES_B" = "0" ] && pass "AC8: B ve 0 rutinas de A" \
  || fail "AC8: B vio $COUNT_ROUTINES_B rutinas (esperado 0)"

# --- T16.1.1 (Fase F16, Planificación de Nutrición/Entrenamiento) — A crea un meal_plan default ---
MEALPLAN_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$GATEWAY/rest/v1/meal_plans" \
  -H "Authorization: Bearer $TOKEN_A" -H "Content-Type: application/json" -H "Content-Profile: nutrition" \
  -d "{\"user_id\":\"$SUB_A\",\"name\":\"Plan Test\",\"meals\":[{\"meal_type\":\"breakfast\",\"food_name\":\"Avena\",\"calories\":300}],\"is_default\":true}")
[ "$MEALPLAN_STATUS" = "201" ] && pass "AC9: A pudo crear su propio meal_plan default (201)" \
  || fail "AC9: INSERT de meal_plan propio devolvió $MEALPLAN_STATUS (esperado 201)"

# --- AC10: B no ve el meal_plan de A ---
BODY_MEALPLANS_B=$(curl -s "$GATEWAY/rest/v1/meal_plans" -H "Authorization: Bearer $TOKEN_B" -H "Accept-Profile: nutrition")
COUNT_MEALPLANS_B=$(echo "$BODY_MEALPLANS_B" | python -c "import sys,json;print(len(json.load(sys.stdin)))")
[ "$COUNT_MEALPLANS_B" = "0" ] && pass "AC10: B ve 0 meal_plans de A" \
  || fail "AC10: B vio $COUNT_MEALPLANS_B meal_plans (esperado 0)"

# --- AC11: un segundo meal_plan default del MISMO usuario A debe fallar (índice único parcial) ---
MEALPLAN2_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$GATEWAY/rest/v1/meal_plans" \
  -H "Authorization: Bearer $TOKEN_A" -H "Content-Type: application/json" -H "Content-Profile: nutrition" \
  -d "{\"user_id\":\"$SUB_A\",\"name\":\"Plan Test 2\",\"meals\":[{\"meal_type\":\"lunch\",\"food_name\":\"Pollo\",\"calories\":400}],\"is_default\":true}")
[ "$MEALPLAN2_STATUS" = "409" ] && pass "AC11: segundo meal_plan default del mismo usuario rechazado (409, uq_meal_plans_default_per_user)" \
  || fail "AC11: segundo INSERT default devolvió $MEALPLAN2_STATUS (esperado 409 por índice único parcial)"

# --- T17.1.2 (Fase F17, Búsqueda de Comida) — catálogo de comida público, sin token ---
FOOD_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$GATEWAY/rest/v1/food_catalog?limit=1" -H "Accept-Profile: nutrition")
[ "$FOOD_STATUS" = "200" ] && pass "AC12: catálogo nutrition.food_catalog accesible sin token (200)" \
  || fail "AC12: GET food_catalog sin token devolvió $FOOD_STATUS (esperado 200)"

# --- AC13: el catálogo devuelve datos (no vacío) sin token ---
FOOD_BODY=$(curl -s "$GATEWAY/rest/v1/food_catalog?limit=1" -H "Accept-Profile: nutrition")
FOOD_COUNT=$(echo "$FOOD_BODY" | python -c "import sys,json;print(len(json.load(sys.stdin)))")
[ "$FOOD_COUNT" = "1" ] && pass "AC13: food_catalog devuelve datos sin token (1 fila con limit=1)" \
  || fail "AC13: food_catalog devolvió $FOOD_COUNT filas (esperado 1)"

# --- T18.8.1 (Fase F18, Ingredientes) — catálogo de ingredientes público, sin token ---
ING_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$GATEWAY/rest/v1/ingredients?limit=1" -H "Accept-Profile: nutrition")
[ "$ING_STATUS" = "200" ] && pass "AC14: catálogo nutrition.ingredients accesible sin token (200)" \
  || fail "AC14: GET ingredients sin token devolvió $ING_STATUS (esperado 200)"

# --- AC15: el catálogo de ingredientes devuelve datos (no vacío) sin token ---
ING_BODY=$(curl -s "$GATEWAY/rest/v1/ingredients?limit=1" -H "Accept-Profile: nutrition")
ING_COUNT=$(echo "$ING_BODY" | python -c "import sys,json;print(len(json.load(sys.stdin)))")
[ "$ING_COUNT" = "1" ] && pass "AC15: ingredients devuelve datos sin token (1 fila con limit=1)" \
  || fail "AC15: ingredients devolvió $ING_COUNT filas (esperado 1)"

# --- T18.2.1 (Fase F18, Nutricionista + Chat) — A hace upsert de sus preferencias ---
PREFS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$GATEWAY/rest/v1/food_preferences" \
  -H "Authorization: Bearer $TOKEN_A" -H "Content-Type: application/json" -H "Content-Profile: nutrition" \
  -H "Prefer: resolution=merge-duplicates" \
  -d "{\"user_id\":\"$SUB_A\",\"allergies\":[\"mani\"],\"dislikes\":[\"cebolla\"],\"avoid\":[],\"rarely\":[\"azucar\"],\"constraints\":{\"no_fridge\":true}}")
[ "$PREFS_STATUS" = "201" ] && pass "AC16: A pudo hacer upsert de sus preferencias (201)" \
  || fail "AC16: upsert de preferencias propio devolvió $PREFS_STATUS (esperado 201)"

# --- AC17: A lee exactamente su fila de preferencias ---
BODY_PREFS_A=$(curl -s "$GATEWAY/rest/v1/food_preferences" -H "Authorization: Bearer $TOKEN_A" -H "Accept-Profile: nutrition")
COUNT_PREFS_A=$(echo "$BODY_PREFS_A" | python -c "import sys,json;print(len(json.load(sys.stdin)))")
[ "$COUNT_PREFS_A" = "1" ] && pass "AC17: A ve exactamente 1 fila de preferencias (la propia)" \
  || fail "AC17: A vio $COUNT_PREFS_A filas de preferencias (esperado 1)"

# --- AC18: B no ve las preferencias de A (RLS) ---
BODY_PREFS_B=$(curl -s "$GATEWAY/rest/v1/food_preferences" -H "Authorization: Bearer $TOKEN_B" -H "Accept-Profile: nutrition")
COUNT_PREFS_B=$(echo "$BODY_PREFS_B" | python -c "import sys,json;print(len(json.load(sys.stdin)))")
[ "$COUNT_PREFS_B" = "0" ] && pass "AC18: B ve 0 preferencias de A (RLS)" \
  || fail "AC18: B vio $COUNT_PREFS_B preferencias (esperado 0)"

if [ "$FAIL" = "0" ]; then
  echo "TODOS LOS TESTS E2E DE T10.2.1/T10.2.2 PASARON"
  exit 0
else
  echo "HAY TESTS E2E FALLIDOS — ver arriba"
  exit 1
fi
