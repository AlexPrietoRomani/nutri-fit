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
