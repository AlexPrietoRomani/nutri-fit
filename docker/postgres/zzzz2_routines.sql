-- Fase F13 (Rutinas Guardables) — T13.1.1
-- Corre DESPUÉS de zzz_auth_rls.sql por orden alfabético en
-- docker-entrypoint-initdb.d. Reutiliza el mismo patrón de RLS por usuario
-- ya establecido ahí (auth.uid() = user_id + GRANT a 'authenticated').

BEGIN;

CREATE TABLE IF NOT EXISTS training.routines (
    id UUID DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    name TEXT NOT NULL,
    source TEXT NOT NULL DEFAULT 'ai',
    items JSONB NOT NULL,
    cardio_block TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    CONSTRAINT pk_routines PRIMARY KEY (id),
    CONSTRAINT fk_routines_users FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE,
    CONSTRAINT chk_routines_source CHECK (source IN ('ai', 'manual'))
);

COMMENT ON TABLE training.routines IS 'Rutinas guardadas por el usuario (generadas por IA o manuales) — plantilla reutilizable con sets/reps/rpe objetivo, distinta de workout_sessions/workout_sets que registran sesiones ya ejecutadas.';
COMMENT ON COLUMN training.routines.items IS 'Array JSONB: [{"exercise_id": int, "name": "str", "sets": int, "reps": int, "rpe": num}]. Sin tabla relacional aparte: no hay necesidad hoy de queries por item individual.';

ALTER TABLE training.routines ENABLE ROW LEVEL SECURITY;

CREATE POLICY own_routines ON training.routines
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Sigue el precedente de zzz_auth_rls.sql: tablas de usuario (public.users,
-- nutrition.food_logs, training.workout_sessions, etc.) solo reciben GRANT
-- ALL para 'authenticated', NUNCA para 'anon' — 'anon' solo se usa para
-- catálogos globales sin dueño (training.exercises, nutrition.food_cache).
GRANT ALL ON training.routines TO authenticated;

COMMIT;
