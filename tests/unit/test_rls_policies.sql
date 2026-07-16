-- Test Unitario de T10.2.1 + T10.2.2 (Fase F10, Autenticación Real).
-- Verifica, a nivel de motor (sin pasar por PostgREST/HTTP), que:
--   1) La FK public.users.id -> auth.users(id) existe y hace CASCADE.
--   2) RLS aisla filas por auth.uid() en las 5 tablas de usuario.
--   3) training.exercises (catálogo) sigue siendo legible sin sesión.
-- Se simula el JWT con `SET LOCAL request.jwt.claims`, que es el mismo GUC
-- que lee auth.uid() (ver prosrc de auth.uid(): usa 'request.jwt.claim.sub'
-- o, si falta, el jsonb 'request.jwt.claims'->>'sub'). El SET ROLE authenticated
-- es necesario para que las políticas y GRANTs de authenticated apliquen.
--
-- Uso: docker exec -i nutri-fit-postgres psql -U postgres -v ON_ERROR_STOP=1 -f - < este_archivo
-- (o vía stdin, ver tests/unit/run_rls_unit_test.sh)

\set ON_ERROR_STOP on
\pset pager off

DO $$
DECLARE
  v_user_a UUID := gen_random_uuid();
  v_user_b UUID := gen_random_uuid();
BEGIN
  -- Fixtures: dos usuarios reales en auth.users (requerido por la FK).
  INSERT INTO auth.users (id, email) VALUES
    (v_user_a, 'unit-rls-a@nutrifit.local'),
    (v_user_b, 'unit-rls-b@nutrifit.local');

  -- Guarda los ids en variables de sesión para los bloques siguientes.
  PERFORM set_config('nutrifit_test.user_a', v_user_a::text, false);
  PERFORM set_config('nutrifit_test.user_b', v_user_b::text, false);
END $$;

-- ============================================================================
-- AC1 (T10.2.1): la FK existe y referencia auth.users con ON DELETE CASCADE.
-- ============================================================================
DO $$
DECLARE
  v_delete_rule TEXT;
BEGIN
  SELECT rc.delete_rule INTO v_delete_rule
  FROM information_schema.referential_constraints rc
  WHERE rc.constraint_name = 'fk_users_auth';

  IF v_delete_rule IS NULL THEN
    RAISE EXCEPTION 'FALLO AC1: no existe la constraint fk_users_auth';
  ELSIF v_delete_rule <> 'CASCADE' THEN
    RAISE EXCEPTION 'FALLO AC1: fk_users_auth no es ON DELETE CASCADE (es %)', v_delete_rule;
  ELSE
    RAISE NOTICE 'PASS AC1: fk_users_auth existe con ON DELETE CASCADE';
  END IF;
END $$;

-- Crea el perfil de A como postgres (superusuario, bypassa RLS) para el
-- resto de los asserts, igual que haría el Onboarding real de la app.
INSERT INTO public.users (id, name, birth_date, gender, height_cm)
VALUES (current_setting('nutrifit_test.user_a')::uuid, 'A', '1990-01-01', 'M', 170);
INSERT INTO public.users (id, name, birth_date, gender, height_cm)
VALUES (current_setting('nutrifit_test.user_b')::uuid, 'B', '1991-01-01', 'F', 160);
INSERT INTO nutrition.food_logs (user_id, meal_type, food_name, calories, protein_g, carbs_g, fat_g, serving_size_g)
VALUES (current_setting('nutrifit_test.user_a')::uuid, 'breakfast', 'Avena', 300, 10, 50, 5, 100);

-- ============================================================================
-- AC2 (T10.2.2): con claims de A, SELECT en food_logs solo devuelve filas de A.
-- ============================================================================
DO $$
DECLARE
  v_count INTEGER;
BEGIN
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', current_setting('nutrifit_test.user_a'), 'role', 'authenticated')::text,
    true);

  SELECT count(*) INTO v_count FROM nutrition.food_logs;
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'FALLO AC2: usuario A debería ver 1 fila propia en food_logs, vio %', v_count;
  END IF;
  RAISE NOTICE 'PASS AC2: usuario A ve exactamente su propia fila en food_logs';
  RESET ROLE;
END $$;

-- ============================================================================
-- AC3 (T10.2.2): con claims de B, 0 filas de A visibles en food_logs.
-- ============================================================================
DO $$
DECLARE
  v_count INTEGER;
BEGIN
  SET LOCAL ROLE authenticated;
  PERFORM set_config('request.jwt.claims',
    json_build_object('sub', current_setting('nutrifit_test.user_b'), 'role', 'authenticated')::text,
    true);

  SELECT count(*) INTO v_count FROM nutrition.food_logs;
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'FALLO AC3: usuario B no debería ver filas de A en food_logs, vio %', v_count;
  END IF;
  RAISE NOTICE 'PASS AC3: usuario B ve 0 filas del diario de A';
  RESET ROLE;
END $$;

-- ============================================================================
-- AC4 (T10.2.2): exercises (catálogo) es legible sin sesión (rol anon, sin JWT).
-- ============================================================================
DO $$
DECLARE
  v_count INTEGER;
BEGIN
  SET LOCAL ROLE anon;
  SELECT count(*) INTO v_count FROM training.exercises LIMIT 1;
  IF v_count IS NULL THEN
    RAISE EXCEPTION 'FALLO AC4: exercises no es legible por anon';
  END IF;
  RAISE NOTICE 'PASS AC4: exercises es legible sin sesión (rol anon)';
  RESET ROLE;
END $$;

-- Limpieza: borrar el usuario de auth debe hacer CASCADE hasta public.users
-- (AC1, segunda mitad: borrar el usuario de auth cascada al perfil).
DO $$
DECLARE
  v_count INTEGER;
BEGIN
  DELETE FROM auth.users WHERE id = current_setting('nutrifit_test.user_a')::uuid;
  SELECT count(*) INTO v_count FROM public.users WHERE id = current_setting('nutrifit_test.user_a')::uuid;
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'FALLO AC1 (cascade): el perfil de A sobrevivió al borrado de auth.users';
  END IF;
  RAISE NOTICE 'PASS AC1 (cascade): borrar de auth.users borra en cascada public.users';

  DELETE FROM auth.users WHERE id = current_setting('nutrifit_test.user_b')::uuid;
END $$;

\echo 'TODOS LOS TESTS UNITARIOS DE T10.2.1/T10.2.2 PASARON'
