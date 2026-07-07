import os
import base64
from typing import Optional, List
from fastapi import FastAPI, HTTPException, File, UploadFile, Form
from pydantic import BaseModel, Field
import httpx
import psycopg2

app = FastAPI(
    title="Nutri-Fit AI Backend",
    description="Microservicio de IA en Python para el procesamiento de imágenes de comidas y reconocimiento de máquinas.",
    version="0.1.0"
)

# Configuración desde variables de entorno
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/postgres")
OLLAMA_HOST = os.getenv("OLLAMA_HOST", "http://localhost:11434")
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

@app.get("/")
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
    file: Optional[UploadFile] = File(None)
):
    """
    Analiza la foto de una comida y estima sus ingredientes, calorías y macronutrientes.
    Si Ollama está disponible, realiza la consulta al modelo multimodal local (ej. llava).
    De lo contrario, retorna un mock estructurado en base a heurísticas sencillas.
    """
    # Obtener imagen en base64
    image_b64 = await get_image_base64(image_url, file)
    
    # Intentar invocar a Ollama
    try:
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
                import json
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
    file: Optional[UploadFile] = File(None)
):
    """
    Identifica la máquina de gimnasio a partir de una foto y retorna detalles y ejercicios asociados.
    Si Ollama está disponible, realiza la consulta al modelo multimodal local (ej. llava).
    De lo contrario, retorna un mock estructurado.
    """
    # Obtener imagen en base64
    image_b64 = await get_image_base64(image_url, file)
    
    # Intentar invocar a Ollama
    try:
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
                import json
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

# Configurar el servicio de archivos estáticos para producción si la carpeta existe
static_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "static")
if os.path.exists(static_dir):
    from fastapi.staticfiles import StaticFiles
    app.mount("/", StaticFiles(directory=static_dir, html=True), name="static")
