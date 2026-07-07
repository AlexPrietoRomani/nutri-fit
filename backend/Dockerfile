# --- ETAPA 1: Construir el Frontend Flutter Web ---
FROM debian:stable-slim AS frontend-builder

WORKDIR /flutter-src

# Instalar dependencias necesarias para descargar y configurar Flutter
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git unzip xz-utils zip ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Descargar Flutter SDK estable
RUN git clone https://github.com/flutter/flutter.git -b stable /flutter-src/flutter
ENV PATH="/flutter-src/flutter/bin:/flutter-src/flutter/bin/cache/dart-sdk/bin:${PATH}"
RUN flutter doctor

WORKDIR /app
# Copiar el código del frontend
COPY frontend/ .
# Configurar la plataforma web para el proyecto
RUN flutter create . --platforms web
# Construir Flutter Web en release
RUN flutter build web --release

# --- ETAPA 2: Constructor de dependencias de Python ---
FROM python:3.11-slim AS python-builder

WORKDIR /app
COPY backend/requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

# --- ETAPA 3: Imagen de producción final ---
FROM python:3.11-slim

WORKDIR /app

# Copiar las dependencias de Python instaladas
COPY --from=python-builder /root/.local /root/.local

# Copiar el código del backend
COPY backend/ .

# Copiar el frontend web compilado a la carpeta /app/static para que FastAPI lo sirva en la raíz
COPY --from=frontend-builder /app/build/web ./static

# Asegurar que el PATH incluya los binarios de python instalados en .local
ENV PATH=/root/.local/bin:$PATH

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
