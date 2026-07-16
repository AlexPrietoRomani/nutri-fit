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

---

## F7: Integración de Dataset Público de Ejercicios (free-exercise-db) [X]

> Reconstruido tras INC-007 (el detalle se perdió por gitignore). Código en git (PR #1). Fuente: `yuhonas/free-exercise-db` (Unlicense, 873 ejercicios con imágenes).

### SF7.1: Modelo de Datos y Documentación [X]
- `[X]` **T7.1.1** Extender `training.exercises` (external_id, body_part, target_muscle, secondary_muscles[], force, level, mechanic, instructions JSONB, image_urls[]; id IDENTITY). Verificado en Postgres efímero (13 columnas, FK intacto). `diseno_db.md` actualizado (+ `food_cache`).
- `[X]` **T7.1.2** ADR 6 en `architecture.md` (fuente de datos + Unlicense; descarte de Gym Visual por licencia de media).

### SF7.2: Import y Seed [X]
- `[X]` **T7.2.1** `scripts/generate_exercises_seed.py` (+test pytest) → `docker/postgres/zz_exercises_seed.sql` con 873 INSERT; montado en el init. Verificado: 873 filas en DB limpia. **8/8 tests unitarios.**
- `[X]` **T7.2.2** Media por URL al raw de GitHub (documentado en `diseno_db.md`); muestra de URLs → HTTP 200.

### SF7.3: Frontend [X]
- `[X]` **T7.3.1** Modelo `Exercise` ampliado (parseo TEXT[]/JSONB) + retiro del seed hardcodeado. Tests Dart `Exercise.fromJson` verdes.
- `[X]` **T7.3.2** Render de miniatura + detalle (imagen/instrucciones) en el selector de ejercicios. Verificado por E2E (thumbnails desde GitHub).

---

## F8: Chatbot de IA Multi-Proveedor (OpenAI, Gemini, Claude, OpenRouter, Ollama, LM Studio, vLLM) [X]

> Reconstruido tras INC-007. Código en git (PR #1). Verificado end-to-end con Ollama del host (`llama3.2`).

### SF8.1: Capa de IA Multi-Proveedor (backend) [X]
- `[X]` **T8.1.1** `backend/app/ai_engine.py` (`AIConfig` + `generate`): cliente `openai` con `base_url` por proveedor (OpenAI/OpenRouter/Gemini/LM Studio/vLLM/Ollama) + rama `anthropic` (Claude). **12 tests unitarios** (mock openai/anthropic). Error → 503 claro.
- `[X]` **T8.1.2** Deps `openai`+`anthropic`; `docker-compose` con envs multi-proveedor + `extra_hosts` host.docker.internal; `.env.example`. `docker compose config` OK.

### SF8.2: Endpoints (FastAPI) [X]
- `[X]` **T8.2.1** `/chat` (Q&A con perfil + `AIConfig`). E2E real: respuesta de Ollama.
- `[X]` **T8.2.2** `/generate-meal-plan` (JSON validado coherente con `user_goals`). E2E: plan real.
- `[X]` **T8.2.3** `/generate-workout-plan` — consulta `training.exercises` reales y **filtra `exercise_id` alucinados**. E2E: IDs 44/109/156 (pecho).
- `[X]` **T8.2.4** `/analyze-progress` (coach). **7 tests de integración** (TestClient) para SF8.2.

### SF8.3: Frontend (Ajustes + Chat) y Documentación [X]
- `[X]` **T8.3.1** Pantalla **Ajustes de IA** (desplegable de proveedor + API key/base_url/modelo en `flutter_secure_storage`).
- `[X]` **T8.3.2** Pantalla **Chat** + `AiProvider`. **E2E de UI completo** (Playwright + Ollama): respuesta renderizada. Destapó INC-004 (secure storage web) e INC-005 (CORS).
- `[X]` **T8.3.3** ADR 7 (multi-proveedor) en `architecture.md`; dominio de IA en `description_proyecto.md`. **6 tests Dart** de IA.

---

## F9: IA de Visión en el Frontend (foto → macros / máquina) [X]

> Cierra el hallazgo B1 de la auditoría: `/analyze-meal` y `/identify-machine` existen pero el cliente nunca los llama. Visión multi-proveedor reusando la `AIConfig` de F8; fallback a Ollama `llava` + mock.
> **AC de Fase:** visión en `ai_engine` (openai `image_url` + anthropic `image`) · Diario foto→borrador→`food_logs` · Entrenamiento foto→máquina+ejercicios · ADR + sin secretos.

### SF9.1: Visión Multi-Proveedor (backend) [X]

#### T9.1.1: `ai_engine.generate_vision(cfg, prompt, image_b64)` [X]
- **🧠 Explicación:** Añade una función de visión análoga a `generate`: la rama OpenAI-compatible manda la imagen como content block `{"type":"image_url","image_url":{"url":"data:image/jpeg;base64,..."}}`; la rama Anthropic como bloque `{"type":"image","source":{"type":"base64",...}}`. Reusa el enrutamiento por `provider`/`protocol` y el manejo de errores (`AIEngineError`).
- **💡 Cómo hacerlo:** en `ai_engine.py`, `generate_vision(cfg, prompt, image_b64, want_json=True)`:
  ```python
  def _vision_openai(cfg, prompt, image_b64, want_json):
      from openai import OpenAI
      client = OpenAI(api_key=cfg.api_key or "not-needed", base_url=_resolve_base_url(cfg))
      content = [
          {"type": "text", "text": prompt},
          {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{image_b64}"}},
      ]
      kwargs = {"response_format": {"type": "json_object"}} if want_json else {}
      r = client.chat.completions.create(model=cfg.model or "", messages=[{"role": "user", "content": content}], **kwargs)
      return r.choices[0].message.content or ""

  def _vision_anthropic(cfg, prompt, image_b64, want_json):
      import anthropic
      client = anthropic.Anthropic(api_key=cfg.api_key) if cfg.api_key else anthropic.Anthropic()
      r = client.messages.create(model=cfg.model or DEFAULT_CLAUDE_MODEL, max_tokens=1024, messages=[{"role":"user","content":[
          {"type":"image","source":{"type":"base64","media_type":"image/jpeg","data":image_b64}},
          {"type":"text","text":prompt}]}])
      return next((b.text for b in r.content if b.type=="text"), "")
  ```
- **Acciones:**
  - `[X]` A9.1.1.1: `generate_vision` con ramas openai/anthropic y validación de proveedor.
  - `[X]` A9.1.1.2: Reutilizar `_resolve_base_url`/`AIEngineError`.
- **✅ Tests Unitarios:** con `openai`/`anthropic` mockeados: `provider=claude` usa bloque `image`; providers openai-compat usan `image_url` con el `base_url` correcto; proveedor inválido → `AIEngineError`.
- **🎭 Tests de Simulación de Usuario:** N/A (capa interna).

#### T9.1.2: `/analyze-meal` y `/identify-machine` aceptan `AIConfig` opcional [X]
- **🧠 Explicación:** Hoy usan Ollama `llava` fijo + mock. Se añade un campo `ai: AIConfig` opcional al form; si viene, se usa `generate_vision`; si no, se mantiene el fallback actual (Ollama llava → mock). El parseo del JSON de comida/máquina se valida.
- **💡 Cómo hacerlo:** en `main.py`, aceptar `ai` (JSON string en el multipart) y `file`/`image_url`; construir el prompt existente y llamar `ai_engine.generate_vision(cfg, prompt, image_b64, want_json=True)`; en except → mock actual.
- **Acciones:**
  - `[X]` A9.1.2.1: Parsear `AIConfig` opcional del form en ambos endpoints.
  - `[X]` A9.1.2.2: Rama con `generate_vision` + fallback Ollama/mock preservado.
- **✅ Tests Unitarios:** con motor mockeado, `/analyze-meal` con `ai` devuelve el JSON del proveedor; sin `ai` o con fallo → mock (200).
- **🎭 Tests de Simulación de Usuario:** subir una foto y recibir un borrador (real o mock) no vacío.

### SF9.2: Cámara y Flujos (frontend) [X]

#### T9.2.1: Dep `image_picker` + servicio de subida [X]
- **🧠 Explicación:** `image_picker` para cámara/galería (móvil y web). Un servicio que toma la imagen, la codifica y hace `multipart POST` al `ai_service` con la `AIConfig` guardada (F8).
- **💡 Cómo hacerlo:** añadir `image_picker` a `pubspec.yaml`; `vision_service.dart` con `analyzeMeal(XFile, AIConfig)` e `identifyMachine(...)` usando `http.MultipartRequest` a `AppConstants.aiServiceUrl`.
- **Acciones:**
  - `[X]` A9.2.1.1: Añadir `image_picker` a `pubspec.yaml`.
  - `[X]` A9.2.1.2: `vision_service.dart` (captura + multipart + AIConfig).
- **✅ Tests Unitarios:** el servicio arma el multipart con el campo `ai` y parsea la respuesta (mock HTTP).
- **🎭 Tests de Simulación de Usuario:** cubierto en T9.2.2/T9.2.3.

#### T9.2.2: Diario — "Tomar foto con IA" → confirmar → `food_logs` [X]
- **🧠 Explicación:** Botón en `diary_screen.dart` que abre cámara/galería, llama `/analyze-meal`, muestra el borrador en un diálogo (nombre/calorías/macros editables) y al confirmar usa `NutritionProvider.addFoodLog(...)`.
- **💡 Cómo hacerlo:** botón → `ImagePicker().pickImage` → `visionService.analyzeMeal` → diálogo de confirmación → `addFoodLog`.
- **Acciones:**
  - `[X]` A9.2.2.1: Botón + captura en `diary_screen.dart`.
  - `[X]` A9.2.2.2: Diálogo de borrador editable.
  - `[X]` A9.2.2.3: Confirmar → `addFoodLog` + refresco de la lista.
- **✅ Tests Unitarios:** el mapeo respuesta→borrador y borrador→payload de `addFoodLog` es correcto.
- **🎭 Tests de Simulación de Usuario:** elegir foto → ver borrador → confirmar → la comida aparece en el Diario y en `nutrition.food_logs`.

#### T9.2.3: Entrenamiento — "Escanear máquina con IA" [X]
- **🧠 Explicación:** Botón que llama `/identify-machine` y muestra máquina, músculos objetivo, ejercicios sugeridos y tips de seguridad.
- **💡 Cómo hacerlo:** botón en la pantalla de entrenamiento → `visionService.identifyMachine` → hoja/diálogo con la ficha.
- **Acciones:**
  - `[X]` A9.2.3.1: Botón + captura.
  - `[X]` A9.2.3.2: Vista de ficha de máquina (músculos, ejercicios, tips).
- **✅ Tests Unitarios:** parseo de `MachineIdentificationResponse` en el cliente.
- **🎭 Tests de Simulación de Usuario:** escanear una máquina → ver su ficha con ejercicios sugeridos.

### SF9.3: Documentación [X]

#### T9.3.1: ADR/flujo de visión en `architecture.md` [X]
- **🧠 Explicación:** Formalizar que la visión también es multi-proveedor (imagen base64) y el flujo cámara→endpoint→confirmación.
- **💡 Cómo hacerlo:** ampliar el ADR de IA (o ADR 8) con la rama de visión y el flujo del Diario/Entrenamiento.
- **Acciones:**
  - `[X]` A9.3.1.1: Documentar la visión multi-proveedor en `architecture.md`.
- **✅ Tests Unitarios:** N/A (docs).
- **🎭 Tests de Simulación de Usuario:** N/A.
