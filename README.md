# Nutri-Fit

Aplicación open-source de **fitness y nutrición** (web + móvil) con backend modular y un asistente de IA multi-proveedor que genera planes de comida y rutinas con ejercicios reales.

El backend está dividido en tres dominios: **Nutrición**, **Entrenamiento** e **Inteligencia Artificial**.

## Stack

| Capa | Tecnología |
|------|-----------|
| Frontend | Flutter (web + móvil), `provider` para estado |
| Auth | Supabase GoTrue + RLS (`auth.uid() = user_id`) |
| Datos | PostgreSQL (esquemas `public`, `nutrition`, `training`) vía PostgREST |
| Servicio IA | Python / FastAPI (`ai_service`) |
| IA multi-proveedor | OpenAI · OpenRouter · Google Gemini · Claude · Ollama · LM Studio · vLLM |
| Correo (dev) | Mailpit (recuperación de contraseña) |
| Gateway | nginx |

## Servicios y puertos (docker compose)

| Servicio | Puerto host | Uso |
|----------|-------------|-----|
| Gateway (nginx) | `54321` | Punto de entrada de Auth + PostgREST |
| Postgres | `54322` | Base de datos |
| ai_service (FastAPI) | `8000` | Chat, planes, visión de comida/máquinas |
| GoTrue (auth) | `9999` | Autenticación |
| Mailpit | `8025` (UI/REST) · `1025` (SMTP) | Correos de dev |
| Frontend (Flutter web) | `8080` | App (se sirve aparte, ver abajo) |

## Arranque rápido

Requisitos: Docker + Docker Compose, Flutter SDK (>=3.0), y opcionalmente [Ollama](https://ollama.com) en el host para IA local.

```bash
# 1. Levantar el backend (Postgres + Auth + PostgREST + ai_service + Mailpit + gateway)
cp .env.example .env        # opcional: claves de IA (también se pueden meter desde la app)
docker compose up -d

# 2. Frontend (Flutter web en :8080)
cd frontend
flutter pub get
flutter run -d chrome --web-port 8080
```

- **IA local (recomendada):** ten `ollama serve` corriendo en el host; el contenedor lo alcanza vía `host.docker.internal:11434`. Descarga un modelo (p. ej. `ollama pull llama3.1`) o hazlo desde **Ajustes de IA** en la app.
- **IA en la nube:** elige el proveedor en **Ajustes de IA** e introduce tu API key (o define `ANTHROPIC_API_KEY` / `OPENAI_API_KEY` en `.env`).

> **Reset de base de datos:** `docker compose down -v` borra el volumen y reejecuta todos los seeds (`docker/postgres/*.sql`). Necesario cuando cambia el esquema.

## Funcionalidades

- **Onboarding** con cálculo de BMR/meta calórica y perfil físico (incluye peso para el cálculo de cardio).
- **Diario nutricional**: registro manual, por cámara IA (foto → macros), escáner de código de barras (OpenFoodFacts) y catálogo de comida peruana.
- **Entrenamiento en vivo**: tracker de series/reps/RPE, cardio con cálculo de calorías por **METs** (según ritmo/distancia), búsqueda de ejercicios por nombre/músculo y detalle con imágenes e instrucciones.
- **Chat de IA (nutricionista/entrenador)**: genera y **guarda** planes de comida y rutinas con ejercicios reales del catálogo, responde dudas y analiza progreso.
- **Planificación y adherencia**: planes predeterminados, comparación *planificado vs. real* en el Dashboard.
- **Autenticación real** con RLS por usuario y **recuperación de contraseña** vía correo (Mailpit en dev).

## Pruebas

```bash
# Backend
cd backend && pytest

# Frontend
cd frontend && flutter test

# E2E de auth + RLS (con JWT reales)
bash tests/e2e/test_auth_rls_e2e.sh
```

## Documentación

- [`docs/description_proyecto.md`](docs/description_proyecto.md) — qué hace el sistema y flujos de UI/backend.
- [`docs/architecture/architecture.md`](docs/architecture/architecture.md) — arquitectura y decisiones (ADR).
- [`docs/db/diseno_db.md`](docs/db/diseno_db.md) — esquema de base de datos.
- `docs/plan/plan_maestro.md` y `docs/task/tareas.md` — plan por fases y tablero de tareas.

## Estado

Fases **F1–F17 completas** (infra, nutrición, entrenamiento, IA de visión, chatbot multi-proveedor, auth real + recuperación de contraseña, rutinas y planes guardables, planificación/adherencia, cardio por METs, búsqueda de ejercicios y catálogo peruano).

**F18 planificada (en desarrollo):** chat con memoria de conversación, planes multi-semana variados, repreguntas, preferencias/alergias, micronutrientes reales y catálogo por ingredientes con platos componibles.
