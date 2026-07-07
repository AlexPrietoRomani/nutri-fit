# Diseño de Base de Datos: Nutri-Fit Modular

Este documento especifica el diseño físico de PostgreSQL utilizando múltiples esquemas para lograr una separación clara de responsabilidades (Nutrición y Entrenamiento).

---

## 1. Estructura de Esquemas

```text
Database: nutri-fit
├── Schema: public      # Perfil de usuario y núcleo de la aplicación
├── Schema: nutrition   # Módulo de alimentación e ingesta diaria
└── Schema: training    # Módulo de rutinas y ejercicios (LiftLog core)
```

---

## 2. Diccionario de Tablas por Esquema

### 2.1. Esquema: `public` (Núcleo y Usuarios)

#### Tabla: `public.users`
| Columna | Tipo | Restricción | Descripción |
|---|---|---|---|
| `id` | `UUID` | `PK, References auth.users` | Identificador de usuario |
| `name` | `TEXT` | `NOT NULL` | Nombre de pantalla |
| `birth_date` | `DATE` | `NOT NULL` | Cálculo de edad |
| `gender` | `TEXT` | `CHECK (gender IN ('M', 'F'))` | Sexo biológico |
| `height_cm` | `REAL` | `NOT NULL` | Altura en cm |
| `body_type` | `TEXT` | `CHECK (body_type IN ('ectomorph', 'mesomorph', 'endomorph'))` | Biotipo |
| `pal_level` | `REAL` | `DEFAULT 1.2` | Factor de actividad diaria |

---

### 2.2. Esquema: `nutrition` (Módulo Fitia/OpenNutriTracker)

#### Tabla: `nutrition.user_goals`
| Columna | Tipo | Restricción | Descripción |
|---|---|---|---|
| `user_id` | `UUID` | `PK, FK -> public.users.id` | Meta asignada al usuario |
| `target_calories` | `INTEGER` | `NOT NULL` | Calorías objetivo al día |
| `target_protein_g` | `REAL` | `NOT NULL` | Proteínas objetivo (g) |
| `target_carbs_g` | `REAL` | `NOT NULL` | Carbohidratos objetivo (g) |
| `target_fat_g` | `REAL` | `NOT NULL` | Grasas objetivo (g) |
| `goal_type` | `TEXT` | `CHECK (goal_type IN ('deficit', 'maintenance', 'surplus'))` | Tipo de meta física |

#### Tabla: `nutrition.food_logs`
| Columna | Tipo | Restricción | Descripción |
|---|---|---|---|
| `id` | `BIGINT` | `PK, IDENTITY` | ID del registro de comida |
| `user_id` | `UUID` | `FK -> public.users.id` | Usuario que consume |
| `logged_at` | `TIMESTAMPTZ` | `DEFAULT NOW()` | Fecha y hora del consumo |
| `meal_type` | `TEXT` | `CHECK (meal_type IN ('breakfast', 'lunch', 'dinner', 'snack'))` | Tipo de comida |
| `food_name` | `TEXT` | `NOT NULL` | Nombre del alimento |
| `calories` | `REAL` | `NOT NULL` | Calorías ingeridas |
| `protein_g` | `REAL` | `NOT NULL` | Proteínas |
| `carbs_g` | `REAL` | `NOT NULL` | Carbohidratos |
| `fat_g` | `REAL` | `NOT NULL` | Grasas |
| `serving_size_g` | `REAL` | `NOT NULL` | Porción en gramos |

---

### 2.3. Esquema: `training` (Módulo Strong/LiftLog)

#### Tabla: `training.exercises`
| Columna | Tipo | Restricción | Descripción |
|---|---|---|---|
| `id` | `INTEGER` | `PK` | ID del ejercicio |
| `name` | `TEXT` | `NOT NULL` | Ej. "Sentadilla libre" |
| `category` | `TEXT` | `NOT NULL` | Pierna, empuje, tracción, calistenia |
| `equipment` | `TEXT` | | Barra, mancuerna, máquina, ninguno |

#### Tabla: `training.workout_sessions`
| Columna | Tipo | Restricción | Descripción |
|---|---|---|---|
| `id` | `UUID` | `PK, DEFAULT gen_random_uuid()` | ID de sesión |
| `user_id` | `UUID` | `FK -> public.users.id` | Usuario |
| `started_at` | `TIMESTAMPTZ` | `NOT NULL` | Inicio de la rutina |
| `ended_at` | `TIMESTAMPTZ` | | Fin de la rutina (si es NULL está activa) |
| `name` | `TEXT` | `NOT NULL` | Ej. "Día A: Pecho e Hombros" |

#### Tabla: `training.workout_sets`
| Columna | Tipo | Restricción | Descripción |
|---|---|---|---|
| `id` | `BIGINT` | `PK, IDENTITY` | ID del set individual |
| `session_id` | `UUID` | `FK -> training.workout_sessions.id` | Sesión activa o terminada |
| `exercise_id` | `INTEGER` | `FK -> training.exercises.id` | Ejercicio que se realiza |
| `set_number` | `INTEGER` | `NOT NULL` | Número de serie (1, 2, 3...) |
| `weight` | `REAL` | `NOT NULL` | Peso en kg |
| `reps` | `INTEGER` | `NOT NULL` | Repeticiones completadas |
| `rpe` | `REAL` | | Esfuerzo percibido (1.0 - 10.0) |
| `completed` | `BOOLEAN` | `DEFAULT TRUE` | Marcar si se realizó la serie |
