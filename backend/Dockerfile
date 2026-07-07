# Etapa 1: Constructor de dependencias
FROM python:3.11-slim AS builder

WORKDIR /app

COPY requirements.txt .

# Instalar las dependencias en la carpeta local del usuario para no contaminar la imagen final
RUN pip install --user --no-cache-dir -r requirements.txt

# Etapa 2: Imagen final limpia
FROM python:3.11-slim

WORKDIR /app

# Copiar las dependencias instaladas del constructor
COPY --from=builder /root/.local /root/.local
COPY . .

# Asegurar que el PATH incluya los binarios de python instalados en .local
ENV PATH=/root/.local/bin:$PATH

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
