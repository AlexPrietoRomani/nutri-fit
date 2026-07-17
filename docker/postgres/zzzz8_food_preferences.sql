-- Fase F18 (Nutricionista + Chat) — T18.2.1 (Preferencias/restricciones de nutrición)
-- Corre DESPUÉS de zzzz7_food_catalog_ingredients.sql por orden alfabético en
-- docker-entrypoint-initdb.d. Reutiliza el mismo patrón de RLS por usuario ya
-- establecido en zzzz3_meal_plans.sql (auth.uid() = user_id + GRANT a 'authenticated').
--
-- Persiste, como en una consulta con un nutricionista, las preferencias y
-- restricciones alimentarias del usuario: alergias (duras), cosas que no le
-- gustan, alimentos a evitar (sin ser alérgico), a incluir muy poco, y
-- restricciones de cocina (sin refrigerador, utensilios faltantes, etc.).
-- Una sola fila por usuario (PK = user_id).

BEGIN;

CREATE TABLE IF NOT EXISTS nutrition.food_preferences (
    user_id UUID NOT NULL,
    allergies TEXT[] NOT NULL DEFAULT '{}',    -- alergias (duras: nunca incluir)
    dislikes TEXT[] NOT NULL DEFAULT '{}',      -- no le gustan
    avoid TEXT[] NOT NULL DEFAULT '{}',         -- evitar (no alérgico)
    rarely TEXT[] NOT NULL DEFAULT '{}',        -- incluir muy poco
    constraints JSONB NOT NULL DEFAULT '{}',    -- {no_fridge: bool, missing_utensils: [..], ...}
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    CONSTRAINT pk_food_preferences PRIMARY KEY (user_id),
    CONSTRAINT fk_food_preferences_users FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE
);

COMMENT ON TABLE nutrition.food_preferences IS 'Preferencias y restricciones de nutrición del usuario (como hablar con un nutricionista). Una fila por usuario, RLS por auth.uid().';
COMMENT ON COLUMN nutrition.food_preferences.allergies IS 'Alergias duras: alimentos que NUNCA deben incluirse en un plan.';
COMMENT ON COLUMN nutrition.food_preferences.dislikes IS 'Alimentos que no le gustan al usuario.';
COMMENT ON COLUMN nutrition.food_preferences.avoid IS 'Alimentos a evitar sin ser alérgico (preferencia, no restricción dura).';
COMMENT ON COLUMN nutrition.food_preferences.rarely IS 'Alimentos a incluir muy poco (con moderación).';
COMMENT ON COLUMN nutrition.food_preferences.constraints IS 'Restricciones de cocina como JSONB, p. ej. {"no_fridge": true, "missing_utensils": ["horno"]}.';

ALTER TABLE nutrition.food_preferences ENABLE ROW LEVEL SECURITY;

CREATE POLICY own_food_preferences ON nutrition.food_preferences
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Mismo precedente que zzzz3_meal_plans.sql: GRANT ALL solo a 'authenticated',
-- nunca a 'anon' (tabla de usuario, no catálogo global).
GRANT ALL ON nutrition.food_preferences TO authenticated;

COMMIT;
