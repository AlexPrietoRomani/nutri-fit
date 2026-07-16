-- Fase F17 (Cardio + Búsqueda de Comida) — T17.1.1
-- Corre DESPUÉS de zzzz3_meal_plans.sql por orden alfabético en
-- docker-entrypoint-initdb.d. Solo añade columnas nullable; no toca RLS
-- ni políticas existentes de public.users ni training.workout_sets.
--   - weight_kg: peso corporal del usuario (antes solo se derivaba).
--   - duration_min / distance_km: métricas de cardio en un set de entrenamiento.
--     Fuerza las deja NULL; cardio las llena.

BEGIN;

ALTER TABLE public.users ADD COLUMN IF NOT EXISTS weight_kg REAL;
ALTER TABLE training.workout_sets ADD COLUMN IF NOT EXISTS duration_min REAL;
ALTER TABLE training.workout_sets ADD COLUMN IF NOT EXISTS distance_km REAL;

COMMENT ON COLUMN public.users.weight_kg IS 'Peso corporal en kg (F17). Nullable: perfiles previos pueden no tenerlo.';
COMMENT ON COLUMN training.workout_sets.duration_min IS 'Duración en minutos para sets de cardio (F17). NULL en sets de fuerza.';
COMMENT ON COLUMN training.workout_sets.distance_km IS 'Distancia en km para sets de cardio (F17). NULL en sets de fuerza.';

COMMIT;
