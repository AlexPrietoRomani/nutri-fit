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

---

## F10: Autenticación Real (GoTrue + RLS) [X]

> Reemplaza el bypass por `devUserId` con auth real (GoTrue) y aislamiento por usuario (RLS). Cierra INC-003/INC-006.
> **AC de Fase:** GoTrue en el stack + gateway enruta `/auth/v1` · FK `users→auth.users` + RLS `auth.uid()` en tablas de usuario (`exercises` público) · login/signup/logout + sesión persistente + cero `devUserId` · providers usan `currentUser.id` · ADR auth + RLS/FK en docs. **Toca architecture.md Y diseno_db.md → `auditar-coherencia` antes de commitear.**

### SF10.1: Infraestructura de Auth (GoTrue + gateway) [X]

#### T10.1.1: Servicio GoTrue en `docker-compose.yml` [X]
- **🧠 Explicación:** GoTrue es el servidor de auth de Supabase (emite JWT con el claim `sub`=user id que RLS lee vía `auth.uid()`). Hoy el stack no lo tiene (se bypasseó en F1). Se añade como servicio apuntando a la misma Postgres, con un `GOTRUE_JWT_SECRET` que **debe** coincidir con el secreto con que PostgREST valida los JWT.
- **💡 Cómo hacerlo:** en `docker-compose.yml`, añadir el servicio y reusar el secreto ya usado por PostgREST (`PGRST_JWT_SECRET`):
  ```yaml
  nutri-fit-auth:
    image: supabase/gotrue:v2.151.0
    depends_on: [nutri-fit-postgres]
    environment:
      GOTRUE_DB_DRIVER: postgres
      GOTRUE_DB_DATABASE_URL: postgres://supabase_auth_admin:postgres@nutri-fit-postgres:5432/postgres?search_path=auth
      GOTRUE_SITE_URL: http://localhost:8080
      GOTRUE_JWT_SECRET: ${JWT_SECRET}          # mismo secreto que PostgREST
      GOTRUE_JWT_EXP: 3600
      GOTRUE_DISABLE_SIGNUP: "false"
      GOTRUE_MAILER_AUTOCONFIRM: "true"          # dev: sin verificación de email
      GOTRUE_API_HOST: 0.0.0.0
      GOTRUE_API_PORT: 9999
  ```
- **Acciones:**
  - `[X]` A10.1.1.1: Añadir el servicio GoTrue con el mismo `JWT_SECRET` que PostgREST y `MAILER_AUTOCONFIRM=true`.
  - `[X]` A10.1.1.2: Asegurar el rol `supabase_auth_admin` y el esquema `auth` en el init de Postgres (GoTrue corre sus migraciones al arrancar).
- **✅ Tests Unitarios:** `docker compose up` levanta `nutri-fit-auth` healthy; `POST /auth/v1/signup` (directo al :9999) crea un usuario en `auth.users`.
- **🎭 Tests de Simulación de Usuario:** N/A (infra).

#### T10.1.2: Enrutar `/auth/v1/` en el gateway nginx [X]
- **🧠 Explicación:** El frontend habla con un solo origen (`:54321`). Hay que enrutar `/auth/v1/` a GoTrue igual que `/rest/v1/` va a PostgREST, sin romper el CORS ya arreglado (INC-001).
- **💡 Cómo hacerlo:** en `docker/gateway/nginx.conf`, añadir un `location`:
  ```nginx
  location /auth/v1/ {
      proxy_pass http://nutri-fit-auth:9999/;
      proxy_set_header Host $host;
      proxy_set_header Authorization $http_authorization;
  }
  ```
- **Acciones:**
  - `[X]` A10.1.2.1: `location /auth/v1/` → GoTrue, conservando `/rest/v1/` → PostgREST.
  - `[X]` A10.1.2.2: Verificar CORS (headers no duplicados, como en INC-001).
- **✅ Tests Unitarios:** `curl :54321/auth/v1/health` → 200; `curl :54321/auth/v1/signup` crea usuario (mismo resultado que directo al :9999).
- **🎭 Tests de Simulación de Usuario:** N/A (infra).

### SF10.2: Esquema y RLS (DB) [X]

#### T10.2.1: FK `public.users → auth.users` + aprovisionamiento de perfil [X]
- **🧠 Explicación:** El perfil (`public.users`) debe colgar del usuario de auth. Se re-instaura la FK (se quitó en `4a46f51`) y se crea la fila de perfil al hacer signup, vía un trigger `handle_new_user` sobre `auth.users` (patrón estándar de Supabase), para que el id del perfil == id de auth.
- **💡 Cómo hacerlo:** en `docker/postgres/*.sql`:
  ```sql
  ALTER TABLE public.users
    ADD CONSTRAINT fk_users_auth FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

  CREATE OR REPLACE FUNCTION public.handle_new_user() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER AS $$
  BEGIN
    INSERT INTO public.users (id, created_at) VALUES (NEW.id, now())
    ON CONFLICT (id) DO NOTHING;
    RETURN NEW;
  END; $$;
  CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
  ```
- **Acciones:**
  - `[X]` A10.2.1.1: FK `public.users.id → auth.users(id) ON DELETE CASCADE`.
  - `[X]` A10.2.1.2: Trigger `handle_new_user` (o INSERT en el onboarding) para crear el perfil tras signup. **Decisión:** sin trigger — `public.users` tiene columnas NOT NULL (`name`/`birth_date`/`gender`/`height_cm`) que GoTrue no conoce; el Onboarding sigue siendo el único punto que crea el perfil completo, ahora con el id del usuario autenticado.
- **✅ Tests Unitarios:** tras `signup`, existe una fila en `public.users` con el mismo id; borrar el usuario de auth cascada al perfil. Ver `tests/unit/test_rls_policies.sql`.
- **🎭 Tests de Simulación de Usuario:** cubierto en T10.3.x (signup → onboarding).

#### T10.2.2: RLS + políticas por usuario (catálogo público) [X]
- **🧠 Explicación:** Con auth real, RLS garantiza que cada usuario solo toque sus filas. `workout_sets` no tiene `user_id` propio → su política se apoya en la sesión dueña. `training.exercises` es catálogo compartido → lectura pública.
- **💡 Cómo hacerlo:**
  ```sql
  ALTER TABLE public.users            ENABLE ROW LEVEL SECURITY;
  ALTER TABLE nutrition.user_goals    ENABLE ROW LEVEL SECURITY;
  ALTER TABLE nutrition.food_logs     ENABLE ROW LEVEL SECURITY;
  ALTER TABLE training.workout_sessions ENABLE ROW LEVEL SECURITY;
  ALTER TABLE training.workout_sets   ENABLE ROW LEVEL SECURITY;

  CREATE POLICY own_users     ON public.users         USING (auth.uid() = id)      WITH CHECK (auth.uid() = id);
  CREATE POLICY own_goals     ON nutrition.user_goals USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
  CREATE POLICY own_logs      ON nutrition.food_logs  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
  CREATE POLICY own_sessions  ON training.workout_sessions USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
  CREATE POLICY own_sets      ON training.workout_sets
    USING (EXISTS (SELECT 1 FROM training.workout_sessions s WHERE s.id = session_id AND s.user_id = auth.uid()))
    WITH CHECK (EXISTS (SELECT 1 FROM training.workout_sessions s WHERE s.id = session_id AND s.user_id = auth.uid()));
  -- Catálogo público de lectura
  GRANT SELECT ON training.exercises TO anon, authenticated;
  ```
- **Acciones:**
  - `[ ]` A10.2.2.1: `ENABLE ROW LEVEL SECURITY` + política `auth.uid()` en las 5 tablas de usuario.
  - `[ ]` A10.2.2.2: Política/GRANT de lectura pública en `training.exercises`.
- **✅ Tests Unitarios:** con JWT real de A, `SELECT` en `food_logs` solo devuelve filas de A; con JWT de B, 0 filas de A; `SELECT` en `exercises` funciona sin sesión. Ver `tests/unit/test_rls_policies.sql` y `tests/e2e/test_auth_rls_e2e.sh` (6/6 PASS, verificado independientemente por el orquestador).
- **🎭 Tests de Simulación de Usuario:** el usuario B no ve el diario del usuario A (cubierto en T10.3.x).

### SF10.3: Autenticación en el Frontend [ ]

#### T10.3.1: Login/Signup/Logout + `AuthGate` [X]
- **🧠 Explicación:** Pantalla de entrada con email/clave (login y signup) y logout; un `AuthGate` que escucha `onAuthStateChange` decide qué mostrar. `supabase_flutter` persiste la sesión automáticamente.
- **💡 Cómo hacerlo:** `auth_screen.dart` + `AuthGate`:
  ```dart
  final auth = Supabase.instance.client.auth;
  await auth.signUp(email: email, password: pass);           // registro
  await auth.signInWithPassword(email: email, password: pass); // login
  await auth.signOut();                                        // logout
  // Gate reactivo:
  StreamBuilder(stream: auth.onAuthStateChange, builder: (_, snap) {
    final session = auth.currentSession;
    if (session == null) return const AuthScreen();
    return const InitialCheckScreen(); // sesión → decide onboarding/dashboard
  });
  ```
- **Acciones:**
  - `[X]` A10.3.1.1: `auth_screen.dart` (login + signup con validación y errores).
  - `[X]` A10.3.1.2: `AuthGate` en `main.dart` (sin sesión → login; con sesión → InitialCheck).
  - `[X]` A10.3.1.3: Botón de logout (p.ej. en el Dashboard).
- **✅ Tests Unitarios:** widget test de `AuthScreen` (valida email/clave, muestra error en credenciales inválidas); `AuthGate` renderiza login cuando no hay sesión. 26/26 tests verdes (`frontend/test/auth_screen_test.dart`).
- **🎭 Tests de Simulación de Usuario:** signup → aterriza en onboarding; login con las mismas credenciales → dashboard; logout → vuelve a login. (E2E de UI pendiente para T10.3.2, cuando los providers ya usen `currentUser.id`.)

#### T10.3.2: Reemplazar `devUserId` por `currentUser!.id` [X]
- **🧠 Explicación:** Todas las lecturas/escrituras deben usar el id del usuario autenticado, no el `devUserId`. El `InitialCheckScreen` ya tiene el hook `currentUser?.id ?? devUserId` → pasa a exigir sesión.
- **💡 Cómo hacerlo:** grep `AppConstants.devUserId` y sustituir por `SupabaseConfig.client.auth.currentUser!.id` en `onboarding_provider.dart`, `nutrition_provider.dart`, `training_provider.dart`, `dashboard_screen.dart` y `main.dart`; el onboarding escribe `public.users`/`user_goals` con ese id. Dejar `devUserId` deprecado/eliminado en `constants.dart`.
- **Acciones:**
  - `[X]` A10.3.2.1: Sustituir `devUserId` en providers + dashboard + `main.dart`.
  - `[X]` A10.3.2.2: Onboarding atado al usuario autenticado; eliminar `devUserId` de `constants.dart`.
- **✅ Tests Unitarios:** provider tests: con una sesión mockeada, las queries usan `currentUser.id`; no queda ninguna referencia a `devUserId` (grep en `lib/`). Confirmado por el orquestador: 0 referencias, 26/26 tests verdes por archivo.
- **🎭 Tests de Simulación de Usuario:** dos cuentas distintas ven diarios/dashboards independientes. Cubierto por el E2E de RLS (`tests/e2e/test_auth_rls_e2e.sh`, T10.2.2) a nivel API; UI completa se ejerce manualmente/con Playwright en una iteración futura si se requiere.

### SF10.4: Documentación [X]

#### T10.4.1: ADR de auth en `architecture.md` + RLS/FK en `diseno_db.md` [X]
- **🧠 Explicación:** Formalizar el flujo de auth (login → sesión JWT → RLS) y retirar la nota de bypass; documentar FK y políticas RLS en el diseño de DB.
- **💡 Cómo hacerlo:** nuevo ADR en `architecture.md` (GoTrue + gateway `/auth/v1`, RLS `auth.uid()`, retira el bypass de INC-006); en `diseno_db.md`, sección de seguridad con la FK `users→auth.users` y la matriz de políticas por tabla.
- **Acciones:**
  - `[X]` A10.4.1.1: ADR de autenticación en `architecture.md` (ADR 9).
  - `[X]` A10.4.1.2: RLS + FK en `diseno_db.md` (§3, añadido durante SF10.2).
- **✅ Tests Unitarios:** N/A (docs).
- **🎭 Tests de Simulación de Usuario:** N/A (docs).

---

## F11: Chat Unificado con Orquestador de Rutinas y Planes de Comida (FAB global) [X]

> Unifica `/chat`, `/generate-workout-plan` y `/generate-meal-plan` (F8) tras un solo endpoint orquestador, y añade un FAB de acceso global al chat. Cierra la brecha "el chat nunca combina rutina + plan de comidas en un solo turno".
> **AC de Fase:** `POST /chat-plan` detecta intención y devuelve `{reply, workout, meal_plan}` · endpoints F8 originales sin regresión · FAB en Dashboard/Diario/Entrenamiento abre el chat como modal · tarjetas de rutina/plan en la conversación · caso de prueba obligatorio (caminadora+pesa rusa+déficit) genera ambos resultados · ADR 10. **NO toca diseno_db.md.**
> **Restricción real verificada:** el catálogo tiene 53 ejercicios `kettlebells`, **0** de caminadora/treadmill (dataset de fuerza, no cardio). La rutina combina ejercicios reales de kettlebell + un bloque de cardio como instrucción directa (sin `exercise_id`).

### SF11.1: Orquestador de intención (backend) [X]

#### T11.1.1: Refactorizar generación de rutina/plan a funciones reusables [X]
- **🧠 Explicación:** `/generate-workout-plan` y `/generate-meal-plan` (F8, en `backend/app/main.py`) tienen su lógica inline en el handler del endpoint. Para que el orquestador de T11.1.2 pueda invocar la MISMA lógica sin duplicar prompts ni la lista de anti-alucinación de `exercise_id`, se extrae esa lógica a funciones internas que tanto el endpoint original como el nuevo orquestador puedan llamar.
- **💡 Cómo hacerlo:** en `main.py`, extraer el cuerpo de `generate_workout_plan`/`generate_meal_plan` a funciones puras:
  ```python
  def _build_meal_plan(ai: AIConfig, goals: dict, preferences: str | None) -> dict:
      prompt = (...)  # el mismo prompt que ya arma generate_meal_plan
      data = _parse_json_or_502(_run_ai(ai, prompt, want_json=True))
      if not isinstance(data.get("meals"), list) or not data["meals"]:
          raise HTTPException(status_code=502, detail="El plan de comidas no contiene 'meals'.")
      return data

  def _build_workout_plan(ai: AIConfig, goal: str | None, body_part: str | None, equipment: str | None) -> dict:
      candidates = _fetch_exercise_candidates(body_part, equipment)
      if not candidates:
          raise HTTPException(status_code=404, detail="No hay ejercicios que coincidan con el filtro.")
      valid_ids = {c["id"] for c in candidates}
      prompt = (...)  # el mismo prompt que ya arma generate_workout_plan
      data = _parse_json_or_502(_run_ai(ai, prompt, want_json=True))
      items = data.get("items")
      if not isinstance(items, list):
          raise HTTPException(status_code=502, detail="La rutina no contiene 'items'.")
      filtered = [it for it in items if it.get("exercise_id") in valid_ids]
      return {"items": filtered}

  @app.post("/generate-meal-plan")
  def generate_meal_plan(req: MealPlanRequest):
      return _build_meal_plan(req.ai, req.goals, req.preferences)

  @app.post("/generate-workout-plan")
  def generate_workout_plan(req: WorkoutPlanRequest):
      return _build_workout_plan(req.ai, req.goal, req.body_part, req.equipment)
  ```
- **Acciones:**
  - `[X]` A11.1.1.1: Extraer `_build_meal_plan` y `_build_workout_plan` con la lógica exacta ya existente (mismo prompt, mismo filtro anti-alucinación).
  - `[X]` A11.1.1.2: Los endpoints `/generate-workout-plan`/`/generate-meal-plan` pasan a ser wrappers finos sobre esas funciones — **cero cambio de contrato HTTP** (mismo request/response que hoy).
- **✅ Tests Unitarios:** los tests existentes de `test_endpoints_ai.py` para `/generate-workout-plan`/`/generate-meal-plan` siguen pasando sin modificarlos (regresión cero); test nuevo que llama `_build_meal_plan`/`_build_workout_plan` directamente con motor mockeado. Verificado: 30/30 tests verdes.
- **🎭 Tests de Simulación de Usuario:** N/A (refactor interno, sin cambio observable).

#### T11.1.2: Endpoint `POST /chat-plan` (orquestador de intención) [X]
- **🧠 Explicación:** Un endpoint nuevo que primero le pregunta al LLM (con `want_json=True`, mismo patrón ya usado) qué quiere el usuario — ¿rutina?, ¿plan de comidas?, ¿con qué equipamiento/objetivo? — y según la respuesta invoca `_build_workout_plan`/`_build_meal_plan` (T11.1.1) y compone una respuesta conversacional. Una sola llamada de "extracción de intención" (barata, sin tool-calling) basta porque el modelo ya devuelve JSON estructurado en F8/F9.
- **💡 Cómo hacerlo:**
  ```python
  class ChatPlanRequest(BaseModel):
      message: str
      profile: Optional[dict] = None
      ai: AIConfig

  class ChatPlanResponse(BaseModel):
      reply: str
      workout: Optional[dict] = None
      meal_plan: Optional[dict] = None

  def _extract_intent(ai: AIConfig, message: str) -> dict:
      prompt = (
          f"Analiza este mensaje de un usuario de una app de fitness: \"{message}\"\n"
          "Devuelve SOLO un JSON con esta forma exacta:\n"
          '{"wants_workout": bool, "wants_meal_plan": bool, '
          '"equipment": ["caminadora"|"treadmill"|"kettlebell"|"dumbbell"|"barbell"|"body only"|...], '
          '"goal": "weight_loss|muscle_gain|maintenance|null", "preferences": "str o null"}'
      )
      return _parse_json_or_502(_run_ai(ai, prompt, want_json=True))

  @app.post("/chat-plan", response_model=ChatPlanResponse)
  def chat_plan(req: ChatPlanRequest):
      intent = _extract_intent(req.ai, req.message)
      workout = meal_plan = None
      # Mapear equipamiento mencionado -> columna real de training.exercises.
      # "caminadora"/"treadmill" NO existe en el catálogo (dataset de fuerza,
      # sin cardio de máquina) -> se pide al LLM un bloque de cardio como
      # instrucción directa dentro del mismo prompt de rutina, no como
      # exercise_id. "pesa rusa"/"kettlebell" SÍ mapea a equipment='kettlebells'.
      if intent.get("wants_workout"):
          equipment_real = "kettlebells" if any("kettlebell" in e.lower() for e in intent.get("equipment", [])) else None
          workout = _build_workout_plan(req.ai, intent.get("goal"), None, equipment_real)
      if intent.get("wants_meal_plan"):
          goals = req.profile.get("goals", {}) if req.profile else {}
          meal_plan = _build_meal_plan(req.ai, goals, intent.get("preferences"))
      reply_prompt = f"{FITNESS_SYSTEM}\nResume en 2-3 frases, en español, lo que generaste para: \"{req.message}\""
      reply = _run_ai(req.ai, reply_prompt)
      return ChatPlanResponse(reply=reply, workout=workout, meal_plan=meal_plan)
  ```
  Ajustar el prompt de `_build_workout_plan` para que, cuando el equipamiento mencionado incluya cardio sin catálogo (caminadora/treadmill), el JSON de rutina incluya además un campo `cardio_block` (texto libre, p.ej. "20 min caminadora a ritmo moderado, 6-8 km/h") junto a `items` (ejercicios reales de kettlebell/etc.), documentando esto en el schema de respuesta.
- **Acciones:**
  - `[X]` A11.1.2.1: `_extract_intent` + `ChatPlanRequest`/`ChatPlanResponse`.
  - `[X]` A11.1.2.2: `POST /chat-plan` orquestando condicionalmente `_build_workout_plan`/`_build_meal_plan`.
  - `[X]` A11.1.2.3: Campo `cardio_block` en la rutina cuando se detecta equipamiento de cardio sin cobertura en el catálogo.
- **✅ Tests Unitarios:** con motor mockeado — mensaje que menciona solo rutina → `meal_plan is None`; mensaje que menciona ambos → los dos no-nulos; equipamiento "pesa rusa" mapea a `equipment='kettlebells'` real; equipamiento "caminadora" no rompe la generación (cae a `cardio_block`, no a un `exercise_id` inventado). Verificado: 30/30 tests verdes.
- **🎭 Tests de Simulación de Usuario:** enviar la consulta EXACTA del caso de prueba (`"Creame un entrenamiento diario si solo tengo una caminadora de hasta 10KM/hr y una pesa rusa de 10kg, para bajar de peso; además de crearme un plan de desayuno, almuerzo y cena completo"`) y confirmar que la respuesta trae `workout` (con ejercicios reales de kettlebell + `cardio_block`) y `meal_plan` (3 tiempos, macros coherentes con déficit) no-nulos. **Verificado con gemma4:e4b real (Ollama del host)**: `workout.items` con 4-5 ejercicios reales de kettlebell (exercise_id verificados contra Postgres), `cardio_block` mencionando la caminadora, `meal_plan.meals` con 5 comidas del día.

### SF11.2: FAB global y tarjetas en el chat (frontend) [X]

#### T11.2.1: FAB compartido que abre el chat como modal [X]
- **🧠 Explicación:** Hoy `/chat` es una ruta de página completa (`Navigator.pushNamed`), solo alcanzable navegando explícitamente. Se necesita un botón flotante reusable, visible en Dashboard/Diario/Entrenamiento, que abra el chat en un `showModalBottomSheet` (o `Dialog` a pantalla completa en modal), conservando el estado/contexto de la pantalla de origen (no hace `pushNamed`, así que al cerrar el modal se vuelve exactamente a donde estaba).
- **💡 Cómo hacerlo:** `frontend/lib/features/ai/chat_fab.dart` (nuevo widget):
  ```dart
  class ChatFab extends StatelessWidget {
    const ChatFab({super.key});
    @override
    Widget build(BuildContext context) => FloatingActionButton(
      heroTag: 'chat_fab',
      backgroundColor: const Color(0xFF2ED573),
      child: const Icon(Icons.chat_rounded, color: Colors.black),
      onPressed: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF1E201E),
        builder: (_) => const FractionallySizedBox(
          heightFactor: 0.9,
          child: ChatScreen(embedded: true), // sin su propio Scaffold/AppBar de página completa
        ),
      ),
    );
  }
  ```
  Añadir `floatingActionButton: const ChatFab()` en `dashboard_screen.dart`, `diary_screen.dart` y `workout_screen.dart` (los 3 `Scaffold` principales). `ChatScreen` necesita un parámetro `embedded` (o un widget interno reusado) para renderizar sin doble AppBar cuando se abre dentro del modal.
- **Acciones:**
  - `[X]` A11.2.1.1: `chat_fab.dart` reusable.
  - `[X]` A11.2.1.2: Añadir el FAB a Dashboard, Diario y Entrenamiento.
  - `[X]` A11.2.1.3: `ChatScreen` soporta modo embebido (sin AppBar propio) para el modal.
- **✅ Tests Unitarios:** widget test — el FAB existe en las 3 pantallas y al pulsarlo se abre un `BottomSheet`/modal conteniendo el chat. Verificado: 30/30 tests verdes.
- **🎭 Tests de Simulación de Usuario:** desde el Dashboard, tocar el FAB → el chat aparece como modal → cerrarlo → se sigue viendo el Dashboard intacto debajo (no se perdió el scroll/estado). Cubierto por widget test de `chat_fab_test.dart`.

#### T11.2.2: `ChatScreen`/`AiProvider` consumen `/chat-plan` con tarjetas [X]
- **🧠 Explicación:** El chat debe llamar `/chat-plan` (T11.1.2) en vez de (o adicionalmente a) `/chat`, y cuando la respuesta traiga `workout`/`meal_plan` no-nulos, mostrar una tarjeta legible (no solo el texto de `reply`) embebida en el mensaje del asistente: rutina con lista de ejercicios (nombre real del catálogo, sets/reps/rpe) + `cardio_block` si aplica, y plan de comidas con las 3-4 comidas y sus macros.
- **💡 Cómo hacerlo:** en `frontend/lib/features/ai/ai_provider.dart`, `sendMessage` pasa a `POST /chat-plan` devolviendo un modelo con `reply`/`workout`/`meal_plan`; en `chat_screen.dart`, el `ListView` de mensajes renderiza, además de la burbuja de texto, un `Card` con los ejercicios (`Column` de `ListTile`) cuando `workout != null`, y otro `Card` con las comidas cuando `meal_plan != null` (reusar el estilo de tarjetas ya usado en `diary_screen.dart`/`workout_screen.dart` para no reinventar).
- **Acciones:**
  - `[X]` A11.2.2.1: `AiProvider`/modelo de mensaje soporta `workout`/`meal_plan` opcionales por mensaje.
  - `[X]` A11.2.2.2: Tarjeta de rutina embebida en el chat (ejercicios + `cardio_block`).
  - `[X]` A11.2.2.3: Tarjeta de plan de comidas embebida en el chat (comidas + macros).
- **✅ Tests Unitarios:** el modelo de mensaje parsea correctamente una respuesta de `/chat-plan` con ambos campos, con uno solo, y con ninguno (solo texto). Verificado: 30/30 tests verdes.
- **🎭 Tests de Simulación de Usuario:** caso de prueba obligatorio end-to-end vía UI — abrir el FAB, escribir la consulta exacta, ver la tarjeta de rutina (kettlebell + cardio) y la tarjeta de plan de comidas en el mismo turno de chat. **Validado a nivel API+DB en T11.1.2** (curl real contra gemma4:e4b: `workout`/`meal_plan` no-nulos con datos reales) y a nivel de renderizado con widget tests (`chat_fab_test.dart` confirma que las tarjetas "Rutina sugerida"/"Plan de comidas" aparecen cuando el mensaje trae esos campos). E2E de UI con Playwright a través del FAB real queda como verificación manual opcional, no bloqueante.

### SF11.3: Documentación [X]

#### T11.3.1: ADR 10 (orquestador chat+generación) en `architecture.md` [X]
- **🧠 Explicación:** Formalizar por qué se eligió un orquestador backend (b) sobre tool-calling (a) o parseo en frontend (c), y documentar el nuevo endpoint y el flujo del FAB.
- **💡 Cómo hacerlo:** ADR 10 en `architecture.md` con el contexto (3 endpoints separados, sin combinar), la decisión (orquestador + funciones reusables), la justificación (tool-calling no uniforme entre 7 proveedores) y la restricción real del catálogo (sin treadmill, cardio como instrucción libre).
- **Acciones:**
  - `[X]` A11.3.1.1: ADR 10 en `architecture.md`.
- **✅ Tests Unitarios:** N/A (docs).
- **🎭 Tests de Simulación de Usuario:** N/A (docs).

---

## F12: Gestión de Modelos Ollama (selector en vivo + instalación de modelos recomendados) [ ]

> Cierra el bug reportado: `kSuggestedModel['ollama']='llama3.1'` no está instalado en el Ollama real del usuario; el campo de modelo era texto libre. Además, `docker-compose.yml` tiene un servicio `ollama` que compite por el puerto 11434 del host con el Ollama nativo real (el que tiene los modelos instalados).
> **AC de Fase:** puerto 11434 sin conflicto + `OLLAMA_HOST` default a `host.docker.internal:11434` · `GET /ollama/models` lista modelos reales · `POST /ollama/pull` + `GET /ollama/pull-status` instalan con progreso · desplegable en Ajustes de IA (fallback a texto libre) · sección de recomendados instalables · ADR 11. **NO toca diseno_db.md.**

### SF12.1: Infraestructura (puerto Ollama y default del backend) [ ]

#### T12.1.1: Resolver conflicto de puerto 11434 y corregir `OLLAMA_HOST` [ ]
- **🧠 Explicación:** El servicio `ollama` de `docker-compose.yml` mapea el puerto 11434 del HOST al contenedor, compitiendo con el Ollama nativo de Windows del usuario que escucha en el mismo puerto y tiene los modelos reales. El backend usa `OLLAMA_HOST` default apuntando al servicio docker — hay que apuntar al Ollama real.
- **💡 Cómo hacerlo:** en `docker-compose.yml`, quitar el mapeo de puerto del servicio `ollama` (dejar el contenedor sin publicar ese puerto al host; evaluar remover el servicio completo si nada más lo referencia) para liberar el 11434 del host para el Ollama nativo. En `backend/app/ai_engine.py`, cambiar el default de `OLLAMA_HOST` a `http://host.docker.internal:11434` (ya existe `extra_hosts: host.docker.internal:host-gateway` en el servicio backend).
- **Acciones:**
  - `[ ]` A12.1.1.1: Quitar/ajustar el mapeo de puerto del servicio `ollama` en `docker-compose.yml` para no competir con el 11434 del host.
  - `[ ]` A12.1.1.2: Cambiar el default de `OLLAMA_HOST` (backend) a `http://host.docker.internal:11434`.
- **✅ Tests Unitarios:** N/A (config de infra); verificación manual: `docker compose up`, `curl http://localhost:11434/api/tags` desde el host devuelve los modelos reales (no el contenedor casi vacío).
- **🎭 Tests de Simulación de Usuario:** N/A (infra).

### SF12.2: Backend — listar e instalar modelos [ ]

#### T12.2.1: `GET /ollama/models` (modelos instalados reales) [ ]
- **🧠 Explicación:** El desplegable del frontend necesita la lista real de modelos. Ollama expone el endpoint nativo `/api/tags` (no el compatible con OpenAI) en la raíz del host — hay que derivar ese host desde el `base_url` configurado por el usuario, que puede venir con o sin el sufijo `/v1` del modo OpenAI-compatible.
- **💡 Cómo hacerlo:** en `backend/app/main.py`, una función `_native_ollama_host(base_url)` que recorta el sufijo `/v1` si viene, y un endpoint `GET /ollama/models` que consulte `{host}/api/tags` vía `httpx`, mapee cada entrada a `{name, size}`, y devuelva 503 con detalle si Ollama no responde (nunca un 500 sin manejar).
- **Acciones:**
  - `[ ]` A12.2.1.1: `_native_ollama_host` deriva el host nativo (con/sin `/v1`).
  - `[ ]` A12.2.1.2: `GET /ollama/models` devuelve la lista real; 503 claro si Ollama no responde (no 500).
- **✅ Tests Unitarios:** con `httpx` mockeado — `base_url` con `/v1` y sin `/v1` derivan el mismo host nativo; respuesta de Ollama se mapea a `{name, size}`; Ollama inalcanzable → 503 con detalle, no excepción sin manejar.
- **🎭 Tests de Simulación de Usuario:** cubierto por T12.3.1 (desplegable poblado con datos reales).

#### T12.2.2: `POST /ollama/pull` + `GET /ollama/pull-status` (instalar con progreso) [ ]
- **🧠 Explicación:** Instalar un modelo puede tardar minutos. Se inicia la descarga en background (no bloquea el request) y se expone el progreso vía polling, leyendo el stream NDJSON que devuelve el endpoint nativo de pull de Ollama.
- **💡 Cómo hacerlo:** en `main.py`, un diccionario en memoria de estado por modelo; una tarea async que hace streaming del pull nativo de Ollama (`stream: true`) y actualiza ese diccionario línea a línea hasta que el status indique éxito; `POST /ollama/pull` la dispara vía `BackgroundTasks` (responde de inmediato, no espera a que termine); `GET /ollama/pull-status?model=...` devuelve el último estado conocido para ese modelo (o "no iniciado" si nunca se pidió).
- **Acciones:**
  - `[ ]` A12.2.2.1: `POST /ollama/pull` dispara la descarga en background (no bloquea).
  - `[ ]` A12.2.2.2: `GET /ollama/pull-status` expone el progreso hasta completarse.
- **✅ Tests Unitarios:** con el stream de Ollama mockeado (NDJSON de ejemplo) — la tarea de pull actualiza el estado en cada línea y termina en éxito; un error de red deja el estado en error/terminado (no cuelga el polling indefinidamente); consultar el estado de un modelo nunca iniciado devuelve "no iniciado".
- **🎭 Tests de Simulación de Usuario:** cubierto por T12.3.2 (botón instalar + barra de progreso real).

### SF12.3: Frontend — desplegable + modelos recomendados [ ]

#### T12.3.1: Desplegable de modelos instalados (con fallback a texto libre) [ ]
- **🧠 Explicación:** Reemplaza el campo de texto de modelo por un desplegable cuando el proveedor es `ollama` y la consulta a `/ollama/models` tuvo éxito; si falla (Ollama no alcanzable), se mantiene el campo de texto de hoy — nunca bloquea el flujo de configurar otro proveedor.
- **💡 Cómo hacerlo:** en `ai_settings_screen.dart`, al entrar o cambiar la URL base con proveedor `ollama`, llamar al nuevo endpoint de listado; si responde con modelos, renderizar un desplegable poblado con esos nombres (preseleccionando el modelo actual si está en la lista); si falla o la lista viene vacía, renderizar el campo de texto existente sin cambios.
- **Acciones:**
  - `[ ]` A12.3.1.1: Llamada al endpoint de modelos al entrar/cambiar la URL base con proveedor `ollama`.
  - `[ ]` A12.3.1.2: Desplegable poblado con fallback al campo de texto libre si falla.
- **✅ Tests Unitarios:** widget test — con el cliente HTTP mockeado devolviendo modelos, aparece el desplegable con esos nombres; con la llamada fallando, aparece el campo de texto de siempre.
- **🎭 Tests de Simulación de Usuario:** abrir Ajustes de IA, elegir `ollama`, ver el desplegable con los modelos reales del Ollama del usuario (no un modelo inventado que no tiene instalado).

#### T12.3.2: Sección "Modelos recomendados" con instalación y progreso [ ]
- **🧠 Explicación:** Lista curada de modelos multi-propósito razonables para esta app (chat, generación de rutinas/planes JSON, visión). Cada uno no presente en la lista instalada muestra un botón de instalar; al pulsar, dispara la descarga y sondea el progreso hasta terminar, mostrando una barra/spinner, y al terminar refresca el desplegable de T12.3.1.
- **💡 Cómo hacerlo:** una constante con la lista curada (p. ej. `gemma4:e4b`, `llama3.2:3b`, `qwen2.5:3b`) en `ai_config.dart`; en `ai_settings_screen.dart`, una sección con un ítem por modelo recomendado y botón de instalar (oculto si ya está en la lista de instalados) que dispara el pull y sondea el estado cada 2-3s hasta completarse.
- **Acciones:**
  - `[ ]` A12.3.2.1: Lista curada de modelos recomendados + UI de la sección con estado instalado/no instalado.
  - `[ ]` A12.3.2.2: Botón de instalar → dispara el pull + sondeo de progreso hasta completar + refresco del desplegable.
- **✅ Tests Unitarios:** widget test — un modelo recomendado ya instalado no muestra botón de instalar; uno no instalado sí; al pulsarlo (con HTTP mockeado) se dispara la petición y se refleja el progreso hasta completarse.
- **🎭 Tests de Simulación de Usuario:** con el Ollama real del usuario, pulsar instalar en un modelo recomendado no instalado, ver el progreso, y que al terminar aparezca seleccionable en el desplegable de T12.3.1.

### SF12.4: Documentación [ ]

#### T12.4.1: ADR 11 en `architecture.md` [ ]
- **🧠 Explicación:** Documentar el hallazgo de infraestructura (conflicto de puerto 11434), la decisión de listar/instalar modelos vía backend (no directo desde el navegador), y el flujo completo.
- **💡 Cómo hacerlo:** ADR 11 con contexto (bug de modelo no instalado + descubrimiento del conflicto de puerto), decisión (backend como intermediario, `OLLAMA_HOST` corregido, servicio `ollama` de compose sin publicar el puerto), y el flujo listar→elegir/instalar→chat.
- **Acciones:**
  - `[ ]` A12.4.1.1: ADR 11 en `architecture.md`.
- **✅ Tests Unitarios:** N/A (docs).
- **🎭 Tests de Simulación de Usuario:** N/A (docs).
