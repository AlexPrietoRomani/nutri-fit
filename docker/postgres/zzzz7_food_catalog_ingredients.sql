-- Fase F18 (Nutricionista + Chat) — T18.8.2 (Composición de platos + recálculo de macros)
-- Corre DESPUÉS de zzzz6_ingredients.sql por orden alfabético en
-- docker-entrypoint-initdb.d: necesita que existan tanto nutrition.food_catalog
-- (zzzz5) como los ingredient_id de nutrition.ingredients (zzzz6).
--
-- Añade a food_catalog una composición OPCIONAL por ingredientes para poder
-- editar/quitar/añadir porciones y recalcular macros. Compatibilidad: un plato
-- con ingredients = NULL sigue usando sus macros planas (calories/protein_g/…).

BEGIN;

-- Columna nullable: NULL = el plato NO declara composición y usa sus macros planas.
ALTER TABLE nutrition.food_catalog
    ADD COLUMN IF NOT EXISTS ingredients JSONB;

COMMENT ON COLUMN nutrition.food_catalog.ingredients IS
  'Composición OPCIONAL del plato como arreglo JSON [{"ingredient_id": int, "grams": num}], donde ingredient_id referencia nutrition.ingredients(id). Permite recalcular macros sumando grams/100 * *_per_100 por ingrediente. NULL = el plato no declara composición y usa sus macros planas (calories/protein_g/carbs_g/fat_g). No es una FK real (JSONB): la integridad de los ids se valida en el seed contra zzzz6_ingredients.sql.';

-- Composición de un subconjunto representativo de platos claros. Los ingredient_id
-- referencian nutrition.ingredients (zzzz6): 1 pechuga pollo, 3 res magra, 5 pescado,
-- 9 arroz cocido, 10 quinua, 11 fideos, 12 pan francés, 14 choclo, 15 papa, 19 cebolla,
-- 20 ají amarillo, 22 tomate, 23 zanahoria, 34 aceite, 37 huevo, 38 leche, 39 queso, 40 frejol.

UPDATE nutrition.food_catalog SET ingredients =
  '[{"ingredient_id":1,"grams":100},{"ingredient_id":9,"grams":300},{"ingredient_id":19,"grams":30},{"ingredient_id":20,"grams":20},{"ingredient_id":23,"grams":20},{"ingredient_id":34,"grams":15}]'::jsonb
  WHERE name ILIKE 'Arroz con Pollo';

UPDATE nutrition.food_catalog SET ingredients =
  '[{"ingredient_id":3,"grams":150},{"ingredient_id":9,"grams":200},{"ingredient_id":15,"grams":100},{"ingredient_id":19,"grams":50},{"ingredient_id":22,"grams":50},{"ingredient_id":34,"grams":15}]'::jsonb
  WHERE name ILIKE 'Lomo Saltado';

UPDATE nutrition.food_catalog SET ingredients =
  '[{"ingredient_id":1,"grams":120},{"ingredient_id":12,"grams":40},{"ingredient_id":15,"grams":100},{"ingredient_id":20,"grams":30},{"ingredient_id":38,"grams":50},{"ingredient_id":34,"grams":10}]'::jsonb
  WHERE name ILIKE 'Ají de Gallina';

UPDATE nutrition.food_catalog SET ingredients =
  '[{"ingredient_id":11,"grams":200},{"ingredient_id":3,"grams":120},{"ingredient_id":22,"grams":40},{"ingredient_id":19,"grams":40},{"ingredient_id":34,"grams":15}]'::jsonb
  WHERE name ILIKE 'Tallarín Saltado';

UPDATE nutrition.food_catalog SET ingredients =
  '[{"ingredient_id":9,"grams":300},{"ingredient_id":1,"grams":100},{"ingredient_id":37,"grams":50},{"ingredient_id":19,"grams":30},{"ingredient_id":34,"grams":15}]'::jsonb
  WHERE name ILIKE 'Arroz Chaufa de Pollo';

UPDATE nutrition.food_catalog SET ingredients =
  '[{"ingredient_id":3,"grams":150},{"ingredient_id":40,"grams":150},{"ingredient_id":9,"grams":150},{"ingredient_id":19,"grams":30},{"ingredient_id":34,"grams":15}]'::jsonb
  WHERE name ILIKE 'Seco de Res con Frejoles';

UPDATE nutrition.food_catalog SET ingredients =
  '[{"ingredient_id":10,"grams":250},{"ingredient_id":23,"grams":40},{"ingredient_id":19,"grams":30},{"ingredient_id":34,"grams":10}]'::jsonb
  WHERE name ILIKE 'Quinua Guisada';

UPDATE nutrition.food_catalog SET ingredients =
  '[{"ingredient_id":14,"grams":200},{"ingredient_id":39,"grams":60}]'::jsonb
  WHERE name ILIKE 'Choclo con Queso';

UPDATE nutrition.food_catalog SET ingredients =
  '[{"ingredient_id":15,"grams":150},{"ingredient_id":39,"grams":40},{"ingredient_id":20,"grams":20},{"ingredient_id":38,"grams":30},{"ingredient_id":37,"grams":30},{"ingredient_id":34,"grams":10}]'::jsonb
  WHERE name ILIKE 'Papa a la Huancaína';

UPDATE nutrition.food_catalog SET ingredients =
  '[{"ingredient_id":5,"grams":200},{"ingredient_id":22,"grams":60},{"ingredient_id":19,"grams":40},{"ingredient_id":20,"grams":20}]'::jsonb
  WHERE name ILIKE 'Sudado de Pescado';

UPDATE nutrition.food_catalog SET ingredients =
  '[{"ingredient_id":5,"grams":180},{"ingredient_id":19,"grams":80},{"ingredient_id":20,"grams":30},{"ingredient_id":37,"grams":30},{"ingredient_id":34,"grams":20}]'::jsonb
  WHERE name ILIKE 'Escabeche de Pescado';

UPDATE nutrition.food_catalog SET ingredients =
  '[{"ingredient_id":9,"grams":150},{"ingredient_id":38,"grams":120}]'::jsonb
  WHERE name ILIKE 'Arroz con Leche';

COMMIT;
