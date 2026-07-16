-- Fase F16 (Planificación de Nutrición y Entrenamiento) — T16.1.1
-- Corre DESPUÉS de zzzz2_routines.sql por orden alfabético en
-- docker-entrypoint-initdb.d. Reutiliza el mismo patrón de RLS por usuario
-- ya establecido ahí (auth.uid() = user_id + GRANT a 'authenticated').

BEGIN;

CREATE TABLE IF NOT EXISTS nutrition.meal_plans (
    id UUID DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    name TEXT NOT NULL,
    source TEXT NOT NULL DEFAULT 'ai',
    meals JSONB NOT NULL,
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    CONSTRAINT pk_meal_plans PRIMARY KEY (id),
    CONSTRAINT fk_meal_plans_users FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE,
    CONSTRAINT chk_meal_plans_source CHECK (source IN ('ai', 'manual'))
);

COMMENT ON TABLE nutrition.meal_plans IS 'Planes de comida guardados por el usuario (generados por IA o manuales) — plantilla reutilizable, análoga a training.routines pero para nutrición.';
COMMENT ON COLUMN nutrition.meal_plans.meals IS 'Array JSONB de comidas planificadas. Sin tabla relacional aparte, mismo criterio que training.routines.items.';

ALTER TABLE nutrition.meal_plans ENABLE ROW LEVEL SECURITY;

CREATE POLICY own_meal_plans ON nutrition.meal_plans
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Sigue el mismo precedente que zzzz2_routines.sql: GRANT ALL solo a
-- 'authenticated', nunca a 'anon' (tabla de usuario, no catálogo global).
GRANT ALL ON nutrition.meal_plans TO authenticated;

CREATE UNIQUE INDEX uq_meal_plans_default_per_user ON nutrition.meal_plans (user_id) WHERE is_default;

-- T16.1.1 también añade is_default a training.routines (F13 no lo tenía),
-- con el mismo índice único parcial: un solo plan/rutina default por usuario.
ALTER TABLE training.routines ADD COLUMN IF NOT EXISTS is_default BOOLEAN NOT NULL DEFAULT FALSE;
CREATE UNIQUE INDEX IF NOT EXISTS uq_routines_default_per_user ON training.routines (user_id) WHERE is_default;

COMMIT;
