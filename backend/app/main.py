import os
import base64
import json
from typing import Optional, List
from fastapi import FastAPI, HTTPException, File, UploadFile, Form, BackgroundTasks
from pydantic import BaseModel, Field
import httpx
import psycopg2

from fastapi.middleware.cors import CORSMiddleware

from app.ai_engine import (
    AIConfig,
    generate as ai_generate,
    generate_vision as ai_generate_vision,
    AIEngineError,
)


def _parse_ai_config(ai_json):
    """Parsea el JSON de AIConfig que llega en el form (o None)."""
    if not ai_json:
        return None
    try:
        return AIConfig(**json.loads(ai_json))
    except Exception:
        return None

app = FastAPI(
    title="Nutri-Fit AI Backend",
    description="Microservicio de IA en Python para el procesamiento de imágenes de comidas y reconocimiento de máquinas.",
    version="0.1.0"
)

# CORS: el frontend web (Flutter en otro puerto) llama a este servicio cross-origin.
# En dev permitimos cualquier origen; en prod restringir a los dominios de la app.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configuración desde variables de entorno
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/postgres")
OLLAMA_HOST = os.getenv("OLLAMA_HOST", "http://host.docker.internal:11434")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "llava")

# Esquemas de respuesta structured JSON para los endpoints
class MealAnalysisResponse(BaseModel):
    food_items: List[str] = Field(..., description="Lista de alimentos identificados")
    calories: int = Field(..., description="Estimación de calorías en kcal")
    protein: float = Field(..., description="Estimación de proteínas en gramos")
    carbohydrates: float = Field(..., description="Estimación de carbohidratos en gramos")
    fat: float = Field(..., description="Estimación de grasas en gramos")
    confidence_score: float = Field(..., description="Puntaje de confianza (0.0 a 1.0)")
    notes: str = Field(..., description="Explicación o descripción breve del platillo")

class MachineIdentificationResponse(BaseModel):
    machine_name: str = Field(..., description="Nombre de la máquina identificada")
    description: str = Field(..., description="Descripción del uso de la máquina")
    target_muscles: List[str] = Field(..., description="Grupos musculares objetivo")
    associated_exercises: List[str] = Field(..., description="Ejercicios asociados que se pueden realizar")
    safety_tips: List[str] = Field(..., description="Consejos de seguridad para su uso")
    confidence_score: float = Field(..., description="Puntaje de confianza (0.0 a 1.0)")

@app.get("/api")
def read_root():
    """
    Endpoint raíz para verificar el estado básico del servicio.
    """
    return {"status": "ok", "service": "Nutri-Fit AI Backend"}

@app.get("/health")
def health_check():
    """
    Realiza una verificación de estado de las conexiones a la base de datos y a Ollama.
    """
    db_status = "unknown"
    ollama_status = "unknown"

    # Verificar conexión a base de datos Postgres
    try:
        conn = psycopg2.connect(DATABASE_URL, connect_timeout=3)
        with conn.cursor() as cursor:
            cursor.execute("SELECT 1;")
        conn.close()
        db_status = "healthy"
    except Exception as e:
        db_status = f"unhealthy: {str(e)}"

    # Verificar conexión al servidor Ollama
    try:
        # Intentamos obtener la versión o listar modelos en Ollama
        response = httpx.get(f"{OLLAMA_HOST}/api/tags", timeout=3.0)
        if response.status_code == 200:
            ollama_status = "healthy"
        else:
            ollama_status = f"unhealthy (status code {response.status_code})"
    except Exception as e:
        ollama_status = f"unhealthy: {str(e)}"

    return {
        "status": "healthy" if db_status == "healthy" and ollama_status == "healthy" else "degraded",
        "database": db_status,
        "ollama": ollama_status
    }

async def get_image_base64(image_url: Optional[str], file: Optional[UploadFile]) -> str:
    """
    Obtiene el contenido de la imagen en formato base64 a partir de un archivo subido o de una URL.
    """
    if file:
        content = await file.read()
        return base64.b64encode(content).decode("utf-8")
    elif image_url:
        try:
            async with httpx.AsyncClient() as client:
                response = await client.get(image_url, timeout=10.0)
                if response.status_code == 200:
                    return base64.b64encode(response.content).decode("utf-8")
                else:
                    raise HTTPException(
                        status_code=400, 
                        detail=f"No se pudo descargar la imagen desde la URL. Código de estado: {response.status_code}"
                    )
        except Exception as e:
            raise HTTPException(status_code=400, detail=f"Error al descargar la imagen de la URL: {str(e)}")
    else:
        raise HTTPException(
            status_code=400, 
            detail="Debe proporcionar un archivo de imagen o una URL de imagen."
        )

@app.post("/analyze-meal", response_model=MealAnalysisResponse)
async def analyze_meal(
    image_url: Optional[str] = Form(None),
    file: Optional[UploadFile] = File(None),
    ai: Optional[str] = Form(None),
):
    """
    Analiza la foto de una comida y estima sus ingredientes, calorías y macronutrientes.
    Si el cliente envía una AIConfig (F9), usa la visión multi-proveedor; si no, intenta
    Ollama (llava) y, en último caso, retorna un mock estructurado.
    """
    # Obtener imagen en base64
    image_b64 = await get_image_base64(image_url, file)

    prompt = (
        "Analyze this meal image. Identify the food items and estimate the total "
        "calories (kcal), protein (g), carbohydrates (g), and fat (g).\n"
        "You must return ONLY a JSON object with this exact structure:\n"
        "{\n"
        '  "food_items": ["item1", "item2"],\n'
        '  "calories": 350,\n'
        '  "protein": 20.0,\n'
        '  "carbohydrates": 40.0,\n'
        '  "fat": 10.0,\n'
        '  "confidence_score": 0.85,\n'
        '  "notes": "Brief explanation or description of the meal."\n'
        "}"
    )

    # Rama multi-proveedor (F9): si el cliente envió su config, úsala.
    cfg = _parse_ai_config(ai)
    if cfg is not None:
        try:
            text = ai_generate_vision(cfg, prompt, image_b64, want_json=True)
            return MealAnalysisResponse(**json.loads(text))
        except Exception:
            pass  # cae al fallback Ollama/mock

    # Intentar invocar a Ollama (llava)
    try:
        payload = {
            "model": OLLAMA_MODEL,
            "prompt": prompt,
            "images": [image_b64],
            "stream": False,
            "format": "json"
        }
        
        async with httpx.AsyncClient() as client:
            response = await client.post(f"{OLLAMA_HOST}/api/generate", json=payload, timeout=30.0)
            
            if response.status_code == 200:
                result = response.json()
                response_text = result.get("response", "")
                parsed_json = json.loads(response_text)
                return MealAnalysisResponse(**parsed_json)
    except Exception:
        # Registrar error silenciosamente y continuar al fallback
        pass
        
    # Mock fallback en caso de error o indisponibilidad de Ollama
    return MealAnalysisResponse(
        food_items=["pechuga de pollo a la plancha", "arroz integral", "brócoli al vapor"],
        calories=450,
        protein=35.0,
        carbohydrates=50.0,
        fat=10.0,
        confidence_score=0.90,
        notes="Estimación simulada (Mock). Ollama no está disponible o falló la decodificación. Plato equilibrado con alta proteína y carbohidratos complejos."
    )

@app.post("/identify-machine", response_model=MachineIdentificationResponse)
async def identify_machine(
    image_url: Optional[str] = Form(None),
    file: Optional[UploadFile] = File(None),
    ai: Optional[str] = Form(None),
):
    """
    Identifica la máquina de gimnasio a partir de una foto y retorna detalles y ejercicios.
    Si el cliente envía una AIConfig (F9), usa la visión multi-proveedor; si no, intenta
    Ollama (llava) y, en último caso, retorna un mock estructurado.
    """
    # Obtener imagen en base64
    image_b64 = await get_image_base64(image_url, file)

    prompt = (
        "Analyze this gym machine image. Identify the gym machine, describe its use, "
        "list target muscle groups, and provide a list of exercises associated with it.\n"
        "You must return ONLY a JSON object with this exact structure:\n"
        "{\n"
        '  "machine_name": "Name of the machine",\n'
        '  "description": "How the machine works and what it is used for",\n'
        '  "target_muscles": ["muscle1", "muscle2"],\n'
        '  "associated_exercises": ["exercise1", "exercise2"],\n'
        '  "safety_tips": ["tip1", "tip2"],\n'
        '  "confidence_score": 0.90\n'
        "}"
    )

    # Rama multi-proveedor (F9)
    cfg = _parse_ai_config(ai)
    if cfg is not None:
        try:
            text = ai_generate_vision(cfg, prompt, image_b64, want_json=True)
            return MachineIdentificationResponse(**json.loads(text))
        except Exception:
            pass

    # Intentar invocar a Ollama (llava)
    try:
        payload = {
            "model": OLLAMA_MODEL,
            "prompt": prompt,
            "images": [image_b64],
            "stream": False,
            "format": "json"
        }
        
        async with httpx.AsyncClient() as client:
            response = await client.post(f"{OLLAMA_HOST}/api/generate", json=payload, timeout=30.0)
            
            if response.status_code == 200:
                result = response.json()
                response_text = result.get("response", "")
                parsed_json = json.loads(response_text)
                return MachineIdentificationResponse(**parsed_json)
    except Exception:
        # Registrar error silenciosamente y continuar al fallback
        pass
        
    # Mock fallback en caso de error o indisponibilidad de Ollama
    return MachineIdentificationResponse(
        machine_name="Prensa de Piernas (Leg Press Machine)",
        description="Máquina de entrenamiento de fuerza con carga de discos o placas donde el usuario empuja una plataforma lejos de sí usando las piernas.",
        target_muscles=["Cuádriceps", "Glúteos", "Isquiotibiales", "Pantorrillas"],
        associated_exercises=["Prensa de piernas a 45 grados", "Prensa horizontal", "Prensa unilateral (una sola pierna)"],
        safety_tips=[
            "No extienda completamente ni bloquee las rodillas en la parte superior del movimiento.",
            "Mantenga la espalda baja firmemente apoyada contra el respaldo en todo momento.",
            "Comience con un peso moderado para asegurar el rango completo de movimiento."
        ],
        confidence_score=0.95
    )

# ============================================================================
# F8 — Chatbot de IA multi-proveedor
# ============================================================================

FITNESS_SYSTEM = (
    "Eres un asistente experto en nutrición y entrenamiento de la app Nutri-Fit. "
    "Responde en español, de forma concreta y accionable."
)


def _run_ai(cfg: AIConfig, prompt: str, want_json: bool = False) -> str:
    """Invoca la capa de IA y traduce sus errores a HTTP 503."""
    try:
        return ai_generate(cfg, prompt, want_json=want_json)
    except AIEngineError as exc:
        raise HTTPException(status_code=503, detail=str(exc))


def _parse_json_or_502(text: str) -> dict:
    """Parsea JSON del modelo o devuelve 502 si vino malformado."""
    try:
        return json.loads(text)
    except (json.JSONDecodeError, TypeError):
        raise HTTPException(status_code=502, detail="El proveedor devolvió un JSON inválido.")


class ChatRequest(BaseModel):
    message: str
    profile: Optional[dict] = None
    ai: AIConfig


class ChatResponse(BaseModel):
    reply: str


@app.post("/chat", response_model=ChatResponse)
def chat(req: ChatRequest):
    """Q&A conversacional de fitness/nutrición con contexto de perfil."""
    ctx = f"\nPerfil del usuario: {json.dumps(req.profile, ensure_ascii=False)}" if req.profile else ""
    prompt = f"{FITNESS_SYSTEM}{ctx}\n\nUsuario: {req.message}"
    return ChatResponse(reply=_run_ai(req.ai, prompt))


class MealPlanRequest(BaseModel):
    goals: dict = Field(..., description="target_calories y macros del usuario")
    preferences: Optional[str] = None
    ai: AIConfig


def _build_meal_plan(ai: AIConfig, goals: dict, preferences: Optional[str]) -> dict:
    """Genera un plan de comidas en JSON coherente con las metas del usuario."""
    prompt = (
        f"{FITNESS_SYSTEM}\nGenera un plan de comidas para UN día que cumpla estas metas: "
        f"{json.dumps(goals, ensure_ascii=False)}. "
        f"Preferencias: {preferences or 'ninguna'}.\n"
        "Devuelve SOLO un objeto JSON con esta forma exacta:\n"
        '{"meals": [{"meal_type": "breakfast|lunch|dinner|snack", "food_name": "str", '
        '"calories": num, "protein_g": num, "carbs_g": num, "fat_g": num, "serving_size_g": num}]}'
    )
    data = _parse_json_or_502(_run_ai(ai, prompt, want_json=True))
    if not isinstance(data.get("meals"), list) or not data["meals"]:
        raise HTTPException(status_code=502, detail="El plan de comidas no contiene 'meals'.")
    return data


@app.post("/generate-meal-plan")
def generate_meal_plan(req: MealPlanRequest):
    return _build_meal_plan(req.ai, req.goals, req.preferences)


def _fetch_exercise_candidates(body_part: Optional[str], equipment: Optional[str], limit: int = 40) -> List[dict]:
    """Consulta ejercicios reales del catálogo para acotar la elección del modelo."""
    conn = psycopg2.connect(DATABASE_URL, connect_timeout=5)
    try:
        with conn.cursor() as cur:
            query = "SELECT id, name, body_part, equipment FROM training.exercises WHERE TRUE"
            params: list = []
            if body_part:
                query += " AND body_part ILIKE %s"
                params.append(f"%{body_part}%")
            if equipment:
                query += " AND equipment ILIKE %s"
                params.append(f"%{equipment}%")
            query += " LIMIT %s"
            params.append(limit)
            cur.execute(query, params)
            return [
                {"id": r[0], "name": r[1], "body_part": r[2], "equipment": r[3]}
                for r in cur.fetchall()
            ]
    finally:
        conn.close()


class WorkoutPlanRequest(BaseModel):
    goal: Optional[str] = None
    body_part: Optional[str] = None
    equipment: Optional[str] = None
    ai: AIConfig


def _build_workout_plan(ai: AIConfig, goal: Optional[str], body_part: Optional[str], equipment: Optional[str]) -> dict:
    """Genera una rutina eligiendo SOLO ejercicios reales del catálogo."""
    candidates = _fetch_exercise_candidates(body_part, equipment)
    if not candidates:
        raise HTTPException(status_code=404, detail="No hay ejercicios que coincidan con el filtro.")
    valid_ids = {c["id"] for c in candidates}
    catalogo = json.dumps(candidates, ensure_ascii=False)
    prompt = (
        f"{FITNESS_SYSTEM}\nArma una rutina para el objetivo: {goal or 'general'}.\n"
        f"Elige ejercicios SOLO de este catálogo (usa exactamente sus id): {catalogo}\n"
        "Devuelve SOLO un objeto JSON con esta forma:\n"
        '{"items": [{"exercise_id": int, "sets": int, "reps": int, "rpe": num}]}'
    )
    data = _parse_json_or_502(_run_ai(ai, prompt, want_json=True))
    items = data.get("items")
    if not isinstance(items, list):
        raise HTTPException(status_code=502, detail="La rutina no contiene 'items'.")
    # Descartar ejercicios alucinados (id fuera del catálogo consultado)
    filtered = [it for it in items if it.get("exercise_id") in valid_ids]
    return {"items": filtered}


@app.post("/generate-workout-plan")
def generate_workout_plan(req: WorkoutPlanRequest):
    return _build_workout_plan(req.ai, req.goal, req.body_part, req.equipment)


class ChatPlanRequest(BaseModel):
    message: str
    profile: Optional[dict] = None
    ai: AIConfig


class ChatPlanResponse(BaseModel):
    reply: str
    workout: Optional[dict] = None
    meal_plan: Optional[dict] = None


def _extract_intent(ai: AIConfig, message: str) -> dict:
    """Usa el LLM para clasificar qué quiere el usuario (rutina/plan de comidas/equipo)."""
    prompt = (
        f"Analiza este mensaje de un usuario de una app de fitness: \"{message}\"\n"
        "Devuelve SOLO un JSON con esta forma exacta:\n"
        '{"wants_workout": bool, "wants_meal_plan": bool, '
        '"equipment": ["lista de implementos mencionados en texto libre"], '
        '"has_cardio_equipment": bool, '
        '"goal": "weight_loss|muscle_gain|maintenance", "preferences": "string o null"}'
    )
    return _parse_json_or_502(_run_ai(ai, prompt, want_json=True))


def _build_cardio_block(ai: AIConfig, equipment_list: list, goal: Optional[str]) -> str:
    """Describe un bloque de cardio en texto libre (nunca un exercise_id: el catálogo
    real no tiene equipo de cardio, así que inventar un id rompería el filtro
    anti-alucinación). Se arma localmente con reglas simples en vez de otra llamada
    al LLM: es determinista, gratis y suficiente para una frase descriptiva.
    """
    equipo = next((e for e in equipment_list if "caminadora" in e.lower() or "treadmill" in e.lower()), None)
    if not equipo:
        equipo = ", ".join(equipment_list) if equipment_list else "cardio"
    if goal == "weight_loss":
        return f"20-30 min en {equipo} a ritmo moderado (6-8 km/h), para maximizar el déficit calórico."
    return f"15-20 min en {equipo} a ritmo ligero-moderado como calentamiento o acondicionamiento."


class ProgressRequest(BaseModel):
    summary: dict = Field(..., description="adherencia calórica, macros, volumen semanal")
    ai: AIConfig


@app.post("/analyze-progress")
def analyze_progress(req: ProgressRequest):
    """Coach proactivo: analiza el progreso y da recomendaciones accionables."""
    prompt = (
        f"{FITNESS_SYSTEM}\nAnaliza este resumen de progreso del usuario y da 2-3 "
        f"recomendaciones accionables:\n{json.dumps(req.summary, ensure_ascii=False)}"
    )
    return {"analysis": _run_ai(req.ai, prompt)}


@app.post("/chat-plan", response_model=ChatPlanResponse)
def chat_plan(req: ChatPlanRequest):
    """Orquestador: interpreta un mensaje libre y arma rutina y/o plan de comidas."""
    intent = _extract_intent(req.ai, req.message)
    workout = meal_plan = None
    if intent.get("wants_workout"):
        equipment_mentioned = [e.lower() for e in intent.get("equipment", [])]
        equipment_real = "kettlebells" if any(
            "kettlebell" in e or "pesa rusa" in e for e in equipment_mentioned
        ) else None
        try:
            workout = _build_workout_plan(req.ai, intent.get("goal"), None, equipment_real)
        except HTTPException as exc:
            if exc.status_code != 404:
                raise
            # Sin equipo reconocible en el catálogo real: degradar en vez de tumbar
            # todo el endpoint (el usuario puede seguir queriendo su meal_plan).
            workout = {"items": []}
        if intent.get("has_cardio_equipment"):
            workout["cardio_block"] = _build_cardio_block(req.ai, intent.get("equipment", []), intent.get("goal"))
    if intent.get("wants_meal_plan"):
        # Sin profile (chat suelto), usamos el objetivo detectado en el mensaje como meta
        # mínima: un dict de goals vacío hace que el LLM rechace la petición (probado con
        # gemma4:e4b), y aquí no hay perfil real del que sacar target_calories/macros.
        goals = (req.profile or {}).get("goals") or {"objetivo": intent.get("goal") or "maintenance"}
        meal_plan = _build_meal_plan(req.ai, goals, intent.get("preferences"))
    reply = _run_ai(req.ai, f"{FITNESS_SYSTEM}\nResume en 2-3 frases, en español, qué generaste en respuesta a: \"{req.message}\"")
    return ChatPlanResponse(reply=reply, workout=workout, meal_plan=meal_plan)


# ============================================================================
# F12 — Gestión de Modelos Ollama (SF12.2)
# ============================================================================

def _native_ollama_host(base_url: Optional[str]) -> str:
    """Deriva el host nativo de Ollama a partir de un base_url que puede venir
    con el sufijo /v1 (modo OpenAI-compatible) o sin él."""
    url = (base_url or OLLAMA_HOST).rstrip("/")
    return url[:-3] if url.endswith("/v1") else url


@app.get("/ollama/models")
async def list_ollama_models(base_url: Optional[str] = None):
    """Lista los modelos instalados en el servidor Ollama nativo."""
    host = _native_ollama_host(base_url)
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(f"{host}/api/tags", timeout=5.0)
            response.raise_for_status()
            data = response.json()
            return {"models": [{"name": m["name"], "size": m.get("size")} for m in data.get("models", [])]}
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"No se pudo listar modelos de Ollama en {host}: {e}")


_ollama_pull_status: dict[str, dict] = {}  # en memoria, MVP
# ponytail: estado de pull en memoria de proceso (se pierde en restart/multi-worker);
# subir a Redis/DB si se necesita persistencia o escalar a más de un worker.


async def _run_ollama_pull(host: str, model: str) -> None:
    """Ejecuta `ollama pull` vía streaming NDJSON y guarda el progreso en memoria."""
    _ollama_pull_status[model] = {"status": "starting", "done": False}
    try:
        async with httpx.AsyncClient(timeout=None) as client:
            async with client.stream("POST", f"{host}/api/pull", json={"name": model, "stream": True}) as resp:
                async for line in resp.aiter_lines():
                    if not line:
                        continue
                    chunk = json.loads(line)
                    status = chunk.get("status", "")
                    _ollama_pull_status[model] = {
                        "status": status,
                        "done": status == "success",
                        "completed": chunk.get("completed"),
                        "total": chunk.get("total"),
                    }
    except Exception as e:
        _ollama_pull_status[model] = {"status": f"error: {e}", "done": True, "error": True}


class OllamaPullRequest(BaseModel):
    model: str
    base_url: Optional[str] = None


@app.post("/ollama/pull")
async def pull_ollama_model(req: OllamaPullRequest, background_tasks: BackgroundTasks):
    """Dispara la descarga de un modelo Ollama en segundo plano."""
    host = _native_ollama_host(req.base_url)
    background_tasks.add_task(_run_ollama_pull, host, req.model)
    return {"started": True, "model": req.model}


@app.get("/ollama/pull-status")
def get_ollama_pull_status(model: str):
    """Consulta el progreso de una descarga de modelo en curso."""
    return _ollama_pull_status.get(model, {"status": "not_started", "done": False})


# Configurar el servicio de archivos estáticos para producción si la carpeta existe
static_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "static")
if os.path.exists(static_dir):
    from fastapi.staticfiles import StaticFiles
    app.mount("/", StaticFiles(directory=static_dir, html=True), name="static")
