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
1. **User Action:** Clic en "Tomar foto con IA" dentro de la sección "Almuerzo".
2. **Frontend Logic:** Captura la imagen, la almacena localmente y la sube al bucket de Supabase Storage `/meals`. Obtiene una URL pública.
3. **Backend Side-Effects:**
   - La app hace un POST a `http://ai-service/analyze-meal` con la URL de la imagen.
   - FastAPI procesa la foto con LLaVA o Gemini Vision y retorna la información nutricional en JSON.
   - El frontend muestra los datos. Si el usuario hace clic en "Guardar", se ejecuta un `INSERT` en la tabla `nutrition.food_logs`.

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
