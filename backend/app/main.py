import os
from fastapi import FastAPI, HTTPException
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
