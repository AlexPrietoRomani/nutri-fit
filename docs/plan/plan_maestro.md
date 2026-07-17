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

### Fase 11: Chat Unificado con Orquestador de Rutinas y Planes de Comida (FAB global)
- **Macro-objetivo:** El chatbot (F8) hoy expone 3 endpoints separados (`/chat`, `/generate-workout-plan`, `/generate-meal-plan`) que la UI nunca combina, y solo se accede navegando a `/chat`. Esta Fase unifica la experiencia: un botón flotante (FAB) accesible desde las pantallas principales abre el chat sin perder el contexto, y una sola consulta en lenguaje natural puede disparar rutina Y plan de comidas a la vez, mostrados como tarjetas legibles en la conversación (no solo texto plano del LLM).
- **Entregable global:** FAB en Dashboard/Diario/Entrenamiento que abre el chat como modal; una consulta como *"Creame un entrenamiento diario si solo tengo una caminadora de hasta 10KM/hr y una pesa rusa de 10kg, para bajar de peso; además de crearme un plan de desayuno, almuerzo y cena completo"* genera ambos resultados en un solo turno de chat.
- **Decisión de arquitectura (evaluada en esta planificación):** de las 3 opciones (a: tool-calling del proveedor; b: endpoint orquestador en el `ai_service`; c: parseo en frontend), se elige **(b) orquestador backend**. Razón: tool-calling no es uniforme entre los 7 proveedores soportados (modelos locales vía Ollama/LM Studio no siempre implementan function-calling de forma confiable), y parsear texto libre en el frontend es frágil. El orquestador hace UNA llamada de extracción de intención (JSON plano, mismo patrón `want_json` ya usado en F8/F9) y, según lo detectado, invoca internamente la MISMA lógica que ya usan `/generate-workout-plan`/`/generate-meal-plan` (refactorizada a funciones compartidas), sin duplicar prompts.
- **Restricción real del catálogo (verificada):** `training.exercises` tiene 53 filas con `equipment='kettlebells'` pero **0** con `equipment` de tipo caminadora/treadmill (el dataset `free-exercise-db` es de fuerza, no tiene cardio de máquina). La rutina generada para el caso de prueba combina: ejercicios reales de `kettlebells` del catálogo (sin alucinar `exercise_id`, igual que F8) + un bloque de cardio en caminadora como instrucción directa en el JSON de salida (sin `exercise_id`, ya que el catálogo no lo cubre) — esto se documenta explícitamente para no prometer cobertura que el dataset no tiene.
- **Criterios de Aceptación (AC):**
  - **AC1:** Nuevo endpoint `POST /chat-plan` en el `ai_service`: recibe `{message, profile?, ai}`, hace una llamada de extracción de intención (`wants_workout`, `wants_meal_plan`, `equipment: []`, `goal`, `preferences`), y devuelve `{reply: str, workout: {...}|null, meal_plan: {...}|null}`. Reusa `_fetch_exercise_candidates`/filtro anti-alucinación ya existente para la rutina.
  - **AC2:** `/generate-workout-plan` y `/generate-meal-plan` (F8) se refactorizan a funciones internas reusables sin cambiar su contrato HTTP externo (endpoints existentes siguen funcionando igual; cero regresión).
  - **AC3:** FAB global visible en Dashboard, Diario y Entrenamiento que abre el chat en un modal/bottom sheet (no navegación de página completa) — conserva el contexto de la pantalla desde la que se abrió.
  - **AC4:** El chat renderiza, además del texto de `reply`, una tarjeta de rutina (ejercicios con sets/reps/rpe) cuando `workout` viene no-nulo, y una tarjeta de plan de comidas (comidas con macros) cuando `meal_plan` viene no-nulo.
  - **AC5 (caso de prueba obligatorio):** la consulta exacta del caso de prueba genera AMBOS resultados: rutina con ejercicios reales de `kettlebells` + bloque de cardio en caminadora como instrucción, y un plan de 3 tiempos (desayuno/almuerzo/cena) con macros coherentes con déficit calórico.
  - **AC6:** ADR 10 en `architecture.md` documentando el orquestador y la decisión (b) sobre (a)/(c). No toca `diseno_db.md` (sin tablas nuevas).
- **Estrategia de Pruebas (nivel Fase):**
  - **Tests Unitarios:** extracción de intención con motor mockeado (detecta `wants_workout`/`wants_meal_plan`/`equipment` correctamente desde texto libre); `/chat-plan` devuelve `workout`/`meal_plan` según lo detectado y `null` cuando no aplica; los endpoints `/generate-workout-plan`/`/generate-meal-plan` originales siguen pasando sus tests existentes tras el refactor.
  - **Tests de Simulación de Usuario:** desde el Dashboard, tocar el FAB → escribir la consulta del caso de prueba → ver la tarjeta de rutina (con ejercicios de kettlebell + cardio) y la tarjeta de plan de comidas en la misma respuesta.
- **F11.SF1: Orquestador de intención (backend)**
  - T11.1.1: Refactorizar `_build_workout_plan`/`_build_meal_plan` como funciones internas reusables desde `main.py` (extraídas de los endpoints F8 existentes, sin cambiar su contrato HTTP).
  - T11.1.2: Endpoint `POST /chat-plan` — extracción de intención (JSON) + orquestación condicional de rutina/plan de comidas + `reply` conversacional.
- **F11.SF2: FAB global y tarjetas en el chat (frontend)**
  - T11.2.1: FAB compartido (widget reusable) en Dashboard/Diario/Entrenamiento que abre el chat como modal, sin perder el contexto de la pantalla.
  - T11.2.2: `ChatScreen`/`AiProvider` consumen `/chat-plan`; tarjetas de rutina y de plan de comidas embebidas en los mensajes del asistente.
- **F11.SF3: Documentación**
  - T11.3.1: ADR 10 (orquestador chat+generación) en `architecture.md`.

### Fase 12: Gestión de Modelos Ollama (selector en vivo + instalación de modelos recomendados)
- **Macro-objetivo:** Cierra el bug reportado: el modelo sugerido por defecto para `ollama` (`kSuggestedModel['ollama']='llama3.1'`) no está instalado en el Ollama real del usuario, y el campo de modelo es texto libre — nadie ve qué modelos existen de verdad hasta que el chat falla con un 404/503. Se añade un dominio nuevo (gestión de modelos Ollama: listar instalados, instalar recomendados) que F8 nunca cubrió (F8 solo consume `AIConfig`, no administra el Ollama del usuario).
- **Entregable global:** en Ajustes de IA, al elegir proveedor `ollama` aparece un desplegable con los modelos REALMENTE instalados (no texto libre a ciegas) y una sección "Modelos recomendados" con botón de instalar y progreso de descarga.
- **Hallazgo de infraestructura (verificado, no re-investigar):** `docker-compose.yml` tiene un servicio `ollama` (imagen `ollama/ollama:latest`) que mapea el puerto **11434 del host** al contenedor — compite con el Ollama nativo de Windows del usuario, que escucha en el mismo puerto del host y es el que tiene los modelos reales (`gemma4:e4b`, `gemma4:26b`, `llama3.2:latest`, `qwen2.5:3b`). El backend usa `OLLAMA_HOST` con default `http://ollama:11434` (el servicio docker, casi vacío) en vez de `host.docker.internal:11434` (el Ollama real). Esta Fase corrige el default y resuelve el conflicto de puerto para que "listar modelos instalados" no muestre el Ollama equivocado.
- **Decisión de arquitectura:** el listado/instalación de modelos pasa por el **backend** (`ai_service`), no por el navegador directo a Ollama — aunque Ollama respondió con CORS abierto en la prueba manual, depender de la config de CORS de un proceso externo que el usuario no controla desde la app es frágil; el backend ya tiene `CORSMiddleware` abierto y es el mismo patrón ya usado para todo lo demás (F8/F9/F11).
- **Criterios de Aceptación (AC):**
  - **AC1 (infra):** el servicio `ollama` de `docker-compose.yml` deja de competir por el puerto 11434 del host (se quita el mapeo de puerto o se remueve el servicio si no lo usa nada más); `OLLAMA_HOST` por defecto del backend apunta a `host.docker.internal:11434`.
  - **AC2 (backend):** `GET /ollama/models?base_url=...` devuelve la lista real de modelos instalados (nombre, tamaño) consultando `/api/tags` nativo del Ollama que corresponda al `base_url` configurado (con o sin sufijo `/v1`). `POST /ollama/pull {base_url, model}` inicia una descarga en background contra `/api/pull` nativo; `GET /ollama/pull-status?model=...` expone el progreso hasta completarse.
  - **AC3 (frontend):** en Ajustes de IA, si el proveedor es `ollama`, el campo de modelo es un desplegable poblado con `GET /ollama/models`; si Ollama no es alcanzable, cae a `TextField` libre (no rompe el flujo existente). Sección "Modelos recomendados" (lista curada: `gemma4:e4b`, `llama3.2:3b`, `qwen2.5:3b`) con botón "Instalar" por cada modelo no presente en la lista instalada, mostrando progreso y refrescando el desplegable al terminar.
  - **AC4 (caso de prueba):** con el Ollama real del usuario, el desplegable lista exactamente los modelos instalados (sin inventar ninguno); pulsar "Instalar" en un modelo recomendado no instalado lo dispara, progresa y termina apareciendo en el desplegable.
  - **AC5 (docs):** ADR 11 en `architecture.md` documentando el hallazgo de infraestructura, la decisión de pasar por el backend, y el flujo de listar/instalar. No toca `diseno_db.md` (sin tablas nuevas).
- **Estrategia de Pruebas (nivel Fase):**
  - **Tests Unitarios:** backend — `GET /ollama/models` parsea la respuesta de `/api/tags` (mockeada) a la forma esperada y maneja Ollama inalcanzable con una lista vacía/error claro, no un 500; `POST /ollama/pull`/`GET /ollama/pull-status` actualizan y exponen el estado en memoria correctamente (mockeando la llamada NDJSON a Ollama). Frontend — el desplegable se puebla con los modelos devueltos y cae a texto libre si la llamada falla.
  - **Tests de Simulación de Usuario:** abrir Ajustes de IA, elegir `ollama`, ver el desplegable con los modelos reales del Ollama del usuario; pulsar "Instalar" en un modelo recomendado y verificar que, tras completarse, aparece seleccionable en el desplegable.
- **F12.SF1: Infraestructura (puerto Ollama y default del backend)**
  - T12.1.1: Resolver el conflicto de puerto 11434 en `docker-compose.yml` y corregir el default de `OLLAMA_HOST` a `host.docker.internal:11434`.
- **F12.SF2: Backend — listar e instalar modelos**
  - T12.2.1: `GET /ollama/models?base_url=...` (consulta `/api/tags` nativo, derivando el host desde `base_url`).
  - T12.2.2: `POST /ollama/pull` + `GET /ollama/pull-status` (descarga en background con progreso consultable).
- **F12.SF3: Frontend — desplegable + modelos recomendados**
  - T12.3.1: Desplegable de modelos instalados en Ajustes de IA (con fallback a texto libre).
  - T12.3.2: Sección "Modelos recomendados" con instalación y progreso.
- **F12.SF4: Documentación**
  - T12.4.1: ADR 11 en `architecture.md`.

### Fase 13: Rutinas Guardables (persistencia real de rutinas generadas por IA)
- **Macro-objetivo:** Cierra un hallazgo crítico: cuando el usuario le pide al chat "ponme esa rutina en mis ejercicios", el chat **afirma** haberla guardado/cargado, pero es una **alucinación del LLM** — no existe ningún mecanismo de persistencia (verificado por grep, cero resultados). Además, `training.workout_sessions`/`workout_sets` solo registran sesiones ya ejecutadas (peso/reps reales), nunca existió una plantilla reutilizable con sets/reps *objetivo* que el usuario pueda guardar con nombre y seguir después.
- **Entregable global:** botón explícito "Guardar rutina" en la tarjeta de rutina del chat (nunca depende de que el LLM "confirme" nada); las rutinas guardadas aparecen en Entrenamiento junto a las 3 predefinidas; iniciar una rutina guardada prellena sets/reps/rpe objetivo por ejercicio (para "seguir los pasos"); el texto de respuesta del chat deja de poder afirmar que algo se guardó cuando no fue así.
- **Decisión de esquema:** una sola tabla `training.routines` con los items como `JSONB` (`[{exercise_id, name, sets, reps, rpe}]`) en vez de una tabla relacional aparte de items — no hay hoy necesidad de queries por item individual (mismo patrón ya usado en `training.exercises.instructions`/`image_urls`), y evita una segunda tabla + JOIN para un caso de uso simple (leer/escribir la rutina completa de una vez). RLS igual que el resto de tablas de usuario (F10): `auth.uid() = user_id`.
- **Decisión de persistencia:** `INSERT` **directo desde Flutter a Supabase** (`client.schema('training').from('routines').insert(...)`, mismo patrón exacto ya usado por `workout_sessions`/`food_logs`) — NO se toca el `ai_service`. RLS ya garantiza el aislamiento por usuario sin código de backend adicional.
- **Corrección de la alucinación (root cause, no un parche de prompt):** se elimina la llamada al LLM que generaba el `reply` de `/chat-plan` pidiéndole "resumir qué generaste" — ese resumen es lo que inventaba la confirmación de guardado. Se reemplaza por un texto determinista construido en código a partir de los flags de intención ya detectados (`wants_workout`/`wants_meal_plan`), que nunca puede afirmar una acción que no ocurrió porque no involucra al LLM en absoluto.
- **Criterios de Aceptación (AC):**
  - **AC1 (DB):** `training.routines` (`id`, `user_id` FK a `public.users.id` `ON DELETE CASCADE`, `name`, `source` `'ai'|'manual'`, `items` `JSONB NOT NULL`, `cardio_block` opcional, `created_at`) con RLS `auth.uid() = user_id`; `GRANT` a `authenticated` igual que las demás tablas de usuario de F10.
  - **AC2 (chat):** la tarjeta de rutina del chat tiene un botón "Guardar rutina" que pide un nombre y hace el `INSERT` real; tras guardar, confirma con un `SnackBar` (esto sí es una confirmación real, no una alucinación).
  - **AC3 (reply sin alucinación):** el campo `reply` de `/chat-plan` ya NO usa una llamada al LLM para resumir acciones — es texto determinista generado en código; nunca puede afirmar un guardado que no ocurrió.
  - **AC4 (Entrenamiento):** la pantalla de Entrenamiento lista las rutinas guardadas del usuario (vía `SELECT` a `training.routines`) junto a las 3 predefinidas; tocar una guardada inicia una sesión que prellena `sets`/`reps`/`rpe` objetivo por ejercicio (reutilizando `startWorkoutSession`/`addExerciseToActiveWorkout` ya existentes, en vez de un flujo nuevo paralelo).
  - **AC5 (docs):** ADR 12 en `architecture.md` (esquema `JSONB`, decisión de INSERT directo, corrección de la alucinación); `training.routines` documentada en `diseno_db.md`.
- **Estrategia de Pruebas (nivel Fase):**
  - **Tests Unitarios:** backend — `/chat-plan` devuelve un `reply` determinista (sin llamar a `ai_generate` para ese campo) y el conteo de llamadas al motor de IA baja en 1 respecto a antes; frontend — el guardado arma el `INSERT` con el `schema('training')` correcto y el shape de `items` esperado; la pantalla de Entrenamiento mezcla predefinidas + guardadas sin duplicar ids.
  - **Tests de Simulación de Usuario:** generar una rutina en el chat → pulsar "Guardar rutina" → nombrarla → verla en Entrenamiento → iniciarla y confirmar que los sets/reps ya vienen prellenados con los valores de la IA.
- **F13.SF1: Esquema de rutinas guardadas (DB)**
  - T13.1.1: `training.routines` (JSONB `items`) + RLS + GRANTs, siguiendo el patrón de F10.
- **F13.SF2: Guardado real desde el chat + fin de la alucinación**
  - T13.2.1: Botón "Guardar rutina" en la tarjeta del chat → `INSERT` directo a Supabase.
  - T13.2.2: `reply` de `/chat-plan` deja de depender del LLM — texto determinista en código.
- **F13.SF3: Rutinas guardadas en Entrenamiento**
  - T13.3.1: Listar rutinas guardadas junto a las predefinidas; iniciar una precarga sets/reps/rpe objetivo.
- **F13.SF4: Documentación**
  - T13.4.1: ADR 12 en `architecture.md` + `training.routines` en `diseno_db.md`.

### Fase 14: Recuperación de Contraseña (mailer local + flujo completo)
- **Macro-objetivo:** `AuthScreen` (F10) solo tiene login/signup, sin ningún flujo de recuperación (verificado por grep, cero resultados). El flujo real de GoTrue (`/auth/v1/recover`) envía un correo con un link de recuperación, pero el stack de dev no tiene ningún servidor SMTP — sin él, GoTrue fallaría al intentar enviar el correo. Esta Fase añade un mailer de pruebas local y el flujo completo de recuperación.
- **Entregable global:** un enlace "¿Olvidaste tu contraseña?" en el login que envía un correo real (capturado por un mailer de pruebas visible en una UI web), y una pantalla que completa el cambio de contraseña al abrir el link del correo.
- **Decisión de infraestructura:** **Mailpit** (no Mailhog, que está prácticamente sin mantenimiento desde 2020) como servidor SMTP de pruebas — expone SMTP en `:1025` y una UI web en `:8025` para ver los correos capturados, más una **API REST** (`GET /api/v1/messages`) que permite extraer el link de recuperación programáticamente para el E2E de esta Fase, sin depender de interacción manual con la UI.
- **Mecanismo de recuperación en Flutter (confirmado vía Context7, no asumido):** `auth.resetPasswordForEmail(email, redirectTo: ...)` dispara el correo; al abrir el link, `Supabase.initialize()` detecta el token de recuperación en la URL y GoTrue establece una sesión temporal, emitiendo `AuthChangeEvent.passwordRecovery` por `onAuthStateChange` — la app debe escuchar ese evento (con prioridad sobre el enrutamiento normal del `AuthGate`) y mostrar una pantalla de "nueva contraseña" que llama `auth.updateUser(UserAttributes(password: nueva))` (método y clase confirmados en la documentación real del SDK).
- **Criterios de Aceptación (AC):**
  - **AC1 (infra):** servicio `mailpit` en `docker-compose.yml` (SMTP `:1025`, UI web `:8025`); `GOTRUE_SMTP_*` configurado para apuntar a él; `GOTRUE_SITE_URL`/redirect ya apunta a `http://localhost:8080` (F10).
  - **AC2 (login):** enlace "¿Olvidaste tu contraseña?" en `AuthScreen` (modo login) → diálogo de email → `resetPasswordForEmail` → mensaje "revisa tu correo".
  - **AC3 (recuperación):** al abrir el link real (capturado por Mailpit), la app detecta `AuthChangeEvent.passwordRecovery` y muestra una pantalla de nueva contraseña → `updateUser` → confirmación → puede iniciar sesión con la contraseña nueva.
  - **AC4 (E2E real, sin mocks):** solicitar recuperación para un email de prueba real → confirmar que el correo aparece en la API de Mailpit (no simulado) → extraer el link real → completar el cambio → login con la contraseña nueva, todo verificado con comandos reales contra el stack.
  - **AC5 (docs):** ADR 13 en `architecture.md` (mailer local, decisión Mailpit sobre Mailhog, mecanismo de `passwordRecovery`). No toca `diseno_db.md` (`auth.users` ya existe, sin tablas nuevas).
- **Estrategia de Pruebas (nivel Fase):**
  - **Tests Unitarios:** frontend — el enlace/diálogo de recuperación arma la llamada correcta a `resetPasswordForEmail`; la pantalla de nueva contraseña llama `updateUser` con la contraseña ingresada y maneja errores sin explotar.
  - **Tests de Simulación de Usuario:** flujo E2E real descrito en AC4, de punta a punta contra el stack Docker vivo (Mailpit + GoTrue + gateway), sin mocks de correo.
- **F14.SF1: Mailer local (infra)**
  - T14.1.1: Servicio `mailpit` en `docker-compose.yml` + configuración `GOTRUE_SMTP_*`.
- **F14.SF2: Flujo de recuperación (frontend)**
  - T14.2.1: Enlace "¿Olvidaste tu contraseña?" + diálogo de email → `resetPasswordForEmail`.
  - T14.2.2: Detección de `AuthChangeEvent.passwordRecovery` + pantalla de nueva contraseña → `updateUser`.
- **F14.SF3: Verificación E2E real + Documentación**
  - T14.3.1: E2E real contra Mailpit (extraer el link del correo vía su API, completar el flujo, confirmar login con la contraseña nueva).
  - T14.3.2: ADR 13 en `architecture.md`.

### Fase 15: UI/UX del Entrenamiento en Vivo + Detalle de Ejercicio (imágenes + instrucciones)
- **Macro-objetivo:** Durante una rutina en curso (`ActiveWorkoutScreen`), las tarjetas de ejercicio solo muestran el nombre en texto plano — sin miniatura ni forma de ver cómo se ejecuta el ejercicio. **Hallazgo:** el popup de detalle (`_showExerciseDetail`) y la miniatura (`_ExerciseThumbnail`) YA EXISTEN en `active_workout_screen.dart`, pero solo están cableados a la hoja de "Agregar Ejercicio" — nunca a las tarjetas de la sesión en vivo. Esta Fase reutiliza ese código ya construido en el lugar donde realmente hace falta, y pule la experiencia visual del tracker en vivo.
- **Aclaración importante (no prometer algo que no existe):** el dataset `free-exercise-db` (F7) tiene **2 imágenes estáticas** por ejercicio (posición inicial/final en `image_urls[0]`/`[1]`), **no un GIF animado** — el popup de detalle ya solo muestra `imageUrls.first` (una sola imagen); esta Fase lo mejora a un carrusel/galería con AMBAS imágenes, que es la representación más fiel de "cómo se hace" disponible en los datos reales.
- **Entregable global:** en la sesión de entrenamiento en vivo, cada tarjeta de ejercicio muestra su miniatura y el nombre es tocable, abriendo el mismo popup de detalle (ahora con las 2 imágenes en carrusel) ya usado en "Agregar Ejercicio"; pulido visual de la tarjeta (indicador claro de ejercicio con todas las series completadas, mejor jerarquía visual de la tabla de series).
- **Criterios de Aceptación (AC):**
  - **AC1:** la tarjeta de ejercicio en `ActiveWorkoutScreen` muestra `_ExerciseThumbnail` (ya existente) junto al nombre.
  - **AC2:** tocar el nombre/miniatura abre `_showExerciseDetail` (ya existente, reusado, no reimplementado) — mismo popup que en "Agregar Ejercicio", ahora accesible también durante la sesión activa.
  - **AC3:** el popup de detalle muestra un carrusel/galería con TODAS las imágenes de `exercise.imageUrls` (hoy solo muestra la primera), con indicador de página si hay más de una.
  - **AC4:** pulido visual: la tarjeta de ejercicio indica claramente cuando todas sus series están completadas (p. ej. borde/ícono de check), y la tabla de series mantiene legibilidad (sin regresión de la edición inline de peso/reps/rpe ya existente).
  - **AC5:** cero regresión en el flujo de edición de sets/finalizar/cancelar entrenamiento ya existente.
- **Estrategia de Pruebas (nivel Fase):**
  - **Tests Unitarios:** widget test — la tarjeta de ejercicio en la sesión activa renderiza `_ExerciseThumbnail`; tocar el nombre invoca el mismo diálogo de detalle (verificable buscando el título del ejercicio duplicado en el árbol de widgets tras el tap, o refactorizando `_showExerciseDetail` a un método público/testeable si hace falta); el carrusel de imágenes muestra tantas páginas como `imageUrls.length`.
  - **Tests de Simulación de Usuario:** iniciar una rutina → tocar un ejercicio en la tarjeta activa → ver el popup con las 2 imágenes (deslizable) + instrucciones reales del catálogo → cerrar → seguir registrando series sin problema.
- **F15.SF1: Miniatura + detalle reusado en la tarjeta activa**
  - T15.1.1: `_ExerciseThumbnail` + tap-to-detail en la tarjeta de `ActiveWorkoutScreen` (reusa `_showExerciseDetail` existente).
- **F15.SF2: Carrusel de imágenes en el popup de detalle**
  - T15.2.1: `_showExerciseDetail` muestra todas las `imageUrls` en un carrusel deslizable con indicador de página, no solo la primera.
- **F15.SF3: Pulido visual de la tarjeta de ejercicio**
  - T15.3.1: Indicador visual de ejercicio 100% completado + revisión de jerarquía visual de la tabla de series.

### Fase 16: Planificación de Nutrición y Entrenamiento con Seguimiento de Adherencia
- **Macro-objetivo:** Hoy la app solo *registra* lo que pasó (comidas sueltas en el Diario, series ejecutadas en Entrenamiento). Esta Fase añade la capa de **planificación**: un plan de comidas por defecto y una rutina por defecto (F13 ya guarda rutinas, pero ninguna se puede marcar como "la de hoy"), y compara lo planificado contra lo real — tanto en el Diario (¿comí lo que tocaba?) como en el Dashboard (¿entrené lo que tocaba? ¿comí lo que tocaba?), sin recalcular el gasto calórico desde cero (`TrainingProvider.todayCaloriesBurned` ya estima calorías quemadas desde las sesiones completadas reales — F6 — y no se toca).
- **Entregable global:** el chat puede generar Y guardar planes de comida (mismo patrón que "Guardar rutina" de F13); una rutina y un plan de comida pueden marcarse como "predeterminados"; el Diario muestra, por tipo de comida, lo planificado junto a lo realmente registrado; el Dashboard tiene una sección "Plan de Hoy" (rutina default + ¿se hizo? / plan de comida default + calorías planificadas vs consumidas); escaneo de código de barras real por cámara como alternativa más rápida a la detección por IA.
- **Decisión de esquema:** `nutrition.meal_plans` — mismo patrón exacto que `training.routines` (F13): una sola tabla con los items (`meals`) en `JSONB`, RLS `auth.uid() = user_id`, sin tabla relacional aparte (no hay hoy necesidad de queries por comida individual). Se añade `is_default BOOLEAN DEFAULT FALSE` a AMBAS tablas (`training.routines` y `nutrition.meal_plans`), con un **índice único parcial** (`WHERE is_default`) por usuario en cada una — garantiza a nivel de DB que solo puede haber un default por usuario y tabla, no solo por convención de la app.
- **Decisión de escáner:** `mobile_scanner` (paquete activamente mantenido, usa la cámara nativa) reemplaza el diálogo mock (`_showBarcodeScannerMockDialog`, con códigos de prueba hardcodeados) como vía principal; se conserva la entrada manual de código como respaldo (dispositivos sin cámara, o pruebas), reusando `NutritionProvider.searchBarcode` ya existente (OpenFoodFacts) sin cambios.
- **Criterios de Aceptación (AC):**
  - **AC1 (esquema):** `nutrition.meal_plans` con RLS + índice único parcial de `is_default`; `training.routines` gana `is_default` + su propio índice único parcial. Migración segura sobre datos existentes (rutinas ya guardadas quedan con `is_default = false`).
  - **AC2 (guardar plan de comida):** la tarjeta de plan de comida del chat (`_buildMealPlanCard`) tiene un botón "Guardar plan" análogo a "Guardar rutina" (F13) → `INSERT` real a `nutrition.meal_plans`.
  - **AC3 (marcar predeterminado):** en "Mis Rutinas" (Entrenamiento) y en una nueva sección "Mis Planes de Comida" (Diario), cada ítem guardado tiene una acción para marcarlo como predeterminado; marcar uno desmarca automáticamente cualquier otro default previo del mismo usuario (a nivel de app Y protegido por el índice único parcial de DB).
  - **AC4 (comparación en el Diario):** por cada tipo de comida del día, si hay un plan de comida default, se muestra lo planificado (nombre/calorías/macros) junto a lo realmente registrado ese día para ese tipo de comida, con un delta visible (más/menos de lo planificado, o "no registrado aún").
  - **AC5 (Dashboard "Plan de Hoy"):** sección nueva con (a) la rutina default (nombre + si ya hay una sesión completada hoy) y (b) el plan de comida default (calorías totales planificadas vs `NutritionProvider.totalCalories` ya calculado). No se toca `todayCaloriesBurned` (F6, ya correcto).
  - **AC6 (escáner real):** botón de escanear código de barras abre la cámara real (`mobile_scanner`), decodifica, y sigue el mismo flujo ya existente de `searchBarcode` → mostrar resultado → confirmar → `addFoodLog`; la entrada manual sigue disponible como respaldo.
  - **AC7 (docs):** ADR 14 en `architecture.md`; `nutrition.meal_plans` + columnas `is_default` documentadas en `diseno_db.md`.
- **Estrategia de Pruebas (nivel Fase):**
  - **Tests Unitarios:** RLS de `meal_plans` con JWT reales (mismo patrón que `training.routines`, F13); provider tests — marcar un plan/rutina como default desmarca cualquier otro; la comparación planificado-vs-real calcula el delta correctamente para varios casos (sin registro, exacto, de más, de menos); el escáner decodifica un código y dispara `searchBarcode` con el valor correcto (mockeado, sin cámara real en CI).
  - **Tests de Simulación de Usuario:** generar y guardar un plan de comida desde el chat → marcarlo predeterminado → en el Diario ver la comparación planificado-vs-real de ese día; marcar una rutina guardada como predeterminada → verla reflejada en el Dashboard; escanear un código de barras real con la cámara → ver el producto → confirmar → aparece en el Diario.
- **F16.SF1: Esquema (DB)**
  - T16.1.1: `nutrition.meal_plans` (JSONB) + RLS + `is_default` en `meal_plans` y `training.routines`, con índices únicos parciales.
- **F16.SF2: Guardar y marcar predeterminado**
  - T16.2.1: Botón "Guardar plan" en la tarjeta de plan de comida del chat.
  - T16.2.2: Marcar/desmarcar predeterminado en "Mis Rutinas" y en la nueva sección "Mis Planes de Comida" del Diario.
- **F16.SF3: Comparación planificado vs real (Diario)**
  - T16.3.1: Por tipo de comida, mostrar lo planificado (del plan default) junto a lo real, con delta.
- **F16.SF4: Escáner de código de barras real**
  - T16.4.1: `mobile_scanner` reemplaza el diálogo mock como vía principal; entrada manual como respaldo.
- **F16.SF5: Dashboard "Plan de Hoy"**
  - T16.5.1: Sección con rutina default (¿hecha hoy?) y plan de comida default (planificado vs consumido).
- **F16.SF6: Documentación**
  - T16.6.1: ADR 14 en `architecture.md` + `nutrition.meal_plans`/`is_default` en `diseno_db.md`.

### Fase 17: Cardio con METs + Búsqueda de Ejercicios por Músculo + Catálogo de Comida Peruana
- **Macro-objetivo:** Tres mejoras sobre datos: (1) el cardio (correr/caminar/bici) SÍ existe en el catálogo pero su gasto calórico es plano (6 cal/min) — se calcula por METs según ritmo real usando el peso del usuario; (2) el "Agregar ejercicio" es una lista plana de 873 ítems sin buscador — se añade búsqueda por nombre y filtro por músculo (los datos `body_part`/`secondary_muscles` ya existen); (3) no hay dataset de comida — se añade un catálogo curado de platos peruanos (híbrido con el OpenFoodFacts ya integrado).
- **Entregable global:** al registrar cardio se ingresa tiempo+distancia y el gasto calórico varía por ritmo; el "Agregar ejercicio" tiene buscador + filtro por músculo con tags; el Diario permite buscar platos peruanos de un catálogo curado además de las vías ya existentes.
- **Decisiones de esquema/diseño:** `public.users.weight_kg` (el onboarding ya captura el peso pero lo descarta — se persiste, necesario para METs); `training.workout_sets` gana columnas nullable `duration_min`/`distance_km` (para cardio; fuerza las deja NULL); `nutrition.food_catalog` (catálogo curado de platos peruanos, lectura pública, mismo patrón que `training.exercises`). MET por fórmula estándar del Compendium (kcal = MET × peso_kg × horas; MET del cardio derivado del ritmo distancia/tiempo). Los macros del seed peruano son estimaciones documentadas como tales.
- **Criterios de Aceptación (AC):**
  - **AC1 (DB):** `public.users.weight_kg` (nullable, REAL); `training.workout_sets.duration_min`/`distance_km` (nullable); `nutrition.food_catalog` (id, name, calories, protein_g, carbs_g, fat_g, serving_size_g, category) poblada por seed con ≥40 platos peruanos, lectura pública (`GRANT SELECT` a anon/authenticated).
  - **AC2 (peso persistido):** el onboarding guarda `weight_kg` en `public.users`; el perfil lo lee.
  - **AC3 (cardio input):** en `ActiveWorkoutScreen`, un ejercicio `category='cardio'` muestra campos tiempo (min) + distancia (km) en vez de peso/reps; se persisten en `workout_sets`.
  - **AC4 (gasto por METs):** `todayCaloriesBurned` se calcula por METs con el peso real; el cardio usa el ritmo (distancia/tiempo → MET), de modo que correr rápido/más tiempo da más kcal que caminar poco; la fuerza mantiene su estimación por duración. Verificable: dos sesiones de cardio con distinto ritmo dan kcal distintas.
  - **AC5 (búsqueda ejercicios):** la hoja "Agregar ejercicio" tiene un box de búsqueda por nombre y un filtro por músculo (`body_part` + `secondary_muscles` como tags); filtra sobre `provider.exercises` ya cargado, sin tocar DB.
  - **AC6 (catálogo comida):** al agregar comida en el Diario, un buscador contra `nutrition.food_catalog` prellena nombre+macros → `addFoodLog`; convive con las vías ya existentes (manual, cámara IA, escáner de barras).
  - **AC7 (docs):** ADR 15 en `architecture.md`; `weight_kg`/`workout_sets` cardio cols/`food_catalog` en `diseno_db.md`.
- **Estrategia de Pruebas (nivel Fase):**
  - **Tests Unitarios:** cálculo MET (varios ritmos → kcal correctas por fórmula; fuerza sin cardio usa la estimación por duración); RLS/GRANT del catálogo de comida (lectura pública, con JWT reales extendiendo `test_auth_rls_e2e.sh`); filtro de ejercicios por nombre/músculo (dado un query, devuelve el subconjunto correcto); búsqueda de comida puebla el borrador con los macros del catálogo.
  - **Tests de Simulación de Usuario:** registrar "Running, Treadmill" 30 min / 5 km → ver kcal quemadas coherentes (y distintas a 20 min / 2 km); buscar "press" en Agregar ejercicio → aparece solo lo que matchea; filtrar por "chest" → solo pecho; en el Diario buscar "arroz con pollo" → prellena macros → guardar.
- **F17.SF1: Esquema (DB)**
  - T17.1.1: `public.users.weight_kg` + `training.workout_sets.duration_min`/`distance_km` (nullable).
  - T17.1.2: `nutrition.food_catalog` + seed curado de platos peruanos (≥40), lectura pública.
- **F17.SF2: Cardio con METs**
  - T17.2.1: Persistir `weight_kg` en el onboarding/perfil.
  - T17.2.2: Input de tiempo+distancia para cardio en `ActiveWorkoutScreen`; cálculo de `todayCaloriesBurned` por METs (cardio por ritmo, fuerza por duración).
- **F17.SF3: Búsqueda y filtro de ejercicios por músculo**
  - T17.3.1: Box de búsqueda por nombre + filtro por músculo (tags) en la hoja "Agregar ejercicio".
- **F17.SF4: Catálogo de comida en el Diario**
  - T17.4.1: Buscador contra `nutrition.food_catalog` al agregar comida → prellena → `addFoodLog`.
- **F17.SF5: Documentación**
  - T17.5.1: ADR 15 en `architecture.md` + esquema nuevo en `diseno_db.md`.

### Fase 18: Chat Nutricionista/Entrenador — Contexto, Planes Multi-Semana, Preferencias, Micronutrientes y Alternativas
- **Macro-objetivo:** Convertir el chat de un generador de planes de un solo turno/un solo día en un asistente tipo nutricionista/entrenador: recuerda la conversación, genera planes de mínimo una semana que varían por día, repregunta cuando la petición es ambigua, respeta preferencias/restricciones del usuario (alergias, disgustos, sin refri/utensilio, ingredientes difíciles), muestra micronutrientes reales y ofrece alternativas.
- **Decisión de alcance:** el usuario pidió explícitamente hacerlo TODO en una sola Fase F18 (grande). Se construye por sub-fases secuenciadas, empezando por el contexto conversacional (desbloquea repreguntas y multi-turno). Los micronutrientes usan **datos reales** (tabla peruana de composición de alimentos INS/CENAN); si la fuente oficial completa no se consigue en formato usable, el fallback documentado es un subconjunto de micros clave para los platos ya en `food_catalog`, marcado como parcial — **nunca micros inventados presentados como reales**.
- **Criterios de Aceptación (AC):**
  - **AC1 (contexto):** `/chat-plan` recibe el historial de la conversación y lo usa; tras hablar de comidas, "hazlo a 3 semanas" genera un plan de COMIDA (no una rutina). El chat sigue stateless en el servidor (historial por request).
  - **AC2 (multi-día):** `meal_plans`/`routines` soportan estructura por día (JSONB `days`); el orquestador genera planes de ≥7 días que varían (músculos distintos por día en entrenamiento, comidas distintas por día); la UI muestra/navega los días; los planes de 1 día previos (F13/F16) siguen leyéndose (compatibilidad hacia atrás).
  - **AC3 (repreguntar):** ante una petición ambigua, el chat devuelve una pregunta de clarificación (equipo, días, alergias…) en vez de un plan a medias; con el historial, el siguiente turno genera.
  - **AC4 (preferencias):** tabla `nutrition.food_preferences` (RLS por usuario) con alergias / no-le-gusta / evitar / incluir-poco / restricciones (sin refri, utensilios); UI para editarlas; se inyectan al prompt del generador de comida y este las respeta.
  - **AC5 (micronutrientes):** `food_catalog` (o tabla asociada) extendida con micronutrientes reales de la fuente peruana; se muestran en la UI de comida/planes; documentado el origen y si es parcial.
  - **AC6 (alternativas):** el generador ofrece sustituciones cuando el usuario declara una restricción (sin refri/utensilio/ingrediente difícil); en el chat se puede pedir "dame una alternativa a X".
  - **AC7 (docs):** ADR 16 en `architecture.md`; esquema (planes multi-día, `food_preferences`, micros) en `diseno_db.md`.
- **Estrategia de Pruebas (nivel Fase):**
  - **Tests Unitarios:** `_extract_intent`/orquestador con historial mockeado resuelve la referencia ("3 semanas" → comida); detección de ambigüedad → pregunta; RLS de `food_preferences` con JWT reales; parser de planes multi-día (N días, variación); micros parseados desde la fuente; inyección de preferencias/restricciones al prompt (el prompt contiene las alergias/restricciones).
  - **Tests de Simulación de Usuario:** conversación real (Ollama): pedir plan de comida → "hazlo a 3 semanas" → recibir plan de comida de 3 semanas variado; petición ambigua → el chat repregunta; declarar alergia → el plan la respeta; ver micros de un plato; pedir alternativa sin refri.
- **F18.SF1: Memoria de conversación (contexto)**
  - T18.1.1: `AiProvider.sendMessage` envía el historial; `/chat-plan` + `_extract_intent` lo reciben y usan para resolver intención/referencia.
- **F18.SF2: Preferencias y restricciones de nutrición**
  - T18.2.1: Tabla `nutrition.food_preferences` (RLS) + provider/CRUD.
  - T18.2.2: UI para editar preferencias (alergias, disgustos, evitar, incluir-poco, sin refri/utensilios) + inyección al prompt de generación de comida.
- **F18.SF3: Repreguntar cuando es ambiguo**
  - T18.3.1: Detección de ambigüedad en el orquestador → pregunta de clarificación en vez de plan; con historial (SF1), el siguiente turno genera.
- **F18.SF4: Planes multi-día / multi-semana variados**
  - T18.4.1: Esquema JSONB `days` en `meal_plans`/`routines` (compat. hacia atrás con 1 día) + generación multi-día variada en el orquestador.
  - T18.4.2: UI para mostrar/navegar los días (tarjetas del chat, "Mis Rutinas"/"Mis Planes", Dashboard).
- **F18.SF5: Micronutrientes con datos reales**
  - T18.5.1: Sourcing de la tabla peruana (INS/CENAN) + extender `food_catalog` con micros (o tabla asociada) + poblarla (fallback parcial documentado si la fuente completa no se consigue).
  - T18.5.2: UI de micronutrientes en comida/planes.
- **F18.SF6: Alternativas por restricciones**
  - T18.6.1: Inyección de restricciones al prompt + mecanismo de "dame una alternativa a X" en el chat.
- **F18.SF8: Catálogo por ingredientes + platos componibles**
  - Modelo de comida a nivel ingrediente (macros por 100g/ml) y platos compuestos de ingredientes con cantidades, para poder añadir/quitar/cambiar porciones. **Debe ir ANTES de SF18.5** (los micros se cuelgan del ingrediente, no del plato). Requiere `docker compose down -v`.
  - T18.8.1: Tabla `nutrition.ingredients` (macros por 100 g/ml) + seed de ingredientes base peruanos (lectura pública, como `food_catalog`).
  - T18.8.2: Composición de platos: `food_catalog` gana `ingredients` JSONB `[{ingredient_id, grams|ml}]`; helper que recalcula macros del plato desde sus ingredientes; compat. con platos sin composición (macros planas actuales).
  - T18.8.3: UI — al elegir un plato, expandir sus ingredientes; añadir/quitar/cambiar porción; recálculo en vivo de macros; opción de registrar el plato completo o ingrediente a ingrediente.
- **F18.SF7: Documentación**
  - T18.7.1: ADR 16 en `architecture.md` + esquema nuevo en `diseno_db.md` (incluye `ingredients` + composición de `food_catalog`).
