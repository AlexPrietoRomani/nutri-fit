# Plan Maestro: Nutri-Fit (Fase por Fase y Eventos de UI)

Este documento detalla la planificación del desarrollo de Nutri-Fit, incluyendo la división de backend y la correlación entre flujos de pantalla (UI) y efectos en base de datos.

---

## 1. Stack Tecnológico Definitivo

| Capa | Tecnología | Versión | Justificación |
|---|---|---|---|
| **Frontend** | Flutter (Dart) | >= 3.22 | Código único para Web y Mobile. |
| **Backend Core** | Supabase (Docker) | Local Stack | Esquemas aislados en PostgreSQL, Auth y Storage local. |
| **Microservicio AI** | FastAPI (Python) | 3.11 | API independiente para procesar imágenes con Ollama (Vision). |

---

## 2. Fases de Ejecución

### Fase 1: Setup e Infraestructura Modular
- **F1.SF1: Entorno Docker y Esquemas DB**
  - T1.1.1: Configurar docker-compose con Supabase, FastAPI y Ollama.
  - T1.1.2: Crear base de datos en PostgreSQL con esquemas `public`, `nutrition` y `training` de forma aislada.
- **F1.SF2: Configuración Inicial de Flutter**
  - T1.2.1: Inicializar estructura del frontend y dependencias de Supabase.

### Fase 2: Diseño de UI y Mapeo de Flujos de Clics
- **F2.SF1: Prototipado del Flujo Onboarding & Dashboard**
  - T2.1.1: Crear vistas en Flutter para Onboarding (carrusel de preguntas) y Dashboard Principal (calendario).
  - T2.1.2: Vincular eventos de clics de UI con llamadas de base de datos (`public.users` y `nutrition.user_goals`).
- **F2.SF2: Flujos del Diario y del Tracker Activo**
  - T2.2.1: Crear la interfaz del Diario Alimenticio y vincular botones de agregar comida manual o mediante cámara de IA.
  - T2.2.2: Diseñar la pantalla de entrenamiento interactiva en Flutter (LiftLog style) y vincular acciones de completado de series con `training.workout_sets` (SQL UPSERT).

### Fase 3: Construcción - Módulo de Nutrición (Fitia/OpenNutriTracker)
- **F3.SF1: Diario Alimenticio y BMR**
  - T3.1.1: Implementar algoritmo Mifflin-St Jeor en Dart e inserción del perfil nutricional en `nutrition.user_goals`.
  - T3.1.2: Habilitar registro, edición y eliminación de comidas diarias (`nutrition.food_logs`).
- **F3.SF2: Escáner e Integración con OpenFoodFacts**
  - T3.2.1: Implementar el escáner de códigos de barra usando la cámara nativa en Flutter.
  - T3.2.2: Conectar con OpenFoodFacts e implementar caché local de alimentos para acelerar búsquedas repetidas.

### Fase 4: Construcción - Módulo de Entrenamiento (Strong/LiftLog)
- **F4.SF1: Catálogo y Creador de Rutinas**
  - T4.1.1: Precargar tabla `training.exercises` con ejercicios base.
  - T4.1.2: Permitir diseño de rutinas personalizadas segmentadas por equipamiento.
- **F4.SF2: Tracker de Entrenamiento en Vivo**
  - T4.2.1: Implementar cronómetro y vista interactiva para marcar series (sets) como completados.
  - T4.2.2: Registro de datos de peso, reps y RPE en `training.workout_sets`.

### Fase 5: Microservicio e IA de Visión (Self-Hosted)
- **F5.SF1: API Gateway (FastAPI)**
  - T5.1.1: Implementar endpoint en Python para recibir fotos subidas de Supabase Storage.
  - T5.1.2: Configurar llamadas a modelos Vision de Ollama (local) o Gemini (fallback en la nube).
- **F5.SF2: Detección Automática de Comida y Máquinas**
  - T5.2.1: Pipeline de detección de calorías y macros de platos a partir de fotos.
  - T5.2.2: Pipeline de identificación de máquinas del gimnasio y mapeo de ejercicios aptos.

### Fase 6: Dashboard y Métricas de Progreso  _(completada)_
- **F6.SF1: Balance Calórico Real e Interactividad** — Dashboard unificado (`NutritionProvider`+`TrainingProvider`), balance `Objetivo - Ingerido + Quemado`, barras de macros y adherencia. Detalle en `docs/task/tareas.md` (F6).

### Fase 7: Integración de Dataset Público de Ejercicios (free-exercise-db)  _(completada — PR #1)_
- **Macro-objetivo:** Reemplazar el catálogo hardcodeado de 8 ejercicios por 800+ de dominio público (`yuhonas/free-exercise-db`, Unlicense) con imágenes, extendiendo `training.exercises` y la UI.
- **Entregable:** `training.exercises` poblada por seed (873 ejercicios) con imágenes, consumible desde Flutter.
- **AC:** ≥800 filas en DB limpia · cada fila con `name`/`target_muscle`/`equipment`/`image_urls` · docs actualizadas · FK `workout_sets→exercises` íntegro · imagen visible en el detalle.
- **F7.SF1: Modelo de datos + docs** — T7.1.1 extender `training.exercises`; T7.1.2 ADR 6.
- **F7.SF2: Import y seed** — T7.2.1 generador `exercises.json`→`zz_exercises_seed.sql`; T7.2.2 estrategia de media.
- **F7.SF3: Frontend** — T7.3.1 modelo `Exercise` + quitar seed hardcodeado; T7.3.2 render imagen/instrucciones.

### Fase 8: Chatbot de IA Multi-Proveedor  _(completada — PR #1)_
- **Macro-objetivo:** Asistente de IA (planes de comida, rutinas con ejercicios reales, Q&A, coach) servido por el `ai_service` con capa multi-proveedor.
- **Proveedores:** OpenAI, OpenRouter, Gemini, LM Studio, vLLM, Ollama (protocolo OpenAI-compatible, SDK `openai`) + Claude (SDK `anthropic`, `claude-opus-4-8`). Config por request desde la app (secure storage).
- **AC:** `/chat` enruta al proveedor y da 503 claro si no hay; capa soporta los 7; `/generate-meal-plan` JSON coherente con `user_goals`; `/generate-workout-plan` con `exercise_id` reales; `/analyze-progress`; pantallas Ajustes+Chat; ADR + sin claves hardcodeadas.
- **F8.SF1: Capa multi-proveedor (backend)** — T8.1.1 `ai_engine`; T8.1.2 deps + env.
- **F8.SF2: Endpoints** — T8.2.1 `/chat`; T8.2.2 `/generate-meal-plan`; T8.2.3 `/generate-workout-plan`; T8.2.4 `/analyze-progress`.
- **F8.SF3: Frontend + docs** — T8.3.1 Ajustes; T8.3.2 Chat; T8.3.3 ADR 7.
- **Chat stateless (MVP):** sin tabla de historial; no toca `diseno_db.md`.

### Fase 9: IA de Visión en el Frontend (foto → macros / máquina)
- **Macro-objetivo:** Cablear al cliente los endpoints de visión que ya existen en el backend pero que nadie llamaba (`/analyze-meal`, `/identify-machine`): foto de comida → calorías/macros guardables; foto de máquina → nombre + ejercicios. Visión **multi-proveedor** (reusa `AIConfig` de F8) con fallback a Ollama `llava` + mock.
- **Entregable global:** "Tomar foto con IA" en el Diario (foto → borrador → confirmar → `nutrition.food_logs`) y "Escanear máquina con IA" en el Entrenamiento (foto → máquina + ejercicios + tips).
- **Decisión de alcance:** No añade tabla/columna (`nutrition.food_logs` ya existe) → **no toca `diseno_db.md`**. La foto no se persiste (MVP).
- **Criterios de Aceptación (AC):**
  - **AC1:** `ai_engine` soporta visión (imagen base64): OpenAI-compat vía `image_url`, Anthropic vía bloques `image`. `/analyze-meal` y `/identify-machine` aceptan `AIConfig` opcional; sin config → fallback Ollama `llava` → mock.
  - **AC2:** Diario "Tomar foto con IA": captura/elige imagen → `/analyze-meal` → borrador (nombre/calorías/macros) → confirmar → `INSERT` en `nutrition.food_logs` + refresco.
  - **AC3:** Entrenamiento "Escanear máquina con IA": foto → `/identify-machine` → máquina, músculos, ejercicios y tips.
  - **AC4:** ADR de visión en `architecture.md`; sin claves hardcodeadas; degradación al mock sin crash.
- **Estrategia de Pruebas (nivel Fase):**
  - **Tests Unitarios:** enrutamiento de visión por `protocol` (mock `openai`/`anthropic`); endpoints parsean/validan y caen al mock sin proveedor.
  - **Tests de Simulación de Usuario:** Diario — foto → borrador → confirmar → comida en lista+DB; Entrenamiento — escanear → ficha + ejercicios.
- **F9.SF1: Visión multi-proveedor (backend)**
  - T9.1.1: `ai_engine.generate_vision(cfg, prompt, image_b64)` (OpenAI-compat `image_url` + Anthropic `image`).
  - T9.1.2: `/analyze-meal` y `/identify-machine` aceptan `AIConfig` opcional; fallback Ollama `llava` + mock.
- **F9.SF2: Cámara y flujos (frontend)**
  - T9.2.1: Dep `image_picker` + servicio de captura/subida al `ai_service` con la `AIConfig` guardada.
  - T9.2.2: Diario — "Tomar foto con IA" → borrador → confirmar → `nutrition.food_logs`.
  - T9.2.3: Entrenamiento — "Escanear máquina con IA" → ficha + ejercicios.
- **F9.SF3: Documentación**
  - T9.3.1: ADR/flujo de visión en `architecture.md`.

### Fase 10: Autenticación Real (GoTrue + RLS)
- **Macro-objetivo:** Reemplazar el bypass de auth (todos comparten `devUserId` `000…000`) por **autenticación real con GoTrue** y **aislamiento por usuario con Row-Level Security**, cerrando la deuda de INC-003/INC-006. Cada usuario ve y escribe solo sus propios datos.
- **Entregable global:** login/signup/logout funcional con sesión persistente; `devUserId` eliminado del código; RLS activo en las tablas de datos del usuario; el catálogo `training.exercises` sigue siendo de lectura pública; docs (ADR de auth + RLS/FK) actualizadas.
- **Decisión de alcance:** Nueva Fase — introduce un dominio nuevo (identidad/seguridad), un servicio nuevo (GoTrue) y un cambio de esquema (FK a `auth.users` + políticas RLS). **Toca `architecture.md` Y `diseno_db.md`** → correr `auditar-coherencia` antes de commitear. No crea tablas de negocio nuevas; `daily_summaries` no existe como tabla (queda fuera).
- **Criterios de Aceptación (AC):**
  - **AC1 (Infra):** GoTrue corre en el stack; el gateway (`:54321`) enruta `/auth/v1/` → GoTrue y conserva `/rest/v1/` → PostgREST; `signup`/`token` responden y el health del stack queda verde.
  - **AC2 (DB/RLS):** `public.users.id` con FK a `auth.users(id)` `ON DELETE CASCADE`; RLS habilitado con políticas `auth.uid()`-based en `public.users`, `nutrition.user_goals`, `nutrition.food_logs`, `training.workout_sessions` y `training.workout_sets` (esta última por pertenencia de la sesión); `training.exercises` con lectura pública. Un usuario no puede leer/escribir filas de otro.
  - **AC3 (Frontend auth):** pantallas de login/signup/logout con `supabase_flutter`; la sesión persiste entre recargas; **cero referencias a `AppConstants.devUserId`** en el código de runtime; gate: sin sesión → login, con sesión sin perfil → onboarding, con sesión y perfil → dashboard.
  - **AC4 (Providers):** `onboarding`/`nutrition`/`training`/`dashboard` usan `client.auth.currentUser!.id`; el onboarding escribe `public.users`/`user_goals` atados al usuario autenticado; el `ai_service` (stateless, solo lee `training.exercises` público) sigue funcionando.
  - **AC5 (Docs):** ADR de autenticación en `architecture.md` (flujo login→sesión→RLS; retira la nota de bypass); RLS + FK documentados en `diseno_db.md`.
- **Estrategia de Pruebas (nivel Fase):**
  - **Tests Unitarios:** SQL de RLS (un `SET request.jwt.claims` de usuario B no ve filas de A; select del catálogo permitido a anon); widget tests de login/signup (validación de email/clave, estados de error); provider tests (leen `currentUser.id`, no `devUserId`).
  - **Tests de Simulación de Usuario:** signup → onboarding → dashboard con datos propios; logout → vuelve a login; el usuario B autenticado no ve el diario del usuario A.
- **F10.SF1: Infraestructura de Auth (GoTrue + gateway)**
  - T10.1.1: Añadir el servicio GoTrue a `docker-compose.yml` (DB, `GOTRUE_JWT_SECRET`, `SITE_URL`, signup habilitado, sin verificación de email en dev).
  - T10.1.2: Enrutar `/auth/v1/` → GoTrue en el gateway nginx, conservando `/rest/v1/` → PostgREST y el CORS ya arreglado.
- **F10.SF2: Esquema y RLS (DB)**
  - T10.2.1: Re-instaurar la FK `public.users.id` → `auth.users(id)` `ON DELETE CASCADE` y el aprovisionamiento del perfil (trigger `handle_new_user` o INSERT en onboarding tras signup).
  - T10.2.2: Habilitar RLS + políticas por usuario en las tablas de datos; `training.exercises` lectura pública (GRANT/policy a `anon`/`authenticated`).
- **F10.SF3: Autenticación en el Frontend**
  - T10.3.1: Pantalla Login/Signup/Logout con `supabase_flutter` + `AuthGate` reactivo a `onAuthStateChange`.
  - T10.3.2: Reemplazar `devUserId` por `currentUser!.id` en providers, dashboard y `main.dart`; onboarding atado al usuario autenticado.
- **F10.SF4: Documentación**
  - T10.4.1: ADR de autenticación en `architecture.md` (retira el bypass) + RLS/FK en `diseno_db.md`.
