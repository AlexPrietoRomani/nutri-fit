"""Capa de IA multi-proveedor para Nutri-Fit.

Enruta las peticiones de generación a cualquiera de los proveedores soportados
según la configuración que llega por request (``AIConfig``):

- **OpenAI-compatible** (OpenAI, OpenRouter, Google Gemini, LM Studio, vLLM,
  Ollama): un único cliente ``openai`` con ``base_url`` distinto por proveedor.
- **Anthropic/Claude**: SDK nativo ``anthropic`` (modelo por defecto
  ``claude-opus-4-8``).

El servicio es *stateless*: las claves llegan por request (el cliente las guarda
en almacenamiento seguro) y nunca se persisten aquí. Los ``base_url`` por defecto
se pueden sobreescribir por request o por variable de entorno.
"""

from __future__ import annotations

import os
from typing import Optional

from pydantic import BaseModel, Field

# ``host.docker.internal`` permite que el contenedor alcance servidores locales
# del host (LM Studio, vLLM) cuando docker-compose declara el extra_host.
OPENAI_BASE_URLS: dict[str, str] = {
    "openai": "https://api.openai.com/v1",
    "openrouter": "https://openrouter.ai/api/v1",
    "gemini": "https://generativelanguage.googleapis.com/v1beta/openai/",
    "lmstudio": os.getenv("LMSTUDIO_URL", "http://host.docker.internal:1234/v1"),
    "vllm": os.getenv("VLLM_URL", "http://host.docker.internal:8000/v1"),
    "ollama": f"{os.getenv('OLLAMA_HOST', 'http://ollama:11434')}/v1",
}

# Proveedores que hablan el protocolo OpenAI-compatible.
OPENAI_COMPATIBLE = set(OPENAI_BASE_URLS.keys())
# Todos los proveedores soportados (incluye el nativo de Anthropic).
SUPPORTED_PROVIDERS = OPENAI_COMPATIBLE | {"claude"}

DEFAULT_CLAUDE_MODEL = "claude-opus-4-8"


class AIConfig(BaseModel):
    """Configuración de IA enviada por el cliente en cada request."""

    provider: str = Field(..., description="openai|openrouter|gemini|lmstudio|vllm|ollama|claude")
    api_key: Optional[str] = Field(None, description="Clave del proveedor (o token dummy para locales)")
    base_url: Optional[str] = Field(None, description="Sobrescribe el base_url por defecto del proveedor")
    model: Optional[str] = Field(None, description="Identificador del modelo a usar")


class AIEngineError(RuntimeError):
    """Error de la capa de IA (proveedor no soportado o fallo del proveedor)."""


def _resolve_base_url(cfg: AIConfig) -> str:
    """Devuelve el base_url efectivo para un proveedor OpenAI-compatible."""
    if cfg.base_url:
        return cfg.base_url
    return OPENAI_BASE_URLS[cfg.provider]


def _generate_openai_compatible(cfg: AIConfig, prompt: str, want_json: bool) -> str:
    """Genera texto vía un endpoint OpenAI-compatible."""
    from openai import OpenAI

    client = OpenAI(api_key=cfg.api_key or "not-needed", base_url=_resolve_base_url(cfg))
    kwargs: dict = {}
    if want_json:
        kwargs["response_format"] = {"type": "json_object"}
    response = client.chat.completions.create(
        model=cfg.model or "",
        messages=[{"role": "user", "content": prompt}],
        **kwargs,
    )
    return response.choices[0].message.content or ""


def _generate_anthropic(cfg: AIConfig, prompt: str, want_json: bool) -> str:
    """Genera texto vía el SDK nativo de Anthropic (Claude)."""
    import anthropic

    # Si no hay api_key en el request, el SDK usa ANTHROPIC_API_KEY del entorno.
    client = anthropic.Anthropic(api_key=cfg.api_key) if cfg.api_key else anthropic.Anthropic()
    response = client.messages.create(
        model=cfg.model or DEFAULT_CLAUDE_MODEL,
        max_tokens=2048,
        messages=[{"role": "user", "content": prompt}],
    )
    return next((block.text for block in response.content if block.type == "text"), "")


def generate(cfg: AIConfig, prompt: str, want_json: bool = False) -> str:
    """Enruta la generación al proveedor indicado en ``cfg``.

    Lanza ``AIEngineError`` si el proveedor no es válido o si el proveedor falla.
    """
    if cfg.provider not in SUPPORTED_PROVIDERS:
        raise AIEngineError(
            f"Proveedor no soportado: '{cfg.provider}'. "
            f"Válidos: {', '.join(sorted(SUPPORTED_PROVIDERS))}."
        )
    try:
        if cfg.provider == "claude":
            return _generate_anthropic(cfg, prompt, want_json)
        return _generate_openai_compatible(cfg, prompt, want_json)
    except AIEngineError:
        raise
    except Exception as exc:  # noqa: BLE001 - se envuelve para dar un 503 claro
        raise AIEngineError(f"Fallo del proveedor '{cfg.provider}': {exc}") from exc


def _vision_openai_compatible(cfg: AIConfig, prompt: str, image_b64: str, want_json: bool) -> str:
    """Análisis de imagen vía endpoint OpenAI-compatible (content block image_url)."""
    from openai import OpenAI

    client = OpenAI(api_key=cfg.api_key or "not-needed", base_url=_resolve_base_url(cfg))
    content = [
        {"type": "text", "text": prompt},
        {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{image_b64}"}},
    ]
    kwargs: dict = {}
    if want_json:
        kwargs["response_format"] = {"type": "json_object"}
    response = client.chat.completions.create(
        model=cfg.model or "",
        messages=[{"role": "user", "content": content}],
        **kwargs,
    )
    return response.choices[0].message.content or ""


def _vision_anthropic(cfg: AIConfig, prompt: str, image_b64: str, want_json: bool) -> str:
    """Análisis de imagen vía SDK nativo de Anthropic (bloque image base64)."""
    import anthropic

    client = anthropic.Anthropic(api_key=cfg.api_key) if cfg.api_key else anthropic.Anthropic()
    response = client.messages.create(
        model=cfg.model or DEFAULT_CLAUDE_MODEL,
        max_tokens=1024,
        messages=[{
            "role": "user",
            "content": [
                {"type": "image", "source": {"type": "base64", "media_type": "image/jpeg", "data": image_b64}},
                {"type": "text", "text": prompt},
            ],
        }],
    )
    return next((block.text for block in response.content if block.type == "text"), "")


def generate_vision(cfg: AIConfig, prompt: str, image_b64: str, want_json: bool = False) -> str:
    """Analiza una imagen (base64) enrutando al proveedor de ``cfg``.

    Mismo enrutamiento que ``generate`` pero con contenido multimodal.
    """
    if cfg.provider not in SUPPORTED_PROVIDERS:
        raise AIEngineError(
            f"Proveedor no soportado: '{cfg.provider}'. "
            f"Válidos: {', '.join(sorted(SUPPORTED_PROVIDERS))}."
        )
    try:
        if cfg.provider == "claude":
            return _vision_anthropic(cfg, prompt, image_b64, want_json)
        return _vision_openai_compatible(cfg, prompt, image_b64, want_json)
    except AIEngineError:
        raise
    except Exception as exc:  # noqa: BLE001
        raise AIEngineError(f"Fallo de visión del proveedor '{cfg.provider}': {exc}") from exc
