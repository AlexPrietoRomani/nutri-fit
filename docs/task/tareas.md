# Tablero de Tareas: Nutri-Fit Modular

Este tablero sigue el desarrollo fase a fase de la infraestructura y el diseño de la UI/UX vinculada al backend.

## Fuentes de Contexto Obligatorias
- [description_proyecto.md](../description_proyecto.md)
- [architecture.md](../architecture/architecture.md)
- [diseno_db.md](../db/diseno_db.md)

---

## F1: Setup de Infraestructura Modular [ ]

### SF1.1: Docker & PostgreSQL Schemas Setup [ ]

#### T1.1.1: Configurar Supabase Local y Docker Compose [ ]
- **🧠 Explicación:** Dockerizar todo el backend incluyendo base de datos y microservicios de IA.
- **Acciones:**
  - `[ ]` A1.1.1.1: Crear `docker-compose.yml` en la raíz incluyendo Supabase, FastAPI y Ollama.
  - `[ ]` A1.1.1.2: Inicializar stack de Supabase local.

#### T1.1.2: Crear Estructura de Esquemas de PostgreSQL [ ]
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
  - `[ ]` A1.1.2.1: Crear script de migración para inicializar los esquemas y tablas básicas.
  - `[ ]` A1.1.2.2: Aplicar la migración SQL al contenedor Postgres.

---

## F2: Diseño de UI y Mapeo de Eventos en Flutter [ ]

### SF2.1: Implementación del Flujo del Dashboard y Onboarding [ ]

#### T2.1.1: UI y Cuestionario del Onboarding [ ]
- **🧠 Explicación:** Pantalla interactiva en Flutter para capturar datos físicos del usuario al inicio.
- **Acciones:**
  - `[ ]` A2.1.1.1: Crear interfaz con carrusel de preguntas en Flutter.
  - `[ ]` A2.1.1.2: Implementar el cálculo de BMR (Mifflin) local en la app al presionar "Calcular".

#### T2.1.2: Clic a Base de Datos - Guardar Perfil [ ]
- **🧠 Explicación:** El clic del botón final en Onboarding debe impactar al backend insertando en `users` y `nutrition.user_goals`.
- **💡 Cómo hacerlo:**
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
- **Acciones:**
  - `[ ]` A2.1.2.1: Configurar llamada API de Supabase en el controlador del carrusel de onboarding en Flutter.
  - `[ ]` A2.1.2.2: Escribir tests unitarios para verificar inserciones correctas.
