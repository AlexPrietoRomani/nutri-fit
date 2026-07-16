-- Fase F10 (Autenticación Real) — T10.2.1 + T10.2.2
-- Corre DESPUÉS de z_init.sql (esquema) y zz_exercises_seed.sql (seed) por
-- orden alfabético en docker-entrypoint-initdb.d. Requiere el esquema `auth`
-- y las funciones/roles que ya trae la imagen supabase/postgres (auth.uid(),
-- roles anon/authenticated/service_role).

BEGIN;

-- ============================================================================
-- T10.2.1 — FK real a auth.users
-- ============================================================================
-- NOTA: NO hay trigger `handle_new_user` de auto-provisión. public.users tiene
-- columnas NOT NULL (name, birth_date, gender, height_cm) que GoTrue no conoce
-- en el signup; un trigger solo podría insertar el id y fallaría, o rellenar
-- basura, que es peor. El Onboarding de la app (frontend/lib/features/auth/
-- onboarding_provider.dart, saveProfile()) ya hace el INSERT/upsert completo
-- con esos datos reales — sigue siendo el único punto que crea la fila de
-- perfil, ahora con el id del usuario autenticado (conectado en T10.3.2).
ALTER TABLE public.users
  ADD CONSTRAINT fk_users_auth FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- ============================================================================
-- T10.2.2 — RLS por usuario + catálogo público
-- ============================================================================

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE nutrition.user_goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE nutrition.food_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE training.workout_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE training.workout_sets ENABLE ROW LEVEL SECURITY;

CREATE POLICY own_users ON public.users
  USING (auth.uid() = id) WITH CHECK (auth.uid() = id);
CREATE POLICY own_goals ON nutrition.user_goals
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY own_logs ON nutrition.food_logs
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY own_sessions ON training.workout_sessions
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY own_sets ON training.workout_sets
  USING (EXISTS (SELECT 1 FROM training.workout_sessions s WHERE s.id = session_id AND s.user_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM training.workout_sessions s WHERE s.id = session_id AND s.user_id = auth.uid()));

-- training.exercises se deja SIN RLS (catálogo global sin dueño) y
-- nutrition.food_cache también (caché global por barcode, sin user_id).
-- El GRANT ALL ... TO anon de z_init.sql ya cubre su acceso vía rol anon.

-- ============================================================================
-- GRANTs para el rol 'authenticated' (requests con JWT vía PostgREST)
-- ============================================================================
-- z_init.sql solo otorga privilegios a 'anon'. Las requests autenticadas
-- corren como rol 'authenticated' tras el SET ROLE de PostgREST; sin GRANT,
-- Postgres deniega por falta de privilegio de tabla ANTES de evaluar RLS.

GRANT USAGE ON SCHEMA nutrition TO authenticated;
GRANT USAGE ON SCHEMA training TO authenticated;

GRANT ALL ON public.users TO authenticated;
GRANT ALL ON nutrition.user_goals TO authenticated;
GRANT ALL ON nutrition.food_logs TO authenticated;
GRANT ALL ON training.workout_sessions TO authenticated;
GRANT ALL ON training.workout_sets TO authenticated;

-- catálogo/caché públicos: también deben seguir siendo legibles/escribibles
-- desde sesiones autenticadas, no solo anon.
GRANT ALL ON training.exercises TO authenticated;
GRANT ALL ON nutrition.food_cache TO authenticated;

GRANT USAGE ON ALL SEQUENCES IN SCHEMA nutrition TO authenticated;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA training TO authenticated;

COMMIT;
