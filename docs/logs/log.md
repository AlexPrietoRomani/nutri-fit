# Bitácora de Incidentes — Nutri-Fit

Registro forense de bugs, bloqueos y refactors. Formato: síntoma → hipótesis → causa raíz → resolución → verificación → lecciones.

---

## 2026-07-15 · INC-001 · CORS duplicado rompe toda escritura desde la app web

- **Severidad:** Alta (bloqueante) · **Estado:** RESUELTO
- **Contexto:** E2E web (Playwright) del onboarding contra el stack real (gateway 54321).
- **Síntoma:** El navegador rechaza el `POST /rest/v1/users` con:
  `Access-Control-Allow-Origin header contains multiple values '*, *', but only one is allowed`. La app no persiste nada.
- **Hipótesis:** (a) doble `add_header` en nginx; (b) nginx *y* PostgREST emiten el header CORS.
- **Causa raíz:** PostgREST v12 emite sus propios headers CORS cuando la petición trae `Origin`. El gateway nginx también los añade con `add_header ... always`. Resultado: el header se duplica (`*, *`), inválido para el navegador.
- **Resolución:** En `docker/gateway/nginx.conf`, dentro de `location /rest/v1/`, se añadió `proxy_hide_header` para `Access-Control-Allow-Origin`, `-Methods`, `-Headers`, `-Expose-Headers`, ocultando los del upstream y dejando solo los del gateway (valor único).
- **Verificación:** `curl -D-` al gateway devuelve un único `Access-Control-Allow-Origin: *`. Re-corrido el E2E, el onboarding escribe en `public.users` y `nutrition.user_goals` (confirmado en Postgres).
- **Lecciones:** Al poner un proxy delante de un servicio que ya hace CORS, hay que ocultar los headers del upstream o delegar CORS en uno solo. Un unit test nunca lo habría detectado; lo cazó el E2E.

---

## 2026-07-15 · INC-002 · Volumen de Postgres persistente sirve esquema/seed viejos

- **Severidad:** Media · **Estado:** RESUELTO
- **Síntoma:** Tras extender `training.exercises` y montar el seed, la DB seguía con el esquema viejo y `SELECT count(*)` = 0; PostgREST daba `column ... does not exist`.
- **Causa raíz:** Los scripts de `docker-entrypoint-initdb.d` solo corren cuando el directorio de datos está **vacío**. El volumen `postgres_data` ya existía de corridas previas, así que `z_init.sql` y `zz_exercises_seed.sql` nunca se re-ejecutaron.
- **Resolución:** `docker compose down -v` (elimina volúmenes) + `up` → initdb corre fresco. 873 ejercicios cargados.
- **Verificación:** `SELECT count(*) FROM training.exercises` = 873; PostgREST sirve las columnas nuevas.
- **Lecciones:** Cualquier cambio en `z_init.sql`/seeds exige recrear el volumen en dev. Documentar en el README un `make db-reset` (`down -v && up`). Nunca asumir que un cambio de DDL aplica sobre un volumen existente.

---

## 2026-07-15 · INC-003 · UUID de usuario de dev inconsistente entre módulos

- **Severidad:** Media · **Estado:** RESUELTO
- **Síntoma:** (a) Tras el onboarding, el Dashboard muestra la meta calórica por defecto (2000) en vez de la recién guardada (2217). (b) Iniciar un entrenamiento falla silenciosamente (la sesión no arranca).
- **Causa raíz:** Con el bypass de auth, cada módulo hardcodea un UUID distinto:
  `onboarding_provider.dart` escribe a `00000000-0000-4000-a000-000000000001`, mientras `nutrition_provider.dart` y `training_provider.dart` leen/escriben con `00000000-0000-0000-0000-000000000000`. El Dashboard lee otro id (→ defaults) y el `INSERT` en `training.workout_sessions` viola el FK a `public.users` (ese id no existe).
- **Resolución:** Se añadió `AppConstants.devUserId` en `core/constants.dart` y se reemplazaron los tres IDs mágicos en `onboarding_provider.dart`, `nutrition_provider.dart` y `training_provider.dart` (2 sitios) por esa constante única.
- **Verificación:** E2E en el emulador Android — tras onboarding, el Dashboard muestra la meta real (2217 kcal, macros 140/257/70) en vez de los defaults (2000/150/200/65), y el inicio de entrenamiento ya no viola el FK. Confirmado también el `INSERT` en `public.users` desde el móvil (nombre "MovilTester").
- **Lecciones:** El bypass de auth debe centralizar el id de dev en un solo lugar; IDs mágicos duplicados divergen. El E2E confirmó (y luego validó el fix de) el drift que la auditoría estática ya había señalado (hallazgo A2).

---

## 2026-07-16 · INC-004 · `flutter_secure_storage` falla en Flutter web

- **Severidad:** Media · **Estado:** RESUELTO
- **Contexto:** E2E de UI del chatbot (F8) en el build web servido en `:8080`.
- **Síntoma:** Al abrir el chat y al guardar la config de IA, dos `pageerror` en el navegador; la pantalla de Ajustes se quedaba atascada (no navegaba tras "Guardar").
- **Causa raíz:** `AiProvider.loadConfig`/`saveConfig` usaban `flutter_secure_storage`, cuyo soporte web lanzó excepción en este entorno. Como `saveConfig` hacía `await _store.save(...)` **antes** de fijar `_config`, la excepción impedía guardar la config en memoria y el `Navigator.pop`.
- **Resolución:** En `ai_provider.dart`, `saveConfig` fija `_config` en memoria y notifica **primero**, y persiste en secure storage como *best-effort* dentro de `try/catch`; `loadConfig` también degrada sin crash. En móvil (Keychain/Keystore) la persistencia sigue funcionando; en web la config vive en memoria durante la sesión.
- **Verificación:** Re-corrido el E2E web sin `pageerror`; la config se guarda y el chat opera.
- **Lecciones:** El almacenamiento seguro es específico de plataforma; nunca bloquear el estado de UI en una escritura de storage que puede fallar en web.

## 2026-07-16 · INC-005 · `ai_service` sin CORS bloquea al frontend web

- **Severidad:** Alta (bloqueante en web) · **Estado:** RESUELTO
- **Síntoma:** El chat web mostraba `ClientException: Failed to fetch, uri=http://localhost:8000/chat`, pese a que `curl` al mismo endpoint funcionaba.
- **Causa raíz:** El frontend web (`:8080`) llama al `ai_service` (`:8000`) **cross-origin**; el FastAPI no tenía CORS, así que el navegador bloqueaba la petición (curl no aplica CORS, por eso pasaba desapercibido). El gateway nginx tenía CORS solo para PostgREST, no para el `ai_service`.
- **Resolución:** Se añadió `CORSMiddleware` a `backend/app/main.py` (`allow_origins=["*"]` en dev). Se reconstruyó la imagen del backend.
- **Verificación:** `OPTIONS /chat` → 200 con `Access-Control-Allow-Origin: *`; el E2E web del chat renderiza la respuesta real de Ollama.
- **Lecciones:** Todo servicio HTTP consumido directamente por un frontend web necesita CORS; probar siempre desde el navegador (no solo curl). En móvil nativo no aplica (no es navegador).
