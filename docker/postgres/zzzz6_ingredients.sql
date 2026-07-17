-- Fase F18 (Nutricionista + Chat) — T18.8.1 + T18.5.1
-- Corre DESPUÉS de zzzz5_food_catalog.sql por orden alfabético en
-- docker-entrypoint-initdb.d. Catálogo curado y PÚBLICO de INGREDIENTES base
-- (nivel ingrediente, no plato): pechuga de pollo, arroz, papa… con macros
-- Y micronutrientes reales por 100 g/ml. Mismo patrón de lectura pública que
-- training.exercises y nutrition.food_catalog (catálogo sin dueño, GRANT SELECT
-- a anon/authenticated; z_init.sql no alcanza a esta tabla porque aún no existe
-- cuando corre, de ahí el GRANT explícito aquí).

BEGIN;

CREATE TABLE IF NOT EXISTS nutrition.ingredients (
    id INTEGER PRIMARY KEY,          -- ids EXPLÍCITOS y estables: la composición de platos (T18.8.2) los referenciará
    name TEXT UNIQUE NOT NULL,
    category TEXT,                   -- 'proteina','cereal','tuberculo','verdura','fruta','grasa','lacteo','legumbre'
    unit TEXT NOT NULL DEFAULT 'g'
        CONSTRAINT chk_ingredients_unit CHECK (unit IN ('g','ml')),
    -- Macros por 100 g/ml de porción comestible:
    calories_per_100 REAL,
    protein_per_100 REAL,
    carbs_per_100 REAL,
    fat_per_100 REAL,
    -- Micronutrientes por 100 g/ml (subconjunto PARCIAL de 7 clave):
    iron_mg REAL,
    calcium_mg REAL,
    sodium_mg REAL,
    potassium_mg REAL,
    vitamin_c_mg REAL,
    vitamin_a_ug REAL,
    zinc_mg REAL
);

COMMENT ON TABLE nutrition.ingredients IS
  'Catálogo curado de ingredientes base (F18). Macros y micronutrientes son ESTIMACIONES por 100 g/ml de porción comestible, basadas en tablas de composición de alimentos (referencia INS/CENAN "Tablas Peruanas de Composición de Alimentos" y valores estándar equivalentes), NO valores de laboratorio propios. Micronutrientes = subconjunto PARCIAL de 7 clave (hierro, calcio, sodio, potasio, vit C, vit A, zinc). Un valor que no sea fiable se deja NULL: NUNCA se inventa un micro para presentarlo como oficial. Rangos de id: 1-8 proteína animal, 9-14 cereal/pan, 15-18 tubérculo, 19-27 verdura, 28-33 fruta, 34-36 grasa, 37-39 lácteo/huevo, 40-42 legumbre.';

-- Lectura pública, mismo patrón que food_catalog (catálogo sin dueño).
GRANT SELECT ON nutrition.ingredients TO anon, authenticated;

INSERT INTO nutrition.ingredients
  (id, name, category, unit, calories_per_100, protein_per_100, carbs_per_100, fat_per_100,
   iron_mg, calcium_mg, sodium_mg, potassium_mg, vitamin_c_mg, vitamin_a_ug, zinc_mg) VALUES
  -- 1-8: proteína animal
  (1,  'Pechuga de pollo',     'proteina', 'g', 165, 31.0, 0.0,  3.6,  0.7, 15,  74,  256, 0.0,  9,    1.0),
  (2,  'Muslo de pollo',       'proteina', 'g', 209, 26.0, 0.0,  10.9, 1.3, 12,  88,  240, 0.0,  17,   2.0),
  (3,  'Carne de res magra',   'proteina', 'g', 250, 26.0, 0.0,  15.0, 2.6, 12,  72,  330, 0.0,  0,    4.8),
  (4,  'Carne de cerdo',       'proteina', 'g', 242, 27.0, 0.0,  14.0, 0.9, 19,  62,  423, 0.7,  2,    2.4),
  (5,  'Pescado (jurel)',      'proteina', 'g', 120, 23.0, 0.0,  3.0,  1.0, 30,  80,  400, 0.0,  30,   0.8),
  (6,  'Atún',                 'proteina', 'g', 130, 28.0, 0.0,  1.3,  1.0, 8,   45,  320, 0.0,  16,   0.6),
  (7,  'Camarón',              'proteina', 'g', 99,  24.0, 0.2,  0.3,  0.5, 70,  111, 259, 0.0,  54,   1.6),
  (8,  'Hígado de res',        'proteina', 'g', 175, 26.0, 3.9,  4.9,  6.5, 5,   69,  313, 1.3,  9442, 4.0),
  -- 9-14: cereal / pan
  (9,  'Arroz blanco cocido',  'cereal',   'g', 130, 2.7,  28.0, 0.3,  0.2, 10,  1,   35,  0.0,  0,    0.5),
  (10, 'Quinua cocida',        'cereal',   'g', 120, 4.4,  21.3, 1.9,  1.5, 17,  7,   172, 0.0,  1,    1.1),
  (11, 'Fideos cocidos',       'cereal',   'g', 158, 5.8,  31.0, 0.9,  0.9, 7,   1,   24,  0.0,  0,    0.5),
  (12, 'Pan francés',          'cereal',   'g', 277, 9.0,  53.0, 2.5,  3.0, 30,  490, 120, 0.0,  0,    0.8),
  (13, 'Avena en hojuelas',    'cereal',   'g', 389, 16.9, 66.3, 6.9,  4.7, 54,  2,   429, 0.0,  0,    4.0),
  (14, 'Maíz (choclo)',        'cereal',   'g', 96,  3.4,  21.0, 1.5,  0.5, 2,   15,  270, 6.8,  9,    0.6),
  -- 15-18: tubérculo
  (15, 'Papa blanca',          'tuberculo','g', 77,  2.0,  17.0, 0.1,  0.8, 12,  6,   421, 19.7, 0,    0.3),
  (16, 'Camote',               'tuberculo','g', 86,  1.6,  20.1, 0.1,  0.6, 30,  55,  337, 2.4,  709,  0.3),
  (17, 'Yuca',                 'tuberculo','g', 160, 1.4,  38.1, 0.3,  0.3, 16,  14,  271, 20.6, 1,    0.3),
  (18, 'Olluco',               'tuberculo','g', 62,  1.1,  14.3, 0.1,  1.1, 3,   4,   NULL,11.5, 0,    NULL),
  -- 19-27: verdura
  (19, 'Cebolla',              'verdura',  'g', 40,  1.1,  9.3,  0.1,  0.2, 23,  4,   146, 7.4,  0,    0.2),
  (20, 'Ají amarillo',         'verdura',  'g', 40,  1.6,  8.8,  0.4,  1.2, 14,  3,   340, 144.0,29,   0.3),
  (21, 'Ajo',                  'verdura',  'g', 149, 6.4,  33.1, 0.5,  1.7, 181, 17,  401, 31.2, 0,    1.2),
  (22, 'Tomate',               'verdura',  'g', 18,  0.9,  3.9,  0.2,  0.3, 10,  5,   237, 13.7, 42,   0.2),
  (23, 'Zanahoria',            'verdura',  'g', 41,  0.9,  9.6,  0.2,  0.3, 33,  69,  320, 5.9,  835,  0.2),
  (24, 'Lechuga',              'verdura',  'g', 15,  1.4,  2.9,  0.2,  0.9, 36,  28,  194, 9.2,  370,  0.2),
  (25, 'Espinaca',             'verdura',  'g', 23,  2.9,  3.6,  0.4,  2.7, 99,  79,  558, 28.1, 469,  0.5),
  (26, 'Brócoli',              'verdura',  'g', 34,  2.8,  6.6,  0.4,  0.7, 47,  33,  316, 89.2, 31,   0.4),
  (27, 'Pimiento rojo',        'verdura',  'g', 31,  1.0,  6.0,  0.3,  0.4, 7,   4,   211, 127.7,157,  0.3),
  -- 28-33: fruta
  (28, 'Plátano',             'fruta',    'g', 89,  1.1,  22.8, 0.3,  0.3, 5,   1,   358, 8.7,  3,    0.2),
  (29, 'Palta',                'fruta',    'g', 160, 2.0,  8.5,  14.7, 0.6, 12,  7,   485, 10.0, 7,    0.6),
  (30, 'Limón',                'fruta',    'g', 29,  1.1,  9.3,  0.3,  0.6, 26,  2,   138, 53.0, 1,    0.1),
  (31, 'Manzana',              'fruta',    'g', 52,  0.3,  13.8, 0.2,  0.1, 6,   1,   107, 4.6,  3,    0.0),
  (32, 'Naranja',              'fruta',    'g', 47,  0.9,  11.8, 0.1,  0.1, 40,  0,   181, 53.2, 11,   0.1),
  (33, 'Papaya',               'fruta',    'g', 43,  0.5,  10.8, 0.3,  0.3, 20,  8,   182, 60.9, 47,   0.1),
  -- 34-36: grasa
  (34, 'Aceite vegetal',       'grasa',    'ml', 884, 0.0,  0.0,  100.0,0.0, 0,   0,   0,   0.0,  0,    0.0),
  (35, 'Mantequilla',          'grasa',    'g', 717, 0.9,  0.1,  81.1, 0.0, 24,  643, 24,  0.0,  684,  0.1),
  (36, 'Maní tostado',         'grasa',    'g', 567, 25.8, 16.1, 49.2, 4.6, 92,  18,  705, 0.0,  0,    3.3),
  -- 37-39: lácteo / huevo
  (37, 'Huevo de gallina',     'lacteo',   'g', 143, 12.6, 0.7,  9.5,  1.8, 56,  142, 138, 0.0,  160,  1.3),
  (38, 'Leche entera',         'lacteo',   'ml', 61,  3.2,  4.8,  3.3,  0.0, 113, 43,  132, 0.0,  46,   0.4),
  (39, 'Queso fresco',         'lacteo',   'g', 264, 18.0, 3.0,  20.0, 0.2, 500, 400, 62,  0.0,  180,  2.8),
  -- 40-42: legumbre
  (40, 'Frejol cocido',        'legumbre', 'g', 127, 8.7,  22.8, 0.5,  2.2, 35,  1,   405, 1.2,  0,    1.0),
  (41, 'Lenteja cocida',       'legumbre', 'g', 116, 9.0,  20.1, 0.4,  3.3, 19,  2,   369, 1.5,  0,    1.3),
  (42, 'Pallar cocido',        'legumbre', 'g', 115, 7.8,  20.9, 0.4,  2.4, 17,  2,   508, 0.0,  0,    0.9)
;

COMMIT;
