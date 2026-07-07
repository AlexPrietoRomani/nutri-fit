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
