# Arquitectura del Sistema: Nutri-Fit Modular

Este documento detalla la separación arquitectónica de servicios y esquemas de base de datos para Nutri-Fit.

---

## 1. Modularización del Backend

El backend se divide en componentes independientes para garantizar que la transición a microservicios en la nube (ej. AWS ECS/Lambda y RDS) sea transparente y no requiera refactorizar la app.

```mermaid
graph TB
    subgraph Cliente Flutter (Mobile / Web)
        UI[Pantallas de UI]
        State[Controlador de Estado - Bloc/Provider]
    end

    subgraph Backend Modular (Supabase Stack)
        AuthService[Supabase Auth Service]
        
        subgraph PostgreSQL Engine
            PublicSchema[Schema 'public': Usuarios, Onboarding]
            NutritionSchema[Schema 'nutrition': Comidas, Planes, OFF Caché]
            TrainingSchema[Schema 'training': Sesiones, Ejercicios, Series]
        end
    end

    subgraph Microservicio AI (Contenedor Python FastAPI)
        APIGateway[FastAPI Endpoints]
        VisionEngine[Ollama / Vision API Handler]
    end

    UI -->|Acción del usuario| State
    State -->|JWT Auth| AuthService
    State -->|SQL CRUD / Realtime| PostgreSQLEngine
    State -->|REST Image Post| APIGateway
    APIGateway -->|Inferencia| VisionEngine
    APIGateway -->|Guardar metadatos| PostgreSQLEngine
```

---

## 2. Mapa de Flujos de Clics y Side-Effects en la Base de Datos

### Flujo A: Crear Cuenta y Onboarding
1. **User Action:** Clic en "Registrar" tras rellenar el cuestionario.
2. **Frontend Logic:** Valida edad, peso, altura y actividad; calcula localmente las calorías sugeridas.
3. **Backend Side-Effects:**
   - Supabase crea la sesión de autenticación (`auth.users`).
   - Inserta datos personales en `public.users`.
   - Inserta metas calóricas y macros calculados en `nutrition.user_goals`.

### Flujo B: Registro de Alimentos por Foto
1. **User Action:** Clic en el botón de cámara ("Tomar foto con IA") en el Diario nutricional.
2. **Frontend Logic:** Captura/elige la imagen con `image_picker` y la sube **directamente por multipart** al `ai_service` (sin pasar por Supabase Storage), adjuntando la `AIConfig` guardada en secure storage (ver ADR 8).
3. **Backend Side-Effects:**
   - La app hace un `POST` multipart a `/analyze-meal` con el archivo de imagen (campo `file`) y la config (`ai`).
   - FastAPI enruta a `generate_vision` según el proveedor; si no hay config o falla, cae a Ollama local (`llava`) y por último a un mock estructurado.
   - El frontend muestra el borrador editable. Si el usuario hace clic en "Guardar", se ejecuta un `INSERT` en `nutrition.food_logs`.

### Flujo D: Escaneo de Máquina de Gimnasio por Foto
1. **User Action:** Clic en el botón de cámara ("Escanear máquina con IA") en Entrenamiento.
2. **Frontend Logic:** Captura/elige la imagen con `image_picker` y la sube por multipart al `ai_service` con la `AIConfig` (misma mecánica que el Flujo B).
3. **Backend Side-Effects:**
   - `POST` multipart a `/identify-machine` (campo `file` + `ai`) → `generate_vision` → ficha JSON.
   - **Sin escritura en DB:** el resultado (máquina, músculos, ejercicios sugeridos, tips) se muestra en una ficha informativa; no persiste nada.

### Flujo C: Ejecución y Completado de Rutina (Tracker en Vivo)
1. **User Action:** Clic en "Empezar Entrenamiento" -> Iniciar serie de Press de Banca.
2. **Frontend Logic:** Inicializa cronómetro local e inicia una sesión de ejercicio interactiva.
3. **Backend Side-Effects:**
   - En el inicio: `INSERT` en `training.workout_sessions` (`ended_at = NULL`).
   - Al marcar cada serie como completada: `UPSERT` en `training.workout_sets` con el estado (`completed = true`, peso, repeticiones).
   - Al dar clic en "Finalizar": `UPDATE` en `training.workout_sessions` estableciendo `ended_at = NOW()`.
   - El backend corre un trigger que calcula las calorías aproximadas quemadas en el entrenamiento y actualiza el total calórico diario del usuario en `nutrition.daily_summaries`.

---

## 3. Decisiones de Arquitectura (ADRs)

### ADR 4: Separación por esquemas en PostgreSQL (`public`, `nutrition`, `training`)
- **Contexto:** Mantener todas las tablas en el esquema `public` acopla fuertemente el sistema, dificultando separar las bases de datos en microservicios reales en el futuro.
- **Decisión:** Agrupar las tablas en esquemas separados (`nutrition` para base alimenticia y `training` para LiftLog).
- **Justificación:** Permite aplicar políticas RLS (Row Level Security) específicas para cada módulo y facilita la migración a bases de datos independientes en AWS (ej. dos instancias de RDS separadas) si el tráfico aumenta.

### ADR 5: Portabilidad de Base de Datos y Postgres Estándar
- **Contexto:** Aunque usamos Supabase para el MVP y el entorno local, se requiere que la base de datos sea compatible con cualquier servicio de nube (AWS RDS, GCP Cloud SQL, Azure Database for PostgreSQL).
- **Decisión:** Programar todas las consultas, tablas y esquemas usando estándares de PostgreSQL ANSI/ISO puro, evitando depender de extensiones propietarias o funciones de Supabase no estándares.
- **Justificación:** Garantiza la facilidad de migración o réplica de la base de datos relacional de Supabase a cualquier otro gestor administrado en la nube comercial (usando herramientas como `pg_dump` y `pg_restore`).

### ADR 6: Catálogo de ejercicios desde `free-exercise-db` (dominio público)
- **Contexto:** El módulo `training` necesita un catálogo amplio de ejercicios con imágenes de referencia. Se evaluó `hasaneyldrm/exercises-dataset` (1.324 ejercicios con GIFs), pero sus medios son **© Gym Visual** y **no son redistribuibles ni de uso comercial** sin una licencia propia, lo que choca con el carácter open-source de Nutri-Fit.
- **Decisión:** Adoptar **`yuhonas/free-exercise-db`** (licencia **Unlicense** / dominio público, 800+ ejercicios con imágenes estáticas). Los datos se cargan en `training.exercises` mediante un seed SQL (`docker/postgres/zz_exercises_seed.sql`) generado a partir de `exercises.json`, ejecutado en el init de Postgres tras `z_init.sql`.
- **Justificación:** La Unlicense permite uso comercial y redistribución sin atribución obligatoria, eliminando el riesgo legal. Las imágenes se referencian por URL al raw de GitHub en el MVP (vendorizado a Storage queda como mejora futura). Las instrucciones vienen en inglés; su traducción a español queda como tarea pendiente.
- **Trazabilidad:** `id` se mantiene como `INTEGER` surrogate para no romper el FK `training.workout_sets.exercise_id`; el slug original del dataset se conserva en `training.exercises.external_id`.

### ADR 7: Capa de IA multi-proveedor en el microservicio (F8)
- **Contexto:** El chatbot debe poder usar cualquiera de OpenAI, OpenRouter, Google Gemini, Claude, Ollama, LM Studio o vLLM, y el usuario debe poder introducir su propia API key y config desde la app — sin hardcodear secretos ni acoplar los endpoints a un proveedor.
- **Decisión:** El `ai_service` (FastAPI) expone una **capa de IA multi-proveedor** (`backend/app/ai_engine.py`) con dos ramas por protocolo: **(a)** un único cliente `openai` con `base_url` configurable cubre los 6 proveedores OpenAI-compatible (OpenAI, OpenRouter, Gemini vía su endpoint OpenAI-compat, LM Studio, vLLM, Ollama vía `/v1`); **(b)** el SDK nativo `anthropic` cubre Claude (modelo por defecto `claude-opus-4-8`). Los 4 endpoints (`/chat`, `/generate-meal-plan`, `/generate-workout-plan`, `/analyze-progress`) reciben la config (`AIConfig{provider, api_key?, base_url?, model}`) **por request**.
- **Justificación:** El protocolo OpenAI-compatible es el mínimo común denominador de casi todos los servidores de LLM, así que una sola abstracción cubre 6 de 7 proveedores; cambiar de proveedor es solo cambiar la config, no el código. Claude usa su SDK nativo por fidelidad de la API.
- **Seguridad / estado:** El servicio es **stateless** — no persiste claves ni historial. La app Flutter guarda la config en `flutter_secure_storage` y la envía por request; el historial de chat vive en el cliente (MVP). Un request sin config válida devuelve **503** con detalle, nunca un crash.
- **Flujo del chatbot:** `Ajustes de IA` (elige proveedor + clave) → guarda en secure storage → `Chat`/botones de generación → `POST` al endpoint con la `AIConfig` → `ai_engine` enruta al proveedor → respuesta. Para rutinas, el backend consulta `training.exercises` y pasa candidatos reales al modelo, descartando `exercise_id` alucinados.

### ADR 8: Visión multi-proveedor (imagen → JSON) en el microservicio (F9)
- **Contexto:** El Diario nutricional necesita estimar comida desde una foto y Entrenamiento identificar una máquina desde una foto. Los endpoints `/analyze-meal` y `/identify-machine` ya existían en el backend pero el cliente Flutter nunca los llamaba (hallazgo B1 de la auditoría).
- **Decisión:** Se extiende `ai_engine.py` con `generate_vision(cfg, prompt, image_b64, want_json)`, reusando las dos ramas de la capa multi-proveedor: **(a)** OpenAI-compatible envía la imagen como content block `image_url` con `data:image/jpeg;base64,…` (cubre OpenAI/Gemini/OpenRouter/LM Studio/vLLM/Ollama con modelo multimodal); **(b)** Anthropic usa el bloque `image` con `source` base64. Ambos endpoints aceptan una `AIConfig` **opcional** por multipart (campo `ai`): si viene, se usa `generate_vision`; si falla o no viene, se mantiene el fallback existente (Ollama local → **mock** determinista), así el flujo se valida siempre.
- **Frontend:** dep `image_picker`; `VisionService` sube la foto por multipart y adjunta la `AIConfig` guardada en secure storage (F8). En el Diario, botón cámara → `/analyze-meal` → borrador editable (tipo de comida + macros) → `INSERT` en `nutrition.food_logs`. En Entrenamiento, botón cámara → `/identify-machine` → ficha (máquina, músculos, ejercicios sugeridos, tips).
- **Estado / seguridad:** stateless igual que el chat — la imagen se procesa en memoria y no se persiste; la clave viaja por request y no se guarda en el servidor. No toca `diseno_db.md` (`food_logs` ya existía).
- **Verificación E2E:** validado contra el Ollama del host con `gemma4:e4b` (capacidad `vision`): `/identify-machine` devolvió ficha estructurada real (~7.6s) y `/analyze-meal` clasificó correctamente una imagen sin comida (food_items=[], 0 kcal) — respuestas reales del modelo, no el mock.

### ADR 9: Autenticación real con GoTrue + Row-Level Security (F10)
- **Contexto:** Desde F1 la app operaba con un bypass de auth (`AppConstants.devUserId`, un UUID fijo compartido por todos) porque el stack no tenía servicio de autenticación. Esto impedía multiusuario real: cualquier sesión leía/escribía las mismas filas (INC-003, INC-006).
- **Decisión:** Se añade **GoTrue** (`supabase/gotrue:v2.151.0`) como servicio (`nutri-fit-auth`) contra el mismo Postgres, que ya trae el esquema `auth` completo (roles `anon`/`authenticated`/`service_role`/`authenticator`, tabla `auth.users`, función `auth.uid()`) por venir de la imagen `supabase/postgres`. El gateway nginx enruta `/auth/v1/` → GoTrue igual que `/rest/v1/` → PostgREST, mismo origen (`:54321`) y mismo tratamiento CORS que evitó INC-001. GoTrue firma los JWT con el mismo `JWT_SECRET` que ya validaba PostgREST, así que el flujo de auth es transparente al resto del stack: PostgREST hace `SET ROLE <claim role>` por request (típicamente `authenticated`), y bajo ese rol (sin `BYPASSRLS`) las políticas de Row-Level Security aplican de verdad, aunque la conexión de PostgREST a Postgres use el superusuario `postgres` como login role.
- **Esquema y RLS:** se re-instaura la FK `public.users.id → auth.users(id) ON DELETE CASCADE` (se había quitado en `4a46f51` para el bypass). **Sin trigger de auto-provisión**: `public.users` tiene columnas obligatorias (`name`, `birth_date`, `gender`, `height_cm`) que GoTrue no conoce en el signup, así que el Onboarding de Flutter sigue siendo el único punto que crea la fila de perfil completa, ahora con el id real del usuario autenticado. RLS (`auth.uid() = user_id`) protege `public.users`, `nutrition.user_goals`, `nutrition.food_logs`, `training.workout_sessions` y `training.workout_sets` (esta última por subquery a la sesión dueña, al no tener `user_id` propio); `training.exercises` y `nutrition.food_cache` quedan sin RLS por ser catálogos/caché compartidos sin dueño. Detalle de tablas y políticas en `diseno_db.md` §3.
- **Frontend:** `AuthScreen` (login/signup con validación local) + `AuthGate` (`StreamBuilder` sobre `auth.onAuthStateChange`) deciden la raíz de navegación: sin sesión → login; con sesión → `InitialCheckScreen` (Onboarding vs Dashboard, sin cambios en esa lógica). Logout desde el Dashboard. **`AppConstants.devUserId` fue eliminado por completo**: todos los providers (`onboarding`, `nutrition`, `training`) y `main.dart` usan `Supabase.instance.client.auth.currentUser!.id` — ya no hay fallback a un id fijo, porque el `AuthGate` garantiza que ese código solo corre con sesión activa.
- **Verificación:** E2E de aislamiento cross-usuario con JWT reales de GoTrue (`tests/e2e/test_auth_rls_e2e.sh`, 6/6 PASS) — el usuario B no ve filas de A en `users`/`food_logs`; el catálogo de ejercicios sigue accesible sin sesión. 26/26 tests de Flutter en verde tras retirar `devUserId`.
- **Deuda conocida (INC-010):** el rol `supabase_auth_admin` (usado por GoTrue para migrar/conectar) es un rol protegido de la imagen `supabase/postgres`; su contraseña debe re-aplicarse a mano tras cada `docker compose down -v` porque el mecanismo declarativo intentado (script en `docker-entrypoint-initdb.d`) no funciona en la fase de bootstrap (el servidor temporal de ese momento no escucha por TCP). Documentado en `docs/logs/log.md`.

### ADR 10: Orquestador de chat + generación de rutinas/planes de comida, FAB global (F11)
- **Contexto:** F8 dejó el chatbot con 3 endpoints separados (`/chat`, `/generate-workout-plan`, `/generate-meal-plan`) que la UI nunca combinaba, y el chat solo era alcanzable navegando a la ruta `/chat`. El objetivo de F11 es que una sola consulta en lenguaje natural (p. ej. *"solo tengo una caminadora y una pesa rusa de 10kg, para bajar de peso, y necesito un plan de desayuno/almuerzo/cena"*) dispare AMBOS resultados en un mismo turno, accesible desde cualquier pantalla principal.
- **Decisión de arquitectura (3 opciones evaluadas):** **(a)** tool-calling del proveedor activo hacia los 2 endpoints, **(b)** un endpoint orquestador nuevo en el `ai_service` que detecta intención y llama internamente a la misma lógica, **(c)** parseo de la respuesta del chat en el frontend para disparar llamadas. Se eligió **(b)**. Razón: tool-calling no es uniforme entre los 7 proveedores soportados (F8) — modelos locales vía Ollama/LM Studio no siempre implementan function-calling de forma confiable, y mantenerlo consistente entre OpenAI/Claude/Gemini/OpenRouter/vLLM añadiría una rama de código por proveedor. Parsear texto libre en el frontend (c) es frágil ante cualquier cambio de redacción del modelo. El orquestador (b) reusa el mismo patrón `want_json=True` ya probado en F8/F9: una llamada de **extracción de intención** (JSON plano, no tool-calling) seguida de la MISMA lógica que ya usan `/generate-workout-plan`/`/generate-meal-plan`, ahora extraída a funciones internas reusables (`_build_workout_plan`, `_build_meal_plan`) para no duplicar prompts ni el filtro anti-alucinación de `exercise_id`.
- **Endpoint:** `POST /chat-plan` recibe `{message, profile?, ai}`; `_extract_intent` detecta `wants_workout`/`wants_meal_plan`/`equipment`/`goal`/`preferences`; según lo detectado, invoca condicionalmente `_build_workout_plan`/`_build_meal_plan` y devuelve `{reply, workout, meal_plan}` (cualquiera de los dos últimos puede ser `null`). Si `_build_workout_plan` no encuentra candidatos en el catálogo para el equipamiento detectado, `chat_plan` degrada a una rutina vacía en vez de tumbar todo el endpoint — el `meal_plan` puede seguir generándose igual.
- **Restricción real del catálogo (verificada):** `training.exercises` tiene 53 filas con `equipment='kettlebells'` y **0** con equipment de treadmill/caminadora (el dataset `free-exercise-db` es de fuerza, no tiene cardio de máquina). Cuando el usuario menciona equipamiento de cardio sin cobertura en el catálogo, la rutina incluye un campo `cardio_block` (texto libre, p. ej. "20-30 min en caminadora a ritmo moderado, 6-8 km/h") construido localmente sin llamada extra al LLM — nunca un `exercise_id` inventado.
- **Frontend:** `ChatFab` (widget reusable) en Dashboard/Diario/Entrenamiento abre `ChatScreen(embedded: true)` en un `showModalBottomSheet`, conservando el contexto de la pantalla de origen (no es una navegación de página completa). `ChatScreen(embedded: false)` (ruta `/chat`) se mantiene idéntica a como estaba en F8. `AiProvider.sendMessage` ahora llama `/chat-plan`; `ChatMessage` lleva `workout`/`meal_plan` opcionales, y el chat renderiza tarjetas "Rutina sugerida" y "Plan de comidas" embebidas en la burbuja del asistente cuando esos campos vienen no-nulos.
- **Verificación:** caso de prueba obligatorio validado contra Ollama real (`gemma4:e4b`, vía `host.docker.internal:11434/v1`) con la consulta exacta del enunciado — `workout.items` con ejercicios reales de `kettlebells` (verificados contra `training.exercises`) + `cardio_block` mencionando la caminadora, y `meal_plan.meals` con las comidas del día, ambos no-nulos en la misma respuesta. 30/30 tests de backend y 30/30 de Flutter en verde, sin regresión en `/generate-workout-plan`/`/generate-meal-plan` originales (mismo contrato HTTP).

### ADR 11: Gestión de modelos Ollama — listar/instalar vía backend (F12)

- **Contexto:** El modelo sugerido por defecto para el proveedor `ollama` (`kSuggestedModel['ollama']='llama3.1'`) casi nunca coincide con lo que el usuario tiene realmente instalado, y el campo de modelo en Ajustes de IA era texto libre — el usuario descubría el desajuste solo cuando el chat fallaba con un 404/503 (`model 'llama3.1' not found`).
- **Hallazgo de infraestructura (causa raíz adicional, no solo el default equivocado):** `docker-compose.yml` (desde F1) tenía un servicio `ollama` (imagen `ollama/ollama:latest`) publicando el puerto **11434 del host** — el mismo puerto en el que ya escucha el Ollama nativo de Windows del usuario, el que de verdad tiene los modelos instalados (`gemma4:e4b`, `gemma4:26b`, `qwen2.5:3b`, `llama3.2:latest`, etc.). Dos procesos compitiendo por el mismo puerto del host hacía impredecible cuál respondía a `curl localhost:11434`. Además, `OLLAMA_HOST` (en `ai_engine.py` y, con un bug adicional, en `main.py` con default `http://localhost:11434`) apuntaba al servicio docker interno o a un `localhost` inalcanzable desde dentro de un contenedor — nunca al Ollama real. Se removió el servicio `ollama` del compose (nada más lo referenciaba) y se corrigió el default a `http://host.docker.internal:11434` en ambos archivos.
- **Decisión de arquitectura:** listar/instalar modelos pasa por el **backend** (`ai_service`), no por el navegador directo a Ollama. Aunque Ollama respondió con CORS abierto en una prueba manual, depender de la configuración de CORS de un proceso externo que la app no controla es frágil; el backend ya tiene `CORSMiddleware` abierto y es el mismo patrón ya usado para todo lo demás (F8/F9/F11).
- **Endpoints:** `GET /ollama/models?base_url=...` deriva el host nativo de Ollama (recortando el sufijo `/v1` si el `base_url` viene en modo OpenAI-compatible) y consulta `/api/tags` nativo, devolviendo `{name, size}` por modelo; 503 claro si Ollama no responde. `POST /ollama/pull {model, base_url}` dispara la descarga en background (`BackgroundTasks`, no bloquea el request) contra `/api/pull` nativo (streaming NDJSON), actualizando un diccionario en memoria (MVP — se pierde en un restart/multi-worker); `GET /ollama/pull-status?model=...` expone el progreso hasta `done: true`.
- **Frontend:** en Ajustes de IA, al elegir proveedor `ollama` (o cambiar la URL base), se consulta `/ollama/models`; si responde con modelos, el campo "Modelo" pasa a ser un desplegable poblado con los nombres reales (el valor persistido se inserta como primer ítem si no está en la lista, para no perder la selección al abrir la pantalla); si la consulta falla, se conserva el campo de texto libre de siempre — el flujo de configurar otros proveedores nunca se bloquea. Una sección "Modelos recomendados" (lista curada multi-propósito: `gemma4:e4b`, `llama3.2:3b`, `qwen2.5:3b`) muestra un check en los ya instalados (comparación tolerante a tags, p. ej. `llama3.2:3b` calza con `llama3.2:latest` instalado) y un botón de instalar en los que faltan, con sondeo de progreso hasta completar y refresco automático del desplegable.
- **Verificación:** contra el Ollama real del usuario (11 modelos instalados) — `GET /ollama/models` devuelve la lista real; `POST /ollama/pull` de un modelo ya instalado confirma el flujo completo (éxito en ~2s, solo verificación de digest, sin descarga real de bytes en la verificación de esta fase). Confirmado en vivo con Playwright/Chromium real: el desplegable de Ajustes de IA lista los 11 modelos reales al elegir `ollama`, y la sección de recomendados muestra los 3 con check verde. 39/39 tests de backend y 33/33 de Flutter en verde, sin regresión.

### ADR 12: Rutinas guardables — fin de la alucinación de "guardado" del chat (F13)

- **Contexto:** El usuario le pidió al chat "ponme esa rutina en mis ejercicios" tras generar una rutina, y el chat **respondió afirmando que se había confirmado y cargado automáticamente** al "calendario de ejercicios". Era falso: verificado por grep, no existía absolutamente ningún mecanismo de persistencia. La causa era el prompt del campo `reply` de `/chat-plan` (F11), que le pedía al LLM "resume en 2-3 frases qué generaste" — el modelo, sin ninguna noción de qué se persistió de verdad, inventó una confirmación creíble. Además, `training.workout_sessions`/`workout_sets` (F1/F4) solo registraban sesiones YA ejecutadas (peso/reps reales), nunca existió una plantilla reutilizable con sets/reps *objetivo* que el usuario pudiera guardar con nombre y seguir después.
- **Decisión de esquema:** una sola tabla `training.routines` con los items como `JSONB` (`[{exercise_id, name, sets, reps, rpe}]`), no una tabla relacional aparte de items — no hay hoy necesidad de queries por item individual, y evita una segunda tabla + JOIN para un caso de uso de leer/escribir la rutina completa de una vez (mismo criterio de simplicidad ya usado en `training.exercises.instructions`/`image_urls`). RLS `auth.uid() = user_id`, igual que el resto de tablas de usuario (F10).
- **Decisión de persistencia:** `INSERT` **directo desde Flutter a Supabase** (`client.schema('training').from('routines').insert(...)`), el mismo patrón exacto ya usado por `workout_sessions`/`food_logs` — no se tocó el `ai_service`. RLS ya garantiza el aislamiento por usuario sin código de backend adicional.
- **Corrección de la alucinación (causa raíz, no un parche de prompt):** se **eliminó por completo** la llamada al LLM que generaba el `reply` de `/chat-plan`. Se reemplazó por texto determinista construido en código a partir de los flags `wants_workout`/`wants_meal_plan` ya detectados por `_extract_intent`. Esto no es "un mejor prompt para evitar que mienta" — es la eliminación estructural de la posibilidad de mentir: el texto ya no pasa por el LLM, así que no puede afirmar una acción que el código no realizó. De paso, ahorra una llamada al LLM por turno (más rápido y barato).
- **Flujo real:** el chat muestra la tarjeta de rutina con un botón explícito **"Guardar rutina"** (nunca depende de que el usuario lo pida en texto libre ni de que el LLM confirme nada) → pide un nombre → `INSERT` real → `SnackBar` de confirmación real. En Entrenamiento, una sección "Mis Rutinas" lista las guardadas (`SELECT` a `training.routines`) junto a las 3 predefinidas; iniciar una guardada precarga los `sets`/`reps`/`rpe` objetivo de cada ejercicio (reutilizando `startWorkoutSession` existente, sin duplicar el flujo de sesión activa) en vez de una sesión en blanco.
- **Verificación:** aislamiento RLS de `training.routines` confirmado con JWT reales (`tests/e2e/test_auth_rls_e2e.sh`, AC6-AC8, 9/9 PASS total incluyendo F10); conteo de llamadas al LLM en `/chat-plan` bajó de 4 a 3 por turno (ya no hay la llamada de resumen); 39/39 tests backend, 38/38 tests Flutter, sin regresión.

### ADR 13: Recuperación de contraseña con mailer local (Mailpit) (F14)

- **Contexto:** `AuthScreen` (F10) solo tenía login/signup, sin ningún flujo de recuperación (verificado por grep, cero resultados). El flujo real de GoTrue (`/auth/v1/recover`) envía un correo con un link/OTP de recuperación, pero el stack de desarrollo no tenía ningún servidor SMTP configurado — sin él, GoTrue no podía enviar el correo.
- **Decisión de infraestructura:** **Mailpit** (no Mailhog, prácticamente sin mantenimiento desde 2020) como servidor SMTP de pruebas — expone SMTP en `:1025` y una **API REST** (`GET /api/v1/messages`, `GET /api/v1/search?query=to:<email>`, `GET /api/v1/message/<id>`) en `:8025` que permite extraer el correo real y su contenido **programáticamente**, sin depender de un navegador ni de interacción manual — clave para automatizar el E2E de esta Fase con datos reales, no simulados.
- **Mecanismo real de Flutter (confirmado vía Context7, no asumido):** `auth.resetPasswordForEmail(email, redirectTo: ...)` dispara `/auth/v1/recover`. Al abrir el link de recuperación, `Supabase.initialize()` detecta el token en la URL y GoTrue establece una sesión de recuperación temporal, emitiendo `AuthChangeEvent.passwordRecovery` por `onAuthStateChange`. `AuthGate` (F10) ya escuchaba ese stream para decidir login/dashboard — se le añadió una rama que prioriza este evento sobre el enrutamiento normal, mostrando `ResetPasswordScreen`, que llama `auth.updateUser(UserAttributes(password: nueva))` para completar el cambio con la sesión de recuperación activa.
- **Flujo completo:** login → "¿Olvidaste tu contraseña?" → diálogo de email → `resetPasswordForEmail` → correo real (capturado por Mailpit en dev) con link y OTP → abrir el link (o, para el E2E automatizado, usar el OTP vía `POST /auth/v1/verify {email, token, type: recovery}`) → sesión de recuperación → `updateUser` → confirmación → login funciona con la contraseña nueva, la vieja deja de servir.
- **Verificación E2E real (sin mocks):** `tests/e2e/test_password_recovery_e2e.sh` — signup real → `POST /auth/v1/recover` real → correo capturado y extraído de la API de Mailpit (no un mock) → OTP real extraído del cuerpo del correo → `POST /auth/v1/verify` (sesión de recuperación real) → `PUT /auth/v1/user` (cambio real) → login con la contraseña nueva (200) y confirmación explícita de que la contraseña vieja ya NO funciona (400 `invalid_grant`). 8/8 PASS. 44/44 tests de Flutter en verde, sin regresión.

### ADR 14: Planificación (planes de comida/rutinas por defecto) + comparación planificado-vs-real (F16)

- **Contexto:** Hasta F15 la app solo *registraba* lo ocurrido (comidas en el Diario, series ejecutadas en Entrenamiento). Faltaba la capa de *planificación*: poder guardar un plan de comidas (F13 ya guardaba rutinas), marcar uno de cada tipo como "el de hoy", y comparar lo planificado contra lo real. El gasto calórico (`TrainingProvider.todayCaloriesBurned`, F6) ya se calcula desde las sesiones completadas reales — F16 no lo toca, solo añade planificación encima.
- **Decisión de esquema:** `nutrition.meal_plans` es un mirror exacto de `training.routines` (F13) — una sola tabla con las comidas en `JSONB` (`meals`), RLS `auth.uid() = user_id`, sin tabla relacional aparte (no hay hoy necesidad de queries por comida individual). Se añade `is_default BOOLEAN` a AMBAS tablas (`meal_plans` y `routines`), con un **índice único parcial** por usuario (`... (user_id) WHERE is_default`) que garantiza a nivel de DB que solo puede haber un default por usuario y tabla — no solo por convención de la app. La app además desmarca el default anterior antes de marcar uno nuevo (mejor UX que dejar que el `INSERT`/`UPDATE` falle con 409/23505), pero el índice es la red de seguridad real.
- **Decisión de escáner:** `mobile_scanner` (7.3.0, activamente mantenido, cámara nativa, compila para web) reemplaza el diálogo mock (códigos de prueba hardcodeados) como vía principal de escaneo de código de barras. La entrada manual de código se **conserva** como respaldo (dispositivos/navegadores sin cámara o sin permiso), reusando el flujo ya existente `searchBarcode` (OpenFoodFacts) → confirmar → `addFoodLog` sin cambios.
- **Flujo de planificación:** el chat genera un plan de comidas (`/chat-plan`, F11) → botón "Guardar plan" (mismo patrón que "Guardar rutina" de F13) → `INSERT` directo a `nutrition.meal_plans`. En el Diario ("Mis Planes de Comida") y en Entrenamiento ("Mis Rutinas") se marca uno como predeterminado (estrella). El Diario compara, por tipo de comida, lo planificado del plan default contra lo realmente registrado (delta: sin registro / en línea ±10% / de más / de menos). El Dashboard ("Plan de Hoy") muestra la rutina default (¿hay sesión completada hoy?) y el plan de comida default (planificado vs `NutritionProvider.totalCalories` consumido).
- **Verificación:** aislamiento RLS de `meal_plans` + rechazo real del segundo default por el índice único confirmados con JWT reales (`tests/e2e/test_auth_rls_e2e.sh`, AC9-AC11, 12/12 PASS incluyendo F10/F13); 75/75 tests de Flutter en verde, sin regresión; `flutter build web` compila con `mobile_scanner`.
