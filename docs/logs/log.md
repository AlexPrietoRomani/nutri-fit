# Bitácora de Incidentes — Nutri-Fit

Registro forense de bugs, bloqueos y refactors. Formato: síntoma → hipótesis → causa raíz → resolución → verificación → lecciones.

---

## 2026-07-16 · INC-011 · Signup real falla en el navegador con "Failed to fetch" (CORS)

- **Severidad:** Alta (bloqueante — nadie podía registrarse desde la app web) · **Estado:** RESUELTO
- **Contexto:** El usuario probó el signup real en `http://localhost:8080` tras F10/F11. `curl` contra `/auth/v1/signup` (directo y con `Origin`/preflight simulado a mano) devolvía 200 sin problema, así que parecía que el stack estaba sano.
- **Síntoma:** En el navegador real: `ClientException: Failed to fetch, uri=http://localhost:54321/auth/v1/signup?`. La consola del navegador (reproducido con Playwright/Chromium real, no `curl`) mostraba el error real: `Access to fetch ... has been blocked by CORS policy: Request header field x-supabase-api-version is not allowed by Access-Control-Allow-Headers in preflight response.`
- **Hipótesis descartada:** el stack estaba caído o mal configurado — descartada porque `curl` con `Origin`/preflight manual sí funcionaba.
- **Causa raíz:** `curl` no aplica CORS del lado cliente, así que un preflight simulado a mano (con los headers que YO elegí probar) puede "pasar" aunque el preflight REAL del navegador falle. `supabase_flutter` envía el header `x-supabase-api-version` en sus requests (incluido en el signup), pero `docker/gateway/nginx.conf` en el `location /auth/v1/` (copiado de `/rest/v1/` en F10) solo declaraba `Access-Control-Allow-Headers: authorization,content-type,apikey,x-client-info,prefer,accept,accept-profile,content-profile` — sin `x-supabase-api-version`. El navegador, al ver que el header que necesita mandar no está en la lista permitida, bloquea la petición completa antes de enviarla (`net::ERR_FAILED`).
- **Resolución:** Añadido `x-supabase-api-version` a `Access-Control-Allow-Headers` en ambos `location` (`/rest/v1/` y `/auth/v1/`) de `nginx.conf`, más `proxy_hide_header 'Access-Control-Allow-Credentials'` (GoTrue emite ese header con `true` junto a `Access-Control-Allow-Origin: *` propio, una combinación inválida para requests credentialed que el gateway ya oculta para los demás headers CORS — se añadió por consistencia/prevención, aunque el fallo real reproducido fue el de `x-supabase-api-version`). `docker compose restart gateway`.
- **Verificación:** Reproducido y confirmado con Playwright/Chromium real (headless) contra `http://localhost:8080`: antes del fix, `[requestfailed] .../signup? -> net::ERR_FAILED` con el mensaje de CORS en consola; después del fix, `[response] 200 .../signup?` y la app avanza al Onboarding.
- **Lecciones:** `curl` **no sirve para validar CORS** — no aplica la política del navegador, así que un preflight "exitoso" con `curl` no garantiza que el navegador real vaya a aceptar la respuesta. Para diagnosticar fallos de CORS hay que reproducir con un navegador real (Playwright/Chromium headless) y leer el mensaje de consola, que dice EXACTAMENTE qué header/método faltó — no adivinar. Al copiar un bloque `location` de CORS a uno nuevo (como se hizo de `/rest/v1/` a `/auth/v1/` en F10), revisar si el servicio de destino (aquí GoTrue) envía headers propios (`x-supabase-api-version`, `Access-Control-Allow-Credentials`) que el cliente real necesita y que el bloque original no contemplaba.

## 2026-07-16 · INC-012 · Dos Ollama compitiendo por el puerto 11434 del host (F12)

- **Severidad:** Alta (causaba el bug reportado de modelo no encontrado) · **Estado:** RESUELTO
- **Contexto:** F12 investigó por qué el modelo por defecto sugerido para `ollama` en Ajustes de IA nunca coincidía con lo que el usuario tenía instalado.
- **Síntoma:** `curl http://localhost:11434/api/tags` devolvía a veces un Ollama casi vacío (un solo modelo, pulleado por error en una sesión de F11) en vez de los ~11 modelos reales del Ollama nativo de Windows del usuario.
- **Causa raíz:** `docker-compose.yml` (desde F1) tenía un servicio `ollama` (imagen `ollama/ollama:latest`) con `ports: "11434:11434"`, publicando ese puerto del host — el mismo puerto en el que ya escucha el Ollama nativo instalado en Windows. Ambos procesos compitiendo por el mismo puerto del host hacía impredecible cuál respondía. Además, `OLLAMA_HOST` (tanto en `ai_engine.py` como, con un bug adicional, en `main.py` con default `http://localhost:11434`) apuntaba al servicio docker interno o a un `localhost` inalcanzable desde dentro de un contenedor, nunca al Ollama real del host.
- **Resolución:** Se removió por completo el servicio `ollama` (y su volumen) de `docker-compose.yml` — nada más en el repo lo referenciaba por hostname. Se corrigió el default de `OLLAMA_HOST` en `ai_engine.py` y `main.py` a `http://host.docker.internal:11434` (el servicio `backend` ya tenía el `extra_hosts` necesario desde F8).
- **Verificación:** `curl http://localhost:11434/api/tags` desde el host devuelve los ~11 modelos reales; `host.docker.internal:11434` alcanzable con 200 desde dentro del contenedor backend; 30/30 tests backend sin regresión. Al hacer `docker compose down` tras editar el compose, el contenedor `nutri-fit-ollama` (ya no definido en el archivo) quedó huérfano y bloqueó el borrado de la red (`Resource is still in use`) — se resolvió con `docker stop nutri-fit-ollama && docker rm nutri-fit-ollama` manual antes de `docker compose up`.
- **Lecciones:** No dupliques un servicio (Ollama, Postgres, etc.) en `docker-compose.yml` cuando el usuario ya lo corre nativamente y el proyecto accede a él vía `host.docker.internal` — el conflicto de puerto es silencioso y confuso (`curl` a veces "funciona", solo que contra el proceso equivocado). Al remover un servicio del compose que ya estaba corriendo, el contenedor viejo queda huérfano y hay que pararlo/borrarlo a mano una vez — `docker compose down` no lo reconoce si ya no está en el archivo.

## 2026-07-16 · INC-013 · El contenedor backend no recoge cambios de código sin rebuild

- **Severidad:** Baja (confusión de proceso, no bug de producto) · **Estado:** RESUELTO/ACLARADO
- **Contexto:** Al construir T12.2.1/T12.2.2, verificar los nuevos endpoints contra el contenedor backend YA arriba no reflejaba el código nuevo.
- **Síntoma:** Tras editar `backend/app/main.py`, `curl http://localhost:8000/ollama/models` seguía dando 404 hasta copiar el archivo a mano dentro del contenedor y reiniciarlo.
- **Causa raíz:** El servicio `backend` de `docker-compose.yml` **no monta el código como volumen** (a diferencia de un dev-container típico) — la imagen se hornea con el código en build time (`Dockerfile` hace `COPY`). Es el comportamiento esperado para este proyecto (no un bug), pero hay que recordarlo: cualquier cambio en `backend/` requiere `docker compose up -d --build backend` (o `--build` general) para reflejarse, un simple `restart` no basta.
- **Resolución:** Ninguna necesaria en el código — es el diseño correcto para un build reproducible. Se usó `docker compose up -d --build backend` para recoger los cambios de forma limpia (en vez del `docker cp` + `restart` que se usó como atajo durante la construcción de la tarea).
- **Verificación:** Tras `--build backend`, 39/39 tests y `/ollama/models` responden con el código nuevo.
- **Lecciones:** Cuando el usuario pregunte "¿el docker ya está actualizado?", la respuesta correcta pasa por confirmar que se corrió `docker compose up -d --build` (no solo `restart`) tras el último cambio de código en `backend/`. `docker cp` + `restart` es un atajo válido para verificación rápida durante el desarrollo de una tarea, pero no reemplaza el rebuild final antes de dar la tarea por cerrada.

## 2026-07-16 · INC-009 · GoTrue no arranca: `password authentication failed for user "supabase_auth_admin"`

- **Severidad:** Alta (bloqueante para T10.1.1) · **Estado:** RESUELTO
- **Contexto:** Levantar el servicio `auth` (GoTrue) recién añadido en `docker-compose.yml` contra `supabase/postgres:15.1.0.117`.
- **Síntoma:** `docker logs nutri-fit-auth` mostraba `fatal: running db migrations: ... failed SASL auth (FATAL: password authentication failed for user "supabase_auth_admin" (SQLSTATE 28P01))` al conectar `GOTRUE_DB_DATABASE_URL=postgres://supabase_auth_admin:devpassword123@postgres:5432/postgres`, pese a que la contraseña `devpassword123` se había "confirmado" antes por conexión directa.
- **Hipótesis:** (1) contraseña incorrecta documentada — descartada tras revisar `pg_hba.conf`; (2) el rol no tiene la contraseña seteada a nivel de autenticación de red — confirmada.
- **Causa raíz:** `pg_hba.conf` de la imagen tiene `trust` para `local` y `127.0.0.1/32`/`::1/128`, pero `scram-sha-256` para cualquier otra conexión (`host all all all scram-sha-256`). La "confirmación" previa de la contraseña se hizo con `psql -h localhost` (trust, ignora la contraseña que se pase), así que nunca se verificó por red. Además `supabase_auth_admin` es un rol protegido ("reserved role"): solo `supabase_admin` (el superusuario real de la imagen, no `postgres`, que no es superuser aquí) puede alterarlo.
- **Resolución:** `docker exec -e PGPASSWORD=x nutri-fit-postgres psql -U supabase_admin -h 127.0.0.1 -d postgres -c "ALTER ROLE supabase_auth_admin WITH PASSWORD 'devpassword123';"` (conexión trust local, sin tocar `docker/postgres/*.sql`). Incidente secundario menor: al reiniciar `gateway` (nginx) antes de que el contenedor `auth` existiera, nginx falló con `host not found in upstream "auth"` porque resuelve upstreams estáticos solo al arrancar; se resolvió reiniciando `gateway` después de `auth`.
- **Verificación:** Contenedor efímero `postgres:15-alpine` conectando a `host=postgres user=supabase_auth_admin` confirmó `select 1`; GoTrue arrancó, aplicó 49 migraciones y `GET /health` devolvió 200. `POST /auth/v1/signup` vía el gateway devolvió `access_token` con `role: authenticated`, y `auth.users` mostró la fila con `confirmed_at` no nulo.
- **Lecciones:** En Supabase self-hosted, alterar roles reservados (`supabase_auth_admin`, `supabase_storage_admin`, etc.) requiere el rol `supabase_admin`, nunca `postgres`. Verificar una contraseña de un rol solo por `-h localhost`/socket local no prueba nada bajo `scram-sha-256`: hay que probarla contra el hostname de red real que usará el servicio consumidor. Además, con upstreams estáticos en nginx, el orden de arranque importa — levantar `auth` antes de reiniciar `gateway`.

---

## 2026-07-16 · INC-010 · INC-009 reaparece tras `docker compose down -v` (T10.2.1/T10.2.2)

- **Severidad:** Media (bloqueaba la verificación, no el código) · **Estado:** RESUELTO
- **Contexto:** `docker compose down -v && up -d --build` para que `zzz_auth_rls.sql` (FK `auth.users` + RLS, T10.2.1/T10.2.2) corriera sobre un volumen Postgres vacío.
- **Síntoma:** Igual que INC-009 — `nutri-fit-auth` moría con `password authentication failed for user "supabase_auth_admin"`; `nutri-fit-gateway` fallaba con `host not found in upstream "auth"` por haber arrancado antes que `auth` existiera.
- **Causa raíz:** La resolución de INC-009 (`ALTER ROLE supabase_auth_admin WITH PASSWORD ...` vía `supabase_admin`) se aplicó a mano sobre el volumen Postgres en su momento y nunca se persistió en ningún script versionado — vive solo en el estado del volumen. Al borrar el volumen (`-v`), el fix se perdió y el problema reapareció idéntico. No es un bug nuevo, es el mismo incidente sin fix declarativo.
- **Resolución:** Se re-aplicó el mismo comando (`docker exec -e PGPASSWORD=devpassword123 nutri-fit-postgres psql -U supabase_admin -h 127.0.0.1 -d postgres -c "ALTER ROLE supabase_auth_admin WITH PASSWORD 'devpassword123';"`), luego `docker restart nutri-fit-auth` y, tras confirmar que `auth` estaba arriba, `docker restart nutri-fit-gateway`.
- **Verificación:** Igual que INC-009 — GoTrue aplicó 49 migraciones y sirvió `/auth/v1/signup`; el test de aislamiento RLS end-to-end de T10.2.2 confirmó todo el flujo funcionando.
- **Lecciones:** Este incidente **volverá a ocurrir en cada `down -v`** mientras el fix no esté en un script versionado. Fuera del alcance de T10.2.1/T10.2.2 (que solo tocan `zzz_auth_rls.sql`), pero queda pendiente para una tarea futura: mover el `ALTER ROLE supabase_auth_admin` a un script que corra con el privilegio adecuado en cada init (p. ej. como parte del entrypoint de `auth` o un script ejecutado por `supabase_admin`), para que la reconstrucción del volumen sea reproducible sin intervención manual.
- **Intento de fix declarativo (descartado):** se probó un script `docker-entrypoint-initdb.d/zzzz_fix_auth_admin_pw.sh` con `psql -h 127.0.0.1 -U supabase_admin` (la conexión TCP que SÍ funciona una vez el contenedor está arriba, por el `trust` de `pg_hba.conf` a `127.0.0.1/32`). **Falló** con `Connection refused`: durante la fase de bootstrap en que corren los scripts de `docker-entrypoint-initdb.d`, el servidor temporal de Postgres NO escucha por TCP (solo socket Unix), así que `-h 127.0.0.1` no es alcanzable en ese momento aunque sí lo sea después del arranque final. Y por socket Unix, `pg_hba.conf` exige `scram-sha-256` para `supabase_auth_admin` (no hay `trust` local para ese rol específico), así que tampoco vale conectar sin `-h`. Conclusión: el fix declarativo real requeriría un mecanismo que corra DESPUÉS del arranque completo (p. ej. un contenedor sidecar con `depends_on: postgres (healthy)` que aplique el `ALTER ROLE` una vez), no un script de `docker-entrypoint-initdb.d`. Se revirtió el intento para no dejar el volumen en un estado parcialmente inicializado.

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

## 2026-07-16 · INC-006 · El gate inicial siempre mostraba el registro (aunque hubiera perfil)

- **Severidad:** Media (UX) · **Estado:** RESUELTO
- **Síntoma:** Tras registrarse, al volver atrás (o reabrir la app) siempre aparecía la pantalla de Onboarding/registro; un usuario con perfil nunca entraba directo al Dashboard. En web, el botón atrás del navegador llevaba de vuelta al "menú de inicio" (registro).
- **Causa raíz:** `InitialCheckScreen._isProfileConfigured()` comprobaba `client.auth.currentUser`, pero la app usa bypass de auth (sin GoTrue), así que `currentUser` es siempre `null` → el método siempre devolvía `false` → siempre renderizaba `OnboardingScreen`. Nunca consultaba el perfil real (fila de `devUserId` en `public.users`).
- **Resolución:** El gate ahora consulta `public.users` por `client.auth.currentUser?.id ?? AppConstants.devUserId`. Con perfil → `DashboardScreen`; sin perfil → `OnboardingScreen`. El onboarding ya usaba `pushReplacementNamed('/dashboard')`, así que volver a `/` re-resuelve al Dashboard.
- **Verificación:** E2E web (Playwright) cargando la raíz `/` con el perfil `devUserId` presente → renderiza el Dashboard directamente (`e2e/shots/initcheck-root.png`), sin pasar por el registro.
- **Lecciones:** Con bypass de auth, cualquier decisión de sesión (gate inicial, "tengo perfil") debe basarse en el `devUserId`, no en `auth.currentUser`. Relacionado con INC-003 (mismo origen: el bypass de auth).

## 2026-07-16 · INC-007 · Se perdió el detalle F7/F8 del tablero al mover ramas (estaba gitignored)

- **Severidad:** Media (pérdida de artefactos de proceso) · **Estado:** RESUELTO
- **Contexto:** Tras mergear el PR #1, se movieron los commits a una rama de feature y se hizo `git checkout master` + `git merge --ff-only`.
- **Síntoma:** `docs/plan/plan_maestro.md` y `docs/task/tareas.md` desaparecieron del disco; el detalle de F7/F8 (que solo existía localmente) se perdió.
- **Causa raíz:** Ambos archivos estaban **gitignored** (decisión previa) — nunca entraron al PR. Pero en `master`(`7f7333d`) SÍ estaban trackeados; el `checkout master` restauró la versión vieja (F1–F6) sobre las locales F1–F8, y el merge (que incluye el `git rm --cached`) los eliminó del working tree. Al estar ignorados, git no los protegía.
- **Resolución:** Se restauraron `plan_maestro.md`/`tareas.md` desde `7f7333d`, se reconstruyeron F7/F8 (desde los commits/PR) y se añadió F9. **Se dejó de ignorarlos**: ahora `docs/plan` y `docs/task` se versionan, así ninguna operación de rama vuelve a borrarlos.
- **Verificación:** Los archivos existen, contienen F1–F9, y `git status` los muestra como trackeados.
- **Lecciones:** No gitignorar artefactos que quieres conservar entre operaciones de rama — un archivo ignorado no está protegido por git y puede ser clobbered por checkouts/merges que toquen su ruta. El tablero spec-driven vale la pena versionarlo.

## 2026-07-16 · INC-008 · `image_picker` lanza en web: el build servido no registraba el plugin

- **Severidad:** Alta (bloqueaba el E2E de visión en web) · **Estado:** RESUELTO
- **Contexto:** E2E de UI de F9 (foto → borrador → `food_logs`) contra el build web servido en `:8080` (un `python -m http.server` sobre `frontend/build/web`).
- **Síntoma:** Al pulsar la cámara, Playwright registraba un `[pageerror] Error` (stack minificado), el `filechooser` NO disparaba y no aparecía el borrador. `ImagePicker().pickImage()` fallaba antes de abrir el selector.
- **Causa raíz:** El `web_plugin_registrant.dart` del build servido solo registraba `app_links`, `shared_preferences` y `url_launcher` — faltaban `image_picker_for_web` y `flutter_secure_storage_web`. El build se generó justo cuando se añadió `image_picker` (F9) y el registrant quedó cacheado sin el plugin; en web, sin registrant, `pickImage` cae al method channel inexistente y lanza. Un `flutter build web` incremental (mismo build id) reusó el registrant viejo.
- **Resolución:** `flutter clean` + `flutter build web` regeneró el registrant (ya incluye `ImagePickerPlugin.registerWith` y `FlutterSecureStorageWeb.registerWith`). El `python -m http.server` sirve `build/web` en vivo, así que basta rebuild (sin reiniciar el server).
- **Verificación:** E2E `run_vision_e2e.mjs` verde de punta a punta: cámara → file picker → `/analyze-meal` con `gemma4:e4b` (visión real, no mock: detectó el plato de salmón) → borrador → `Guardar` → fila en `nutrition.food_logs`.
- **Lecciones:** Tras añadir/quitar un plugin con implementación web, **reconstruir con `flutter clean`** antes de servir — un build incremental puede reusar un `web_plugin_registrant.dart` cacheado sin el plugin nuevo, y el fallo en web es un error genérico que no dice "falta el plugin". Bonus: este rebuild también registró `flutter_secure_storage_web`, mitigando INC-004 en web.
