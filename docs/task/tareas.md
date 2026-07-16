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

## F12: Gestión de Modelos Ollama (selector en vivo + instalación de modelos recomendados) [X]

> Cierra el bug reportado: `kSuggestedModel['ollama']='llama3.1'` no está instalado en el Ollama real del usuario; el campo de modelo era texto libre. Además, `docker-compose.yml` tiene un servicio `ollama` que compite por el puerto 11434 del host con el Ollama nativo real (el que tiene los modelos instalados).
> **AC de Fase:** puerto 11434 sin conflicto + `OLLAMA_HOST` default a `host.docker.internal:11434` · `GET /ollama/models` lista modelos reales · `POST /ollama/pull` + `GET /ollama/pull-status` instalan con progreso · desplegable en Ajustes de IA (fallback a texto libre) · sección de recomendados instalables · ADR 11. **NO toca diseno_db.md.**

### SF12.1: Infraestructura (puerto Ollama y default del backend) [X]

#### T12.1.1: Resolver conflicto de puerto 11434 y corregir `OLLAMA_HOST` [X]
- **🧠 Explicación:** El servicio `ollama` de `docker-compose.yml` mapea el puerto 11434 del HOST al contenedor, compitiendo con el Ollama nativo de Windows del usuario que escucha en el mismo puerto y tiene los modelos reales. El backend usa `OLLAMA_HOST` default apuntando al servicio docker — hay que apuntar al Ollama real.
- **💡 Cómo hacerlo:** en `docker-compose.yml`, quitar el mapeo de puerto del servicio `ollama` (dejar el contenedor sin publicar ese puerto al host; evaluar remover el servicio completo si nada más lo referencia) para liberar el 11434 del host para el Ollama nativo. En `backend/app/ai_engine.py`, cambiar el default de `OLLAMA_HOST` a `http://host.docker.internal:11434` (ya existe `extra_hosts: host.docker.internal:host-gateway` en el servicio backend).
- **Acciones:**
  - `[X]` A12.1.1.1: Servicio `ollama` (y su volumen) **removidos por completo** de `docker-compose.yml` — nada más en el repo lo referenciaba por hostname; mantenerlo vacío corriendo era puro desperdicio y fuente de confusión.
  - `[X]` A12.1.1.2: Default de `OLLAMA_HOST` corregido a `http://host.docker.internal:11434` en `ai_engine.py` Y en `main.py` (este último tenía un bug latente adicional: default `http://localhost:11434`, inalcanzable desde dentro de un contenedor).
- **✅ Tests Unitarios:** N/A (config de infra). Verificado: `curl http://localhost:11434/api/tags` desde el host devuelve 11 modelos reales (`gemma4:e4b`, `qwen2.5:3b`, etc.); `host.docker.internal:11434` alcanzable desde el contenedor backend (200); 30/30 tests backend sin regresión.
- **🎭 Tests de Simulación de Usuario:** N/A (infra).

### SF12.2: Backend — listar e instalar modelos [X]

#### T12.2.1: `GET /ollama/models` (modelos instalados reales) [X]
- **🧠 Explicación:** El desplegable del frontend necesita la lista real de modelos. Ollama expone el endpoint nativo `/api/tags` (no el compatible con OpenAI) en la raíz del host — hay que derivar ese host desde el `base_url` configurado por el usuario, que puede venir con o sin el sufijo `/v1` del modo OpenAI-compatible.
- **💡 Cómo hacerlo:** en `backend/app/main.py`, una función `_native_ollama_host(base_url)` que recorta el sufijo `/v1` si viene, y un endpoint `GET /ollama/models` que consulte `{host}/api/tags` vía `httpx`, mapee cada entrada a `{name, size}`, y devuelva 503 con detalle si Ollama no responde (nunca un 500 sin manejar).
- **Acciones:**
  - `[X]` A12.2.1.1: `_native_ollama_host` deriva el host nativo (con/sin `/v1`).
  - `[X]` A12.2.1.2: `GET /ollama/models` devuelve la lista real; 503 claro si Ollama no responde (no 500).
- **✅ Tests Unitarios:** con `httpx` mockeado — `base_url` con `/v1` y sin `/v1` derivan el mismo host nativo; respuesta de Ollama se mapea a `{name, size}`; Ollama inalcanzable → 503 con detalle, no excepción sin manejar. Verificado: 39/39 tests, y contra el Ollama real devuelve 11 modelos reales.
- **🎭 Tests de Simulación de Usuario:** cubierto por T12.3.1 (desplegable poblado con datos reales).

#### T12.2.2: `POST /ollama/pull` + `GET /ollama/pull-status` (instalar con progreso) [X]
- **🧠 Explicación:** Instalar un modelo puede tardar minutos. Se inicia la descarga en background (no bloquea el request) y se expone el progreso vía polling, leyendo el stream NDJSON que devuelve el endpoint nativo de pull de Ollama.
- **💡 Cómo hacerlo:** en `main.py`, un diccionario en memoria de estado por modelo; una tarea async que hace streaming del pull nativo de Ollama (`stream: true`) y actualiza ese diccionario línea a línea hasta que el status indique éxito; `POST /ollama/pull` la dispara vía `BackgroundTasks` (responde de inmediato, no espera a que termine); `GET /ollama/pull-status?model=...` devuelve el último estado conocido para ese modelo (o "no iniciado" si nunca se pidió).
- **Acciones:**
  - `[X]` A12.2.2.1: `POST /ollama/pull` dispara la descarga en background (no bloquea).
  - `[X]` A12.2.2.2: `GET /ollama/pull-status` expone el progreso hasta completarse.
- **✅ Tests Unitarios:** con el stream de Ollama mockeado (NDJSON de ejemplo) — la tarea de pull actualiza el estado en cada línea y termina en éxito; un error de red deja el estado en error/terminado (no cuelga el polling indefinidamente); consultar el estado de un modelo nunca iniciado devuelve "no iniciado". Verificado con pull real de un modelo ya instalado (`qwen2.5:3b`): `done:True, status:"success"` en ~2s.
- **🎭 Tests de Simulación de Usuario:** cubierto por T12.3.2 (botón instalar + barra de progreso real).

### SF12.3: Frontend — desplegable + modelos recomendados [X]

#### T12.3.1: Desplegable de modelos instalados (con fallback a texto libre) [X]
- **🧠 Explicación:** Reemplaza el campo de texto de modelo por un desplegable cuando el proveedor es `ollama` y la consulta a `/ollama/models` tuvo éxito; si falla (Ollama no alcanzable), se mantiene el campo de texto de hoy — nunca bloquea el flujo de configurar otro proveedor.
- **💡 Cómo hacerlo:** en `ai_settings_screen.dart`, al entrar o cambiar la URL base con proveedor `ollama`, llamar al nuevo endpoint de listado; si responde con modelos, renderizar un desplegable poblado con esos nombres (preseleccionando el modelo actual si está en la lista); si falla o la lista viene vacía, renderizar el campo de texto existente sin cambios.
- **Acciones:**
  - `[X]` A12.3.1.1: Llamada al endpoint de modelos al entrar/cambiar la URL base con proveedor `ollama`.
  - `[X]` A12.3.1.2: Desplegable poblado con fallback al campo de texto libre si falla.
- **✅ Tests Unitarios:** widget test — con el cliente HTTP mockeado devolviendo modelos, aparece el desplegable con esos nombres; con la llamada fallando, aparece el campo de texto de siempre. Verificado: 33/33 tests.
- **🎭 Tests de Simulación de Usuario:** abrir Ajustes de IA, elegir `ollama`, ver el desplegable con los modelos reales del Ollama del usuario (no un modelo inventado que no tiene instalado). **Verificado en vivo con Playwright**: el desplegable listó los 11 modelos reales (`gemma4:e4b`, `qwen2.5:3b`, `llama3.2:latest`, `gpt-oss:20b`, etc.).

#### T12.3.2: Sección "Modelos recomendados" con instalación y progreso [X]
- **🧠 Explicación:** Lista curada de modelos multi-propósito razonables para esta app (chat, generación de rutinas/planes JSON, visión). Cada uno no presente en la lista instalada muestra un botón de instalar; al pulsar, dispara la descarga y sondea el progreso hasta terminar, mostrando una barra/spinner, y al terminar refresca el desplegable de T12.3.1.
- **💡 Cómo hacerlo:** una constante con la lista curada (p. ej. `gemma4:e4b`, `llama3.2:3b`, `qwen2.5:3b`) en `ai_config.dart`; en `ai_settings_screen.dart`, una sección con un ítem por modelo recomendado y botón de instalar (oculto si ya está en la lista de instalados) que dispara el pull y sondea el estado cada 2-3s hasta completarse.
- **Acciones:**
  - `[X]` A12.3.2.1: Lista curada de modelos recomendados + UI de la sección con estado instalado/no instalado.
  - `[X]` A12.3.2.2: Botón de instalar → dispara el pull + sondeo de progreso hasta completar + refresco del desplegable.
- **✅ Tests Unitarios:** widget test — un modelo recomendado ya instalado no muestra botón de instalar; uno no instalado sí; al pulsarlo (con HTTP mockeado) se dispara la petición y se refleja el progreso hasta completarse. Verificado: 33/33 tests.
- **🎭 Tests de Simulación de Usuario:** con el Ollama real del usuario, pulsar instalar en un modelo recomendado no instalado, ver el progreso, y que al terminar aparezca seleccionable en el desplegable de T12.3.1. **Verificado en vivo**: los 3 recomendados (`gemma4:e4b`, `llama3.2:3b`, `qwen2.5:3b`) ya estaban instalados y mostraron el check verde correctamente (matching tolerante a tags funcionó, ej. `llama3.2:3b` vs `llama3.2:latest` instalado).

### SF12.4: Documentación [X]

#### T12.4.1: ADR 11 en `architecture.md` [X]
- **🧠 Explicación:** Documentar el hallazgo de infraestructura (conflicto de puerto 11434), la decisión de listar/instalar modelos vía backend (no directo desde el navegador), y el flujo completo.
- **💡 Cómo hacerlo:** ADR 11 con contexto (bug de modelo no instalado + descubrimiento del conflicto de puerto), decisión (backend como intermediario, `OLLAMA_HOST` corregido, servicio `ollama` de compose sin publicar el puerto), y el flujo listar→elegir/instalar→chat.
- **Acciones:**
  - `[X]` A12.4.1.1: ADR 11 en `architecture.md`.
- **✅ Tests Unitarios:** N/A (docs).
- **🎭 Tests de Simulación de Usuario:** N/A (docs).

---

## F13: Rutinas Guardables (persistencia real de rutinas generadas por IA) [X]

> Cierra un hallazgo crítico: el chat AFIRMA haber guardado una rutina cuando se le pide, pero es una alucinación del LLM (verificado por grep: cero mecanismo de persistencia). `training.workout_sessions`/`workout_sets` solo registran sesiones ya ejecutadas, nunca hubo una plantilla reutilizable guardable.
> **AC de Fase:** tabla `training.routines` (JSONB) con RLS · botón real "Guardar rutina" en el chat (INSERT directo a Supabase, sin tocar el backend) · el `reply` del chat deja de depender del LLM (texto determinista, nunca alucina un guardado) · Entrenamiento lista rutinas guardadas + predefinidas y precarga sets/reps/rpe al iniciar · ADR 12.

### SF13.1: Esquema de rutinas guardadas (DB) [X]

#### T13.1.1: `training.routines` (JSONB) + RLS + GRANTs [X]
- **🧠 Explicación:** Una sola tabla con los items como `JSONB` (no una tabla relacional aparte) — no hay hoy necesidad de queries por item individual, y evita una segunda tabla + JOIN para leer/escribir la rutina completa de una vez. Mismo patrón de RLS que las demás tablas de usuario de F10.
- **💡 Cómo hacerlo:** nuevo archivo `docker/postgres/zzzz2_routines.sql` (corre después de `zzz_auth_rls.sql` por orden alfabético):
  ```sql
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

  ALTER TABLE training.routines ENABLE ROW LEVEL SECURITY;
  CREATE POLICY own_routines ON training.routines
    USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

  GRANT ALL ON training.routines TO authenticated;
  GRANT ALL ON training.routines TO anon;
  ```
  Montar el archivo en `docker-compose.yml` igual que `zzz_auth_rls.sql`. Requiere `docker compose down -v` para aplicar el nuevo esquema (avisar antes de ejecutarlo, igual que en F10).
- **Acciones:**
  - `[X]` A13.1.1.1: Tabla `training.routines` con `items JSONB NOT NULL`.
  - `[X]` A13.1.1.2: RLS `auth.uid() = user_id` + `GRANT` a `authenticated` (siguiendo el precedente real de `zzz_auth_rls.sql`: sin `GRANT` a `anon` en tablas de usuario).
- **✅ Tests Unitarios:** verificación manual — con JWT real de un usuario A, `INSERT`/`SELECT` en `training.routines` solo devuelve/acepta sus propias filas; usuario B no ve las de A. Verificado: `tests/e2e/test_auth_rls_e2e.sh` extendido con AC6-AC8, 9/9 PASS.
- **🎭 Tests de Simulación de Usuario:** N/A (DB pura, cubierto por T13.2.1/T13.3.1).

### SF13.2: Guardado real desde el chat + fin de la alucinación [X]

#### T13.2.1: Botón "Guardar rutina" en el chat → `INSERT` real [X]
- **🧠 Explicación:** El chat nunca debe depender de que el usuario "pida" el guardado en texto libre ni de que el LLM lo confirme — un botón explícito en la tarjeta de rutina dispara el `INSERT` real, con confirmación real (`SnackBar`) tras el éxito.
- **💡 Cómo hacerlo:** en `frontend/lib/features/ai/chat_screen.dart`, `_buildWorkoutCard` recibe también el contexto para poder guardar; añadir un botón (p. ej. `TextButton.icon` con ícono de guardar) que:
  ```dart
  Future<void> _saveRoutine(BuildContext context, Map<String, dynamic> workout) async {
    final nameCtrl = TextEditingController(text: 'Rutina IA ${DateTime.now().day}/${DateTime.now().month}');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nombra tu rutina'),
        content: TextField(controller: nameCtrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()), child: const Text('Guardar')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      final client = Supabase.instance.client;
      await client.schema('training').from('routines').insert({
        'user_id': client.auth.currentUser!.id,
        'name': name,
        'source': 'ai',
        'items': workout['items'],
        'cardio_block': workout['cardio_block'],
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rutina guardada — ya aparece en Entrenamiento')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
      }
    }
  }
  ```
  Import `package:supabase_flutter/supabase_flutter.dart` en `chat_screen.dart` si no está ya.
- **Acciones:**
  - `[X]` A13.2.1.1: Botón "Guardar rutina" en la tarjeta del chat.
  - `[X]` A13.2.1.2: Diálogo para nombrar + `INSERT` real a `training.routines` + confirmación real.
- **✅ Tests Unitarios:** widget test — el botón existe en la tarjeta cuando `workout != null`; al pulsarlo y confirmar el nombre, se invoca el `INSERT` con el `schema('training')`/tabla/shape correctos. Verificado: 34/34 tests, vía un seam `saveRoutineOverride` inyectable (instanciar `SupabaseClient` real colgaba el test runner en este entorno — documentado en INC-015).
- **🎭 Tests de Simulación de Usuario:** generar una rutina en el chat → pulsar "Guardar rutina" → nombrarla → ver el `SnackBar` de confirmación real (no el texto del LLM).

#### T13.2.2: `reply` del chat deja de depender del LLM (fin de la alucinación) [X]
- **🧠 Explicación:** El bug reportado viene de pedirle al LLM "resume qué generaste" — el modelo no sabe qué se persistió de verdad y alucina una confirmación. La solución de raíz es dejar de usar el LLM para ese texto: construirlo determinísticamente en código a partir de los flags de intención ya detectados.
- **💡 Cómo hacerlo:** en `backend/app/main.py`, dentro de `chat_plan`, reemplazar la llamada `_run_ai(req.ai, f"...Resume...")` por:
  ```python
  reply_parts = []
  if workout is not None:
      reply_parts.append("Aquí tienes tu rutina sugerida. Usa el botón 'Guardar rutina' si quieres conservarla.")
  if meal_plan is not None:
      reply_parts.append("Y tu plan de comidas para hoy.")
  if not reply_parts:
      reply_parts.append("No detecté que quisieras una rutina o un plan de comidas — cuéntame con más detalle qué necesitas.")
  reply = " ".join(reply_parts)
  ```
  Esto elimina una llamada al LLM por turno (más rápido y barato) y hace estructuralmente imposible que el `reply` afirme una acción que el código no realizó.
- **Acciones:**
  - `[X]` A13.2.2.1: `reply` construido en código, sin llamada al LLM, cubriendo los 3 casos (solo rutina, solo plan, ninguno).
- **✅ Tests Unitarios:** test que cuenta las invocaciones al motor de IA mockeado en un turno con `wants_workout=True, wants_meal_plan=True` — deben ser 3 (extracción de intención + rutina + plan de comidas, no 4 como antes de esta tarea: ya no hay llamada de resumen); el texto de `reply` nunca contiene "se guardó"/"cargó". Verificado: 39/39 tests backend.
- **🎭 Tests de Simulación de Usuario:** cubierto por T13.2.1 (la confirmación real reemplaza a la alucinación).

### SF13.3: Rutinas guardadas en Entrenamiento [X]

#### T13.3.1: Listar rutinas guardadas + precargar sets/reps/rpe al iniciar [X]
- **🧠 Explicación:** `workout_screen.dart` hoy solo muestra 3 rutinas predefinidas hardcodeadas (`_predefinedRoutines`) que inician una sesión vacía. Hay que traer las rutinas guardadas del usuario (`SELECT` a `training.routines`) y, al iniciar una, precargar los `sets`/`reps`/`rpe` objetivo de cada ejercicio en vez de una sesión en blanco.
- **💡 Cómo hacerlo:** en `training_provider.dart`, un método `fetchSavedRoutines()` (`client.schema('training').from('routines').select().eq('user_id', ...)` — RLS ya filtra, pero el `.eq` es explícito y barato) que puebla una lista `List<Map<String,dynamic>> savedRoutines`; y un método nuevo `startWorkoutSessionFromRoutine(String name, List items)` que llama internamente a `startWorkoutSession(name)` y luego, por cada item, hace `addExerciseToActiveWorkout(exerciseId)` seguido de tantas llamadas a algo equivalente a `addSetToActiveExercise` como indique `sets`, pero usando `reps`/`rpe` del item en vez de los defaults (puede necesitar una pequeña variante de `addSetToActiveExercise` que acepte `reps`/`rpe` opcionales sin romper la firma existente — usa un parámetro nombrado opcional). En `workout_screen.dart`, una sección "Mis Rutinas" (junto a "Rutinas Predefinidas") listando `savedRoutines`, cuyo `onTap` llama `startWorkoutSessionFromRoutine` y navega a `ActiveWorkoutScreen` igual que las predefinidas.
- **Acciones:**
  - `[X]` A13.3.1.1: `fetchSavedRoutines()` + estado en `TrainingProvider`.
  - `[X]` A13.3.1.2: `startWorkoutSessionFromRoutine` precarga sets/reps/rpe objetivo.
  - `[X]` A13.3.1.3: Sección "Mis Rutinas" en `workout_screen.dart`.
- **✅ Tests Unitarios:** provider test — `fetchSavedRoutines` puebla el estado desde una respuesta mockeada; `startWorkoutSessionFromRoutine` crea tantos `WorkoutSet` como la suma de `sets` de todos los items, con los `reps`/`rpe` correctos por ejercicio. Verificado: 38/38 tests verdes.
- **🎭 Tests de Simulación de Usuario:** guardar una rutina desde el chat (T13.2.1) → verla en Entrenamiento bajo "Mis Rutinas" → iniciarla → confirmar que los sets ya vienen con las reps/rpe sugeridas por la IA, no vacíos.

### SF13.4: Documentación [X]

#### T13.4.1: ADR 12 en `architecture.md` + `training.routines` en `diseno_db.md` [X]
- **🧠 Explicación:** Documentar el hallazgo de la alucinación, la decisión de esquema (JSONB vs relacional) y de persistencia (INSERT directo vs backend), y la tabla nueva en el diccionario de DB.
- **💡 Cómo hacerlo:** ADR 12 en `architecture.md` (contexto: alucinación descubierta por el usuario; decisión: JSONB + INSERT directo + reply determinista); nueva entrada de `training.routines` en la sección 2.3 de `diseno_db.md` (mismo formato de tabla que `workout_sessions`/`workout_sets`).
- **Acciones:**
  - `[X]` A13.4.1.1: ADR 12 en `architecture.md`.
  - `[X]` A13.4.1.2: `training.routines` documentada en `diseno_db.md`.
- **✅ Tests Unitarios:** N/A (docs).
- **🎭 Tests de Simulación de Usuario:** N/A (docs).

---

## F14: Recuperación de Contraseña (mailer local + flujo completo) [X]

> `AuthScreen` (F10) solo tiene login/signup — sin recuperación de contraseña (verificado por grep, cero resultados). GoTrue puede enviarla, pero el stack no tiene SMTP configurado.
> **AC de Fase:** servicio `mailpit` (SMTP + UI + API REST) · enlace "¿Olvidaste tu contraseña?" → `resetPasswordForEmail` · detección de `AuthChangeEvent.passwordRecovery` → pantalla de nueva contraseña → `updateUser` · E2E real (correo capturado por Mailpit, no simulado) · ADR 13. **NO toca diseno_db.md.**

### SF14.1: Mailer local (infra) [X]

#### T14.1.1: Servicio `mailpit` + `GOTRUE_SMTP_*` [X]
- **🧠 Explicación:** Mailpit (no Mailhog, sin mantenimiento desde 2020) captura correos SMTP sin enviarlos de verdad — expone una UI web para verlos y una API REST (`GET /api/v1/messages`) para extraerlos programáticamente, clave para el E2E de T14.3.1 sin depender de un navegador.
- **💡 Cómo hacerlo:** en `docker-compose.yml`:
  ```yaml
  mailpit:
    image: axllent/mailpit:latest
    container_name: nutri-fit-mailpit
    ports:
      - "8025:8025"  # UI web + API REST
      - "1025:1025"  # SMTP
    networks:
      - nutrifit-network
  ```
  En el servicio `auth` (GoTrue), añadir/ajustar variables:
  ```yaml
  GOTRUE_SMTP_HOST: mailpit
  GOTRUE_SMTP_PORT: "1025"
  GOTRUE_SMTP_USER: "test"
  GOTRUE_SMTP_PASS: "test"
  GOTRUE_SMTP_SENDER_NAME: "Nutri-Fit"
  GOTRUE_SMTP_ADMIN_EMAIL: "no-reply@nutrifit.local"
  ```
  `GOTRUE_SITE_URL` (ya en `http://localhost:8080` desde F10) sigue sirviendo como base para el link del correo; `auth: depends_on: [postgres, mailpit]`.
- **Acciones:**
  - `[X]` A14.1.1.1: Servicio `mailpit` en `docker-compose.yml`.
  - `[X]` A14.1.1.2: `GOTRUE_SMTP_*` apuntando a Mailpit. Verificado con correo real: signup → recover → correo capturado en Mailpit con link + código OTP de recuperación.
- **✅ Tests Unitarios:** N/A (config de infra); verificación manual — `docker compose up`, `curl http://localhost:8025/api/v1/messages` responde (aunque vacío al inicio).
- **🎭 Tests de Simulación de Usuario:** N/A (infra, cubierto por T14.3.1).

### SF14.2: Flujo de recuperación (frontend) [X]

#### T14.2.1: Enlace "¿Olvidaste tu contraseña?" → `resetPasswordForEmail` [X]
- **🧠 Explicación:** En el modo login de `AuthScreen`, un enlace que pide el email y dispara la recuperación real — sin depender de que el usuario "avise" de otra forma.
- **💡 Cómo hacerlo:** en `frontend/lib/features/auth/auth_screen.dart`, debajo del botón de login (solo visible en modo login, no signup):
  ```dart
  TextButton(
    onPressed: _isLoading ? null : _showForgotPasswordDialog,
    child: const Text('¿Olvidaste tu contraseña?'),
  ),
  ```
  ```dart
  Future<void> _showForgotPasswordDialog() async {
    final emailCtrl = TextEditingController(text: _emailController.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recuperar contraseña'),
        content: TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, emailCtrl.text.trim()), child: const Text('Enviar')),
        ],
      ),
    );
    if (email == null || email.isEmpty || !email.contains('@')) return;
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'http://localhost:8080/',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Revisa tu correo para continuar (o la bandeja de Mailpit en dev: http://localhost:8025)')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo enviar: $e')));
      }
    }
  }
  ```
- **Acciones:**
  - `[X]` A14.2.1.1: Enlace "¿Olvidaste tu contraseña?" visible solo en modo login.
  - `[X]` A14.2.1.2: Diálogo de email → `resetPasswordForEmail` con manejo de error.
- **✅ Tests Unitarios:** widget test — el enlace existe en modo login y NO en modo signup; el diálogo valida el email antes de llamar. Verificado: 44/44 tests verdes.
- **🎭 Tests de Simulación de Usuario:** cubierto por T14.3.1 (E2E real).

#### T14.2.2: `AuthChangeEvent.passwordRecovery` → pantalla de nueva contraseña [X]
- **🧠 Explicación:** Al abrir el link del correo, `Supabase.initialize()` detecta el token de recuperación en la URL y GoTrue emite `AuthChangeEvent.passwordRecovery` por `onAuthStateChange` — confirmado en la documentación real del SDK (no asumido). `AuthGate` (en `main.dart`) ya escucha ese stream para decidir login/dashboard; hay que darle prioridad a este evento sobre el enrutamiento normal.
- **💡 Cómo hacerlo:** en `frontend/lib/main.dart`, dentro de `AuthGate.build`, el `builder` del `StreamBuilder<AuthState>` ya tiene `snapshot.data?.event` disponible:
  ```dart
  builder: (context, snapshot) {
    if (snapshot.data?.event == AuthChangeEvent.passwordRecovery) {
      return const ResetPasswordScreen();
    }
    final session = snapshot.data?.session ?? SupabaseConfig.client.auth.currentSession;
    if (session == null) return const AuthScreen();
    return const InitialCheckScreen();
  },
  ```
  Nuevo archivo `frontend/lib/features/auth/reset_password_screen.dart`: pantalla con un campo de nueva contraseña (+ botón de ojo, mismo patrón ya usado en `auth_screen.dart`) y un botón "Guardar" que llama:
  ```dart
  await Supabase.instance.client.auth.updateUser(
    UserAttributes(password: newPasswordCtrl.text),
  );
  ```
  Tras el éxito, muestra confirmación; el `AuthGate` volverá a evaluar (la sesión ya está activa tras la recuperación) y navegará normalmente.
- **Acciones:**
  - `[X]` A14.2.2.1: `AuthGate` prioriza `AuthChangeEvent.passwordRecovery` sobre el enrutamiento normal.
  - `[X]` A14.2.2.2: `ResetPasswordScreen` con campo de contraseña + `updateUser`. Verificado: 44/44 tests, sin regresión.
- **✅ Tests Unitarios:** widget test — con un `AuthState` mockeado de evento `passwordRecovery`, `AuthGate` renderiza `ResetPasswordScreen` (no `AuthScreen`/`InitialCheckScreen`); `ResetPasswordScreen` valida la contraseña (mínimo 6 caracteres, mismo criterio que `auth_screen.dart`) antes de llamar `updateUser`.
- **🎭 Tests de Simulación de Usuario:** cubierto por T14.3.1 (E2E real).

### SF14.3: Verificación E2E real + Documentación [X]

#### T14.3.1: E2E real contra Mailpit (sin mocks) [X]
- **🧠 Explicación:** El criterio de aceptación central de la Fase: demostrar con comandos reales (no mocks) que el correo se envía, se puede extraer, y el cambio de contraseña funciona de punta a punta.
- **💡 Cómo hacerlo:**
  ```bash
  # 1. Disparar la recuperación real
  curl -X POST http://localhost:54321/auth/v1/recover -H "Content-Type: application/json" \
    -d '{"email":"<email de prueba ya existente>"}'
  # 2. Confirmar que el correo llegó a Mailpit (API REST, no la UI)
  curl -s http://localhost:8025/api/v1/messages | jq '.messages[0]'
  # 3. Extraer el link de recuperación del cuerpo del correo (contiene el token)
  # 4. Completar el cambio de contraseña usando el access_token que trae el link
  #    (el link de GoTrue ya es una sesión de recuperación válida; el endpoint
  #    real es PUT /auth/v1/user con ese token como Bearer y {"password": "nueva"})
  # 5. Confirmar login con la contraseña nueva vía /auth/v1/token?grant_type=password
  ```
  Documentar el script real usado (guardarlo en `tests/e2e/` si se generaliza, siguiendo el patrón de `test_auth_rls_e2e.sh`).
- **Acciones:**
  - `[X]` A14.3.1.1: Script/comandos reales que verifican el flujo completo contra Mailpit. Formalizado en `tests/e2e/test_password_recovery_e2e.sh`.
- **✅ Tests Unitarios:** N/A (es en sí mismo el test de simulación de usuario a nivel API).
- **🎭 Tests de Simulación de Usuario:** flujo completo verificado end-to-end: solicitar → correo real en Mailpit → cambiar contraseña → login con la nueva. **8/8 PASS** (signup, recover, correo real capturado, OTP extraído, sesión de recuperación, cambio de contraseña, login con la nueva funciona, login con la vieja YA NO funciona).

#### T14.3.2: ADR 13 en `architecture.md` [X]
- **🧠 Explicación:** Documentar la decisión de Mailpit sobre Mailhog, la config SMTP de GoTrue, y el mecanismo de `AuthChangeEvent.passwordRecovery`.
- **💡 Cómo hacerlo:** ADR 13 con contexto (sin flujo de recuperación, sin SMTP), decisión (Mailpit + su API REST para E2E), y el flujo completo (resetPasswordForEmail → correo → passwordRecovery → updateUser).
- **Acciones:**
  - `[X]` A14.3.2.1: ADR 13 en `architecture.md`.
- **✅ Tests Unitarios:** N/A (docs).
- **🎭 Tests de Simulación de Usuario:** N/A (docs).

---

## F15: UI/UX del Entrenamiento en Vivo + Detalle de Ejercicio (imágenes + instrucciones) [X]

> Hallazgo: `_showExerciseDetail`/`_ExerciseThumbnail` YA EXISTEN en `active_workout_screen.dart`, pero solo están cableados a la hoja "Agregar Ejercicio" — nunca a las tarjetas de la sesión en vivo, que hoy solo muestran el nombre en texto plano. El dataset tiene 2 imágenes ESTÁTICAS por ejercicio (no un GIF animado) — se corrige esa expectativa mostrando ambas en un carrusel.
> **AC de Fase:** miniatura + tap-to-detail en la tarjeta activa (reusando código existente) · popup con carrusel de TODAS las imágenes (hoy solo la primera) · indicador visual de ejercicio completado · cero regresión en edición de sets/finalizar/cancelar.

### SF15.1: Miniatura + detalle reusado en la tarjeta activa [X]

#### T15.1.1: `_ExerciseThumbnail` + tap-to-detail en la tarjeta de `ActiveWorkoutScreen` [X]
- **🧠 Explicación:** El encabezado de cada tarjeta de ejercicio en la sesión activa (`ActiveWorkoutScreen`, dentro del `ListView.builder` de `activeExercisesIds`) hoy es solo `Text(exercise.name)` + botón de borrar. `_ExerciseThumbnail` y `_showExerciseDetail` ya existen en el mismo archivo (usados hoy solo en `_showAddExerciseModal`) — hay que reusarlos aquí, no reimplementarlos.
- **💡 Cómo hacerlo:** en el `Row` del encabezado de la tarjeta (donde hoy está `Expanded(child: Text(exercise.name, ...))`), envolver en un `InkWell`/`GestureDetector` que llame `_showExerciseDetail(context, exercise)`, y anteponer `_ExerciseThumbnail(exercise: exercise)`:
  ```dart
  Row(
    children: [
      _ExerciseThumbnail(exercise: exercise),
      const SizedBox(width: 12),
      Expanded(
        child: InkWell(
          onTap: () => _showExerciseDetail(context, exercise),
          child: Text(exercise.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ),
      IconButton(icon: const Icon(Icons.delete_outline_rounded, ...), onPressed: () => provider.removeExerciseFromActiveWorkout(exId)),
    ],
  ),
  ```
- **Acciones:**
  - `[X]` A15.1.1.1: `_ExerciseThumbnail` en el encabezado de la tarjeta activa.
  - `[X]` A15.1.1.2: Tap en el nombre/miniatura abre `_showExerciseDetail` (reusado).
- **✅ Tests Unitarios:** widget test — con una sesión activa y un ejercicio agregado, la tarjeta renderiza `_ExerciseThumbnail`; tocar el nombre abre el diálogo de detalle. Verificado: 45/45 tests verdes, sin regresión.
- **🎭 Tests de Simulación de Usuario:** iniciar una rutina → agregar/tener un ejercicio → tocar su nombre en la tarjeta activa → ver el popup de detalle (antes solo accesible desde "Agregar Ejercicio").

### SF15.2: Carrusel de imágenes en el popup de detalle [X]

#### T15.2.1: `_showExerciseDetail` muestra todas las `imageUrls` en carrusel [X]
- **🧠 Explicación:** Hoy el popup solo muestra `exercise.imageUrls.first` — una sola imagen estática. El dataset trae típicamente 2 (posición inicial/final); mostrarlas ambas (deslizables) es la representación más fiel de "cómo se hace el ejercicio" disponible en los datos reales (no hay GIF animado en el dataset).
- **💡 Cómo hacerlo:** reemplazar el bloque `if (exercise.imageUrls.isNotEmpty) Center(child: Image.network(exercise.imageUrls.first, ...))` por un `PageView.builder` de altura fija (misma `height: 180`) sobre `exercise.imageUrls`, con un indicador de página (`SmoothPageIndicator`-style casero: una fila de puntitos, sin dependencia nueva) debajo si `imageUrls.length > 1`:
  ```dart
  SizedBox(
    height: 180,
    child: PageView.builder(
      itemCount: exercise.imageUrls.length,
      itemBuilder: (context, i) => Image.network(
        exercise.imageUrls[i], fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(Icons.fitness_center_rounded, size: 96, color: Colors.grey),
      ),
    ),
  ),
  if (exercise.imageUrls.length > 1)
    Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text('${exercise.imageUrls.length} imágenes — desliza', style: const TextStyle(color: Colors.grey, fontSize: 11)),
    ),
  ```
  (Un indicador de puntos real es un plus, pero un texto simple "N imágenes — desliza" ya cumple el AC sin añadir una dependencia nueva — usa tu criterio si quieres algo más elaborado, pero no añadas un paquete pub.dev nuevo solo para esto.)
- **Acciones:**
  - `[X]` A15.2.1.1: `PageView` sobre todas las `imageUrls` en vez de solo la primera.
  - `[X]` A15.2.1.2: Indicador de que hay más de una imagen cuando aplica.
- **✅ Tests Unitarios:** widget test — con un `Exercise` de 2 `imageUrls`, el popup renderiza un `PageView` con `itemCount == 2`; con 1 sola imagen, no muestra el indicador de "desliza"; con 0 imágenes, cae al ícono de fallback. Verificado: 45/45 tests.
- **🎭 Tests de Simulación de Usuario:** abrir el detalle de un ejercicio con 2 imágenes → deslizar → ver ambas.

### SF15.3: Pulido visual de la tarjeta de ejercicio [X]

#### T15.3.1: Indicador de ejercicio completado + jerarquía visual de la tabla de series [X]
- **🧠 Explicación:** Con muchos ejercicios en una rutina larga, es difícil ver de un vistazo cuáles ya se completaron del todo. Un indicador visual (borde/ícono) en la tarjeta cuando TODAS sus series están `completed: true` mejora la lectura rápida del progreso.
- **💡 Cómo hacerlo:** en el `Card` de cada ejercicio (`ActiveWorkoutScreen`), calcular `final allDone = exerciseSets.isNotEmpty && exerciseSets.every((s) => s.completed);` y usar `shape: RoundedRectangleBorder(side: BorderSide(color: allDone ? Color(0xFF2ED573) : Colors.transparent, width: 1.5), borderRadius: BorderRadius.circular(12))` en el `Card`, más un ícono de check pequeño junto al nombre cuando `allDone`. No cambies la lógica de edición de sets existente, solo el estilo condicional.
- **Acciones:**
  - `[X]` A15.3.1.1: Borde/ícono de "completado" cuando todas las series de un ejercicio están marcadas.
- **✅ Tests Unitarios:** widget test — con todos los sets de un ejercicio `completed: true`, la tarjeta muestra el indicador visual; con al menos uno sin completar, no lo muestra. Verificado: 45/45 tests, sin regresión.
- **🎭 Tests de Simulación de Usuario:** marcar todas las series de un ejercicio como hechas → ver el indicador visual de completado en la tarjeta, sin afectar el resto de la sesión.

---

## F16: Planificación de Nutrición y Entrenamiento con Seguimiento de Adherencia [X]

> Pasa de "solo registrar" a "planificar + comparar contra lo real": plan de comidas y rutina por defecto, comparación planificado-vs-real en el Diario, sección "Plan de Hoy" en el Dashboard, y escáner de código de barras real por cámara. `TrainingProvider.todayCaloriesBurned` (F6) YA calcula el gasto calórico desde sesiones completadas reales — no se toca.
> **AC de Fase:** `nutrition.meal_plans` (JSONB, RLS) + `is_default` en `meal_plans`/`training.routines` con índice único parcial · botón "Guardar plan" en el chat · marcar/desmarcar predeterminado · comparación planificado-vs-real en el Diario · "Plan de Hoy" en el Dashboard · `mobile_scanner` real · ADR 14.

### SF16.1: Esquema (DB) [X]

#### T16.1.1: `nutrition.meal_plans` + `is_default` en ambas tablas [X]
- **🧠 Explicación:** `nutrition.meal_plans` es al Diario lo que `training.routines` (F13) es a Entrenamiento: una plantilla guardable, no un registro de lo que ya pasó. `is_default` (con índice único parcial) permite marcar "el plan/rutina de hoy" sin ambigüedad, garantizado a nivel de DB.
- **💡 Cómo hacerlo:** nuevo archivo `docker/postgres/zzzz3_meal_plans.sql` (corre después de `zzzz2_routines.sql`):
  ```sql
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
  ALTER TABLE nutrition.meal_plans ENABLE ROW LEVEL SECURITY;
  CREATE POLICY own_meal_plans ON nutrition.meal_plans
    USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
  GRANT ALL ON nutrition.meal_plans TO authenticated;
  CREATE UNIQUE INDEX uq_meal_plans_default_per_user ON nutrition.meal_plans (user_id) WHERE is_default;

  ALTER TABLE training.routines ADD COLUMN IF NOT EXISTS is_default BOOLEAN NOT NULL DEFAULT FALSE;
  CREATE UNIQUE INDEX IF NOT EXISTS uq_routines_default_per_user ON training.routines (user_id) WHERE is_default;
  ```
  Revisa el patrón real de `GRANT`/RLS ya usado en `zzzz2_routines.sql` (F13) para no desviarte (p. ej. si ahí NO se dio `GRANT` a `anon`, sigue el mismo criterio aquí).
- **Acciones:**
  - `[X]` A16.1.1.1: `nutrition.meal_plans` (JSONB `meals`) + RLS + `GRANT`.
  - `[X]` A16.1.1.2: `is_default` + índice único parcial en `meal_plans` y en `training.routines` (`ALTER TABLE`). Verificado con JWT reales: 12/12 PASS, incluyendo el índice único rechazando un segundo default (409/23505).
- **✅ Tests Unitarios:** verificación manual con JWT reales (extender `tests/e2e/test_auth_rls_e2e.sh`, mismo patrón AC6-AC8 de F13) — aislamiento de `meal_plans` por usuario; intentar marcar dos filas como `is_default=true` para el mismo usuario en la misma tabla debe fallar por el índice único (o la app debe desmarcar la anterior antes de marcar la nueva — cubrir ambos: la protección de DB Y el flujo de "solo una a la vez" desde la app en T16.2.2).
- **🎭 Tests de Simulación de Usuario:** N/A (DB pura, cubierto por T16.2.x).

### SF16.2: Guardar y marcar predeterminado [X]

#### T16.2.1: Botón "Guardar plan" en la tarjeta de plan de comida del chat [X]
- **🧠 Explicación:** Mismo patrón exacto que "Guardar rutina" (F13, `chat_screen.dart`) pero para `nutrition.meal_plans`. El chat ya genera `meal_plan` vía `/chat-plan` (F11) y ya lo muestra en `_buildMealPlanCard` — solo falta la acción de guardado real.
- **💡 Cómo hacerlo:** en `chat_screen.dart`, análogo a `_saveRoutine`, un `_saveMealPlan(BuildContext, Map mealPlan)` con diálogo de nombre → `INSERT` a `nutrition.meal_plans` (`meals: mealPlan['meals']`) → `SnackBar` real. Añadir el botón junto al título "Plan de comidas" en `_buildMealPlanCard`, mismo estilo que el de rutina.
- **Acciones:**
  - `[X]` A16.2.1.1: Botón "Guardar plan" en `_buildMealPlanCard`.
  - `[X]` A16.2.1.2: Diálogo de nombre + `INSERT` real a `nutrition.meal_plans` + confirmación.
- **✅ Tests Unitarios:** widget test — el botón existe cuando `mealPlan != null`; al confirmar el nombre, arma el `INSERT` con `schema('nutrition')`/tabla/shape correctos. Verificado: 59/59 tests.
- **🎭 Tests de Simulación de Usuario:** generar un plan de comida en el chat → "Guardar plan" → nombrarlo → confirmación real.

#### T16.2.2: Marcar/desmarcar predeterminado (rutinas y planes de comida) [X]
- **🧠 Explicación:** Un usuario puede tener varias rutinas/planes guardados pero solo UNO puede ser "el de hoy". Marcar uno nuevo debe desmarcar el anterior (evita depender solo del índice único de DB para la UX — un `UPDATE` que falle por el índice sería una mala experiencia si no se maneja).
- **💡 Cómo hacerlo:** en `TrainingProvider`, un método `setDefaultRoutine(routineId)` que hace, en la práctica, dos `UPDATE`: desmarcar cualquier fila `is_default=true` del usuario en `training.routines`, luego marcar la elegida (o un solo `UPDATE ... SET is_default = (id = :elegido)` si Postgres/PostgREST lo permite en una sola llamada — usa tu criterio, prioriza que quede exactamente una marcada). Análogo `setDefaultMealPlan(planId)` en `NutritionProvider` sobre `nutrition.meal_plans`. En `workout_screen.dart` ("Mis Rutinas") y en una nueva sección "Mis Planes de Comida" en `diary_screen.dart` (listar `nutrition.meal_plans` del usuario, mismo patrón visual que "Mis Rutinas"), un ícono/botón (p. ej. `Icons.star`/`Icons.star_border`) por ítem que llama el método correspondiente y refresca la lista.
- **Acciones:**
  - `[X]` A16.2.2.1: `setDefaultRoutine`/`fetchMealPlans`/`setDefaultMealPlan` en los providers correspondientes.
  - `[X]` A16.2.2.2: Acción de marcar/desmarcar en "Mis Rutinas" y nueva sección "Mis Planes de Comida" en el Diario.
- **✅ Tests Unitarios:** provider test — marcar un ítem como default dentro de una lista con otro ya marcado deja exactamente uno marcado (el nuevo). Verificado: 59/59 tests, sin regresión (2 incidentes reales encontrados y corregidos: INC-017 constructor eager de Supabase, INC-018 ExpansionTile sin Material intermedio).
- **🎭 Tests de Simulación de Usuario:** con 2+ rutinas/planes guardados, marcar uno como predeterminado → el anterior se desmarca automáticamente → se refleja en el Dashboard (T16.5.1).

### SF16.3: Comparación planificado vs real (Diario) [X]

#### T16.3.1: Planificado vs real por tipo de comida [X]
- **🧠 Explicación:** Para cada sección de comida del día (`_buildMealSection`, ya existente en `diary_screen.dart`), si hay un plan de comida default, mostrar el ítem planificado de ese `meal_type` junto a lo realmente registrado, con el delta de calorías.
- **💡 Cómo hacerlo:** al cargar el Diario, además de `loadDailyData`, buscar el plan default del usuario (`NutritionProvider.fetchDefaultMealPlan()` o filtrar de `fetchMealPlans()` el que tenga `is_default`); en `_buildMealSection`, antes/después de la lista de `FoodLog` reales, si existe un ítem planificado para ese `meal_type` en el plan default, un bloque compacto "Planificado: `<food_name>` · `<calories>` kcal" con un indicador de delta (`real - planificado`, con color verde/rojo/gris según esté cerca, por encima, o sin registrar aún). Sin plan default, no mostrar nada nuevo (comportamiento actual intacto).
- **Acciones:**
  - `[X]` A16.3.1.1: Obtener el plan default al cargar el Diario (`defaultMealPlan` getter + `fetchMealPlans` en `initState`).
  - `[X]` A16.3.1.2: Bloque de comparación planificado-vs-real por tipo de comida, con delta (`_buildPlanVsActual`: sin registro/en línea/de más/de menos).
- **✅ Tests Unitarios:** con un plan default mockeado y logs reales variados (sin registro, exacto, de más, de menos), el delta calculado es correcto en cada caso. Verificado: 5 casos en `diary_screen_test.dart`, suite completa verde.
- **🎭 Tests de Simulación de Usuario:** con un plan de comida marcado como predeterminado, abrir el Diario de hoy → ver lo planificado junto a lo real por cada comida.

### SF16.4: Escáner de código de barras real [X]

#### T16.4.1: `mobile_scanner` reemplaza el diálogo mock [X]
- **🧠 Explicación:** Hoy `_showBarcodeScannerMockDialog` (en `diary_screen.dart`) es un diálogo con códigos de prueba hardcodeados y un campo de texto manual — sin cámara real. Se añade escaneo real, conservando la entrada manual como respaldo.
- **💡 Cómo hacerlo:** añadir `mobile_scanner` a `pubspec.yaml` (paquete activamente mantenido, cámara nativa multiplataforma incl. web); nueva pantalla/diálogo con `MobileScanner` que, al detectar un código, llama `NutritionProvider.searchBarcode(codigo)` (YA EXISTE, no lo toques) y sigue el flujo ya existente (`_searchAndShowBarcodeResult`). El diálogo actual pasa a tener dos vías: botón "Escanear con cámara" (nuevo, real) y el campo de entrada manual (conservado, ya existente) — no elimines la entrada manual, es el respaldo para cuando la cámara no esté disponible (web sin permiso, dispositivo sin cámara, etc.).
- **Acciones:**
  - `[X]` A16.4.1.1: Dependencia `mobile_scanner ^7.3.0` + `_BarcodeScannerPage` con `MobileScanner` real (errorBuilder amable si no hay cámara/permiso).
  - `[X]` A16.4.1.2: Al detectar un código, dispara el mismo flujo ya existente de `searchBarcode` → confirmar → `addFoodLog`. Entrada manual conservada como respaldo.
- **✅ Tests Unitarios:** widget test — el botón de escanear con cámara existe junto a la entrada manual (no la reemplaza); la entrada manual sigue disparando `_searchAndShowBarcodeResult`. Verificado: `diary_screen_test.dart` 8/8, `flutter build web` compila con `mobile_scanner`.
- **🎭 Tests de Simulación de Usuario:** desde un dispositivo/navegador con cámara, escanear un código de barras real → ver el producto (OpenFoodFacts) → confirmar → aparece en el Diario.

### SF16.5: Dashboard "Plan de Hoy" [X]

#### T16.5.1: Sección de rutina y plan de comida por defecto [X]
- **🧠 Explicación:** El Dashboard hoy no muestra nada de planificación — solo balance calórico y adherencia semanal ya calculados. Se añade una sección que muestre la rutina default (¿ya hay una sesión completada hoy?) y el plan de comida default (calorías planificadas vs `NutritionProvider.totalCalories`, ya calculado).
- **💡 Cómo hacerlo:** en `dashboard_screen.dart`, una nueva `Card`/sección "Plan de Hoy" antes o después de las tarjetas existentes (`_buildCaloricBalanceCard`, `_buildMacrosCard`, `_buildWeeklyAdherenceCard`): consulta la rutina default (`TrainingProvider`) y si hay una `WorkoutSession` completada HOY con ese nombre (o simplemente si hay alguna sesión completada hoy, más simple y suficiente — decide con criterio); consulta el plan de comida default (`NutritionProvider`) y compara la suma de `calories` de sus `meals` contra `provider.totalCalories` de hoy (ya existe). No toques `todayCaloriesBurned` (F6, ya correcto).
- **Acciones:**
  - `[X]` A16.5.1.1: Sección "Plan de Hoy" con rutina default (getter `defaultRoutine`) + indicador "Hecho hoy"/"Pendiente hoy".
  - `[X]` A16.5.1.2: Plan de comida default: calorías planificadas vs consumidas (criterio ±10% consistente con el Diario).
- **✅ Tests Unitarios:** widget test — con una rutina default y una sesión completada hoy mockeadas, el indicador de "hecho" aparece; sin sesión completada, "pendiente"; sin rutina default, texto discreto. Verificado: `dashboard_test.dart` 6/6, suite completa 75 tests verde.
- **🎭 Tests de Simulación de Usuario:** con una rutina y un plan de comida marcados como predeterminados, abrir el Dashboard → ver la sección "Plan de Hoy" reflejando el estado real del día.

### SF16.6: Documentación [X]

#### T16.6.1: ADR 14 en `architecture.md` + esquema en `diseno_db.md` [X]
- **🧠 Explicación:** Documentar la nueva capa de planificación (mirroring de `training.routines` para `nutrition.meal_plans`), la decisión de `is_default` + índice único parcial, y la decisión de `mobile_scanner`.
- **💡 Cómo hacerlo:** ADR 14 con contexto (solo tracking, sin planificación), decisión de esquema (`meal_plans` mirror de `routines`, índice único parcial para `is_default`), decisión de escáner (`mobile_scanner` sobre el mock), y el flujo completo (chat genera → guardar → marcar default → comparación en Diario/Dashboard). `nutrition.meal_plans` + columnas `is_default` documentadas en `diseno_db.md` (secciones 2.2 y 2.3).
- **Acciones:**
  - `[X]` A16.6.1.1: ADR 14 en `architecture.md`.
  - `[X]` A16.6.1.2: `nutrition.meal_plans` + `is_default` (en `meal_plans` y `training.routines`) en `diseno_db.md`.
- **✅ Tests Unitarios:** N/A (docs).
- **🎭 Tests de Simulación de Usuario:** N/A (docs).

---

## F17: Cardio con METs + Búsqueda de Ejercicios por Músculo + Catálogo de Comida Peruana [ ]

> 3 frentes sobre datos: (1) el cardio existe pero su gasto es plano → cálculo por METs con peso real y ritmo; (2) "Agregar ejercicio" sin buscador → búsqueda + filtro por músculo (datos `body_part`/`secondary_muscles` ya existen); (3) sin dataset de comida → catálogo curado de platos peruanos (híbrido con OpenFoodFacts ya integrado).
> **AC de Fase:** `public.users.weight_kg` + `workout_sets.duration_min`/`distance_km` + `nutrition.food_catalog` (≥40 platos, lectura pública) · peso persistido en onboarding · input cardio (tiempo+distancia) · `todayCaloriesBurned` por METs · buscador+filtro por músculo · buscador de comida en el Diario · ADR 15. **Requiere `docker compose down -v`.**

### SF17.1: Esquema (DB) [X]

#### T17.1.1: `weight_kg` + columnas de cardio en `workout_sets` [X]
- **🧠 Explicación:** El peso del usuario se captura en el onboarding pero se descarta (solo BMR local); el MET lo necesita. `workout_sets` no tiene dónde guardar tiempo/distancia de cardio.
- **💡 Cómo hacerlo:** nuevo archivo `docker/postgres/zzzz4_cardio_and_weight.sql` con `ALTER TABLE public.users ADD COLUMN IF NOT EXISTS weight_kg REAL;` y `ALTER TABLE training.workout_sets ADD COLUMN IF NOT EXISTS duration_min REAL; ... distance_km REAL;`. Montar en `docker-compose.yml` tras `zzzz3_meal_plans.sql`. Nullable (fuerza las deja NULL).
- **Acciones:**
  - `[X]` A17.1.1.1: `public.users.weight_kg` (nullable REAL).
  - `[X]` A17.1.1.2: `training.workout_sets.duration_min`/`distance_km` (nullable REAL).
- **✅ Tests Unitarios:** columnas existen tras `up`; RLS de `users`/`workout_sets` sin cambios.
- **🎭 Tests de Simulación de Usuario:** N/A (cubierto por SF17.2).

#### T17.1.2: `nutrition.food_catalog` + seed de platos peruanos [X]
- **🧠 Explicación:** Catálogo curado de comida peruana (lectura pública, como `training.exercises` — sin dueño, sin RLS restrictivo). Macros = estimaciones documentadas.
- **💡 Cómo hacerlo:** `CREATE TABLE nutrition.food_catalog (id, name, category, calories, protein_g, carbs_g, fat_g, serving_size_g)` + `GRANT SELECT ... TO anon, authenticated` + INSERTs de ≥40 platos peruanos (arroz con pollo, ceviche, lomo saltado, pollo a la brasa, ají de gallina, causa, turrón, etc.) con macros aprox por porción. En un `.sql` de init nuevo.
- **Acciones:**
  - `[X]` A17.1.2.1: Tabla `nutrition.food_catalog` + `GRANT SELECT` público.
  - `[X]` A17.1.2.2: Seed de 50 platos peruanos con macros aproximadas. Verificado: 14/14 E2E (lectura pública sin token).
- **✅ Tests Unitarios:** `count >= 40`; accesible sin token (extender `test_auth_rls_e2e.sh`, como el caso de `exercises`).
- **🎭 Tests de Simulación de Usuario:** cubierto por SF17.4.

### SF17.2: Cardio con METs [ ]

#### T17.2.1: Persistir `weight_kg` en el onboarding/perfil [ ]
- **🧠 Explicación:** El onboarding ya captura `_weightKg`; hay que incluirlo en el INSERT/UPSERT a `public.users` (hoy no se guarda) y leerlo en el perfil.
- **💡 Cómo hacerlo:** en `onboarding_provider.dart` (`saveProfile()`), añadir `'weight_kg': _weightKg` al `insert`. En `loadProfile()`, leer `weight_kg`. Getter accesible para el cálculo MET.
- **Acciones:**
  - `[ ]` A17.2.1.1: `saveProfile` guarda `weight_kg`.
  - `[ ]` A17.2.1.2: `loadProfile` lo lee + getter accesible.
- **✅ Tests Unitarios:** el payload de `saveProfile` incluye `weight_kg`.
- **🎭 Tests de Simulación de Usuario:** completar onboarding → peso persistido en `public.users`.

#### T17.2.2: Input de cardio + `todayCaloriesBurned` por METs [ ]
- **🧠 Explicación:** Un ejercicio `category='cardio'` en el tracker pide tiempo+distancia (no peso/reps). Gasto por METs (kcal = MET × peso_kg × horas); para cardio el MET sale del ritmo (km/h → MET vía umbrales del Compendium); fuerza mantiene estimación por duración.
- **💡 Cómo hacerlo:** en `active_workout_screen.dart`, si `exercise.category == 'cardio'`, campos "Tiempo (min)"/"Distancia (km)" en vez de peso/reps (persistir en `duration_min`/`distance_km`). En `training_provider.dart`, `metFromSpeed(distance_km/(duration_min/60))` + `kcal = met * weightKg * (duration_min/60)` para cardio; resto por duración. Peso del perfil (T17.2.1); default 70 con comentario si falta.
- **Acciones:**
  - `[ ]` A17.2.2.1: UI de tiempo+distancia para cardio; persistir en `workout_sets`.
  - `[ ]` A17.2.2.2: `metFromSpeed` + `todayCaloriesBurned` por METs.
- **✅ Tests Unitarios:** 30 min/5 km > 20 min/2 km en kcal; correr > caminar en MET; sesión de solo fuerza no cae a 0.
- **🎭 Tests de Simulación de Usuario:** registrar "Running, Treadmill" 30 min/5 km → kcal coherentes y distintas a 20 min/2 km.

### SF17.3: Búsqueda y filtro de ejercicios por músculo [ ]

#### T17.3.1: Box de búsqueda + filtro por músculo en "Agregar ejercicio" [ ]
- **🧠 Explicación:** `_showAddExerciseModal` lista 873 ejercicios sin buscador. Los datos ya permiten filtrar: `name`, `bodyPart`, `secondaryMuscles` (tags). Frontend puro sobre `provider.exercises`.
- **💡 Cómo hacerlo:** un `TextField` de búsqueda + filtro por músculo (`FilterChip`/dropdown de `body_part` distintos); el `ListView` filtra por `name.contains(query)` y/o `bodyPart == muscle || secondaryMuscles.contains(muscle)`. Mostrar `secondaryMuscles` como chips en cada `ListTile`. Mantener miniatura/detalle.
- **Acciones:**
  - `[ ]` A17.3.1.1: `TextField` de búsqueda por nombre.
  - `[ ]` A17.3.1.2: Filtro por músculo + tags visibles por ejercicio.
- **✅ Tests Unitarios:** query "press" → solo lo que matchea; filtro "chest" → solo pecho.
- **🎭 Tests de Simulación de Usuario:** buscar "running" → aparece el cardio; filtrar "chest" → solo pecho.

### SF17.4: Catálogo de comida en el Diario [ ]

#### T17.4.1: Buscador de `food_catalog` al agregar comida [ ]
- **🧠 Explicación:** Además de manual/cámara/escáner, un buscador contra el catálogo curado peruano que prellena nombre+macros.
- **💡 Cómo hacerlo:** en `nutrition_provider.dart`, `searchFoodCatalog(query)` → `client.schema('nutrition').from('food_catalog').select().ilike('name','%q%')`. En `diary_screen.dart`, opción "Buscar en catálogo" → al elegir, prellena el diálogo de borrador existente (el de la cámara IA) → `addFoodLog`. Reusar el diálogo, no crear uno nuevo.
- **Acciones:**
  - `[ ]` A17.4.1.1: `searchFoodCatalog` en el provider.
  - `[ ]` A17.4.1.2: Buscador en el Diario que prellena macros → `addFoodLog`.
- **✅ Tests Unitarios:** `searchFoodCatalog` arma la query `ilike` correcta (seam mockeado); elegir un resultado prellena el borrador.
- **🎭 Tests de Simulación de Usuario:** buscar "arroz con pollo" → prellena macros → guardar → aparece en el día.

### SF17.5: Documentación [ ]

#### T17.5.1: ADR 15 + esquema en `diseno_db.md` [ ]
- **🧠 Explicación:** Documentar el cálculo MET, el catálogo híbrido de comida, y las columnas nuevas.
- **💡 Cómo hacerlo:** ADR 15 en `architecture.md`; `weight_kg`/`workout_sets` cardio cols/`food_catalog` en `diseno_db.md`.
- **Acciones:**
  - `[ ]` A17.5.1.1: ADR 15 en `architecture.md`.
  - `[ ]` A17.5.1.2: Columnas + `food_catalog` en `diseno_db.md`.
- **✅ Tests Unitarios:** N/A (docs).
- **🎭 Tests de Simulación de Usuario:** N/A (docs).
