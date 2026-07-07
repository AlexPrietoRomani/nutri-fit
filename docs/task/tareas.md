# Tablero de Tareas: Nutri-Fit Modular

Este tablero sigue el desarrollo fase a fase de la infraestructura y el diseño de la UI/UX vinculada al backend.

## Fuentes de Contexto Obligatorias
- [description_proyecto.md](../description_proyecto.md)
- [architecture.md](../architecture/architecture.md)
- [diseno_db.md](../db/diseno_db.md)

---

## F1: Setup de Infraestructura Modular [x]

### SF1.1: Docker & PostgreSQL Schemas Setup [x]

#### T1.1.1: Configurar Supabase Local y Docker Compose [x]
- **🧠 Explicación:** Dockerizar todo el backend incluyendo base de datos y microservicios de IA.
- **Acciones:**
  - `[x]` A1.1.1.1: Crear `docker-compose.yml` en la raíz incluyendo Supabase, FastAPI y Ollama.
  - `[x]` A1.1.1.2: Inicializar stack de Supabase local.

#### T1.1.2: Crear Estructura de Esquemas de PostgreSQL [x]
- **🧠 Explicación:** Crear y aislar las tablas en esquemas `public`, `nutrition` y `training`.
- **💡 Cómo hacerlo:**
  ```sql
  -- Crear esquemas separados
  CREATE SCHEMA IF NOT EXISTS nutrition;
  CREATE SCHEMA IF NOT EXISTS training;
  
  -- Tabla inicial de perfiles físicos
  CREATE TABLE public.users (
    id UUID PRIMARY KEY,
    name TEXT NOT NULL,
    birth_date DATE NOT NULL,
    gender CHAR(1) CHECK (gender IN ('M', 'F')),
    height_cm REAL NOT NULL,
    body_type TEXT,
    pal_level REAL DEFAULT 1.2 NOT NULL
  );
  ```
- **Acciones:**
  - `[x]` A1.1.2.1: Crear script de migración para inicializar los esquemas y tablas básicas.
  - `[x]` A1.1.2.2: Aplicar la migración SQL al contenedor Postgres.

### SF1.2: Configuración Inicial de Flutter [x]

#### T1.2.1: Inicializar Estructura del Frontend y Dependencias [x]
- **🧠 Explicación:** Crear el scaffolding del proyecto Flutter y configurar las dependencias clave.
- **Acciones:**
  - `[x]` A1.2.1.1: Crear estructura de carpetas (`frontend/lib/core`, `frontend/lib/features`, etc.).
  - `[x]` A1.2.1.2: Configurar `pubspec.yaml` con `supabase_flutter`, `provider` y `uuid`.

#### T1.2.2: Inicialización del SDK de Supabase [x]
- **🧠 Explicación:** Configurar el punto de entrada de la aplicación y la conexión local a Supabase.
- **Acciones:**
  - `[x]` A1.2.2.1: Crear configuración y constantes de inicialización para `localhost:54322`.
  - `[x]` A1.2.2.2: Crear `main.dart` realizando la llamada a la inicialización del cliente.

---

## F2: Diseño de UI y Mapeo de Eventos en Flutter [x]

### SF2.1: Implementación del Flujo del Dashboard y Onboarding [x]

#### T2.1.1: UI y Cuestionario del Onboarding [x]
- 🧠 Explicación: Pantalla interactiva en Flutter para capturar datos físicos del usuario al inicio.
- Acciones:
  - `[x]` A2.1.1.1: Crear interfaz con carrusel de preguntas en Flutter.
  - `[x]` A2.1.1.2: Implementar el cálculo de BMR (Mifflin) local en la app al presionar "Calcular".

#### T2.1.2: Clic a Base de Datos - Guardar Perfil [x]
- 🧠 Explicación: El clic del botón final en Onboarding debe impactar al backend insertando en `users` y `nutrition.user_goals`.
- 💡 Cómo hacerlo:
  ```dart
  // Flutter/Supabase insert
  await supabase.from('users').insert({
    'id': userId,
    'name': name,
    'birth_date': birthDate.toIso8601String(),
    'gender': gender,
    'height_cm': height,
    'body_type': bodyType,
    'pal_level': pal,
  });
  ```
- Acciones:
  - `[x]` A2.1.2.1: Configurar llamada API de Supabase en el controlador del carrusel de onboarding en Flutter.
  - `[x]` A2.1.2.2: Escribir tests unitarios para verificar inserciones correctas.


---

## F3: Construcción - Módulo de Nutrición (Fitia/OpenNutriTracker) [x]

### SF3.1: Diario Alimenticio y Metas Diarias [x]

#### T3.1.1: Controlador y UI del Diario Alimenticio [x]
- **🧠 Explicación:** Crear la vista dividida del diario (Desayuno, Almuerzo, Cena, Snacks) mostrando consumo calórico contra el objetivo.
- **Acciones:**
  - `[x]` A3.1.1.1: Crear la vista principal `diary_screen.dart` con divisiones y barra de progreso.
  - `[x]` A3.1.1.2: Crear el controlador de estado `nutrition_provider.dart` para manejar los logs del diario y metas.

#### T3.1.2: Conexión con Supabase y CRUD [x]
- **🧠 Explicación:** Conectar las acciones de agregar y eliminar alimentos con las tablas `nutrition.food_logs` y `nutrition.user_goals`.
- **Acciones:**
  - `[x]` A3.1.2.1: Implementar consultas de lectura y borrado en `NutritionProvider`.
  - `[x]` A3.1.2.2: Vincular botones e inputs de comida manual en `DiaryScreen`.

### SF3.2: Integración de OpenFoodFacts (Escáner de Código de Barras) [x]

#### T3.2.1: Escáner Simulado y Búsqueda de Productos [x]
- **🧠 Explicación:** Permitir simulación e ingreso de códigos de barras, y mockear la búsqueda de alimentos de OpenFoodFacts.
- **Acciones:**
  - `[x]` A3.2.1.1: Implementar cuadro de diálogo para escaneo con códigos de barra de prueba predefinidos en `DiaryScreen`.
  - `[x]` A3.2.1.2: Crear lógica de simulación de consulta externa y decodificación de macros en `NutritionProvider`.

#### T3.2.2: Caché de Alimentos en Base de Datos [x]
- **🧠 Explicación:** Almacenar los alimentos consultados con éxito en una caché de base de datos para no repetir la llamada externa.
- **Acciones:**
  - `[x]` A3.2.2.1: Crear la tabla `nutrition.food_cache` en PostgreSQL (`init.sql`).
  - `[x]` A3.2.2.2: Implementar lógica de lectura en caché antes de hacer la búsqueda mock y guardar los resultados del query exitoso.

#### T3.2.3: Pruebas Unitarias e Integración [x]
- **🧠 Explicación:** Escribir y verificar las pruebas unitarias e integradas para la lógica de alimentos, macros y la caché de códigos de barra.
- **Acciones:**
  - `[x]` A3.2.3.1: Crear archivo de pruebas `frontend/test/nutrition_test.dart` simulando los llamados a Supabase de forma correcta.

---

## F4: Construcción - Módulo de Entrenamiento (Strong/LiftLog) [x]

### SF4.1: Catálogo y Creador de Rutinas [x]
- `[x]` T4.1.1: Precargar tabla `training.exercises` con ejercicios base.
- `[x]` T4.1.2: Permitir diseño de rutinas personalizadas segmentadas por equipamiento.

### SF4.2: Tracker de Entrenamiento en Vivo [x]
- `[x]` T4.2.1: Implementar cronómetro y vista interactiva para marcar series (sets) como completados.
- `[x]` T4.2.2: Registro de datos de peso, reps y RPE en `training.workout_sets`.

---

## F5: Microservicio e IA de Visión (Self-Hosted) [x]

### SF5.1: API Gateway (FastAPI) [x]
- `[x]` T5.1.1: Implementar endpoint en Python para recibir fotos subidas de Supabase Storage.
- `[x]` T5.1.2: Configurar llamadas a modelos Vision de Ollama (local) o Gemini (fallback en la nube).

### SF5.2: Detección Automática de Comida y Máquinas [x]
- `[x]` T5.2.1: Pipeline de detección de calorías y macros de platos a partir de fotos.
- `[x]` T5.2.2: Pipeline de identificación de máquinas del gimnasio y mapeo de ejercicios aptos.

---

## F6: Dashboard y Métricas de Progreso [x]

### SF6.1: Balance Calórico Real e Interactividad [x]
- `[x]` T6.1.1: Diseñar e implementar el Dashboard unificado en `dashboard_screen.dart` integrando `NutritionProvider` y `TrainingProvider`.
- `[x]` T6.1.2: Mostrar balance calórico interactivo: `Objetivo - Ingerido + Quemado` indicando si está en Déficit/Superávit.
- `[x]` T6.1.3: Agregar barras de macronutrientes diarios e indicador de adherencia semanal.
- `[x]` T6.1.4: Registrar ruta `/dashboard` y reconfigurar la navegación en `main.dart`.
- `[x]` T6.1.5: Escribir pruebas unitarias para la fórmula del balance calórico.
