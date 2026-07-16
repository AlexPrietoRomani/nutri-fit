"""Tests unitarios de la capa de IA multi-proveedor (T8.1.1).

Los SDK ``openai`` y ``anthropic`` se inyectan como módulos falsos en
``sys.modules`` para poder testear el enrutamiento sin instalarlos ni tocar la
red.
"""

from __future__ import annotations

import sys
import types

import pytest

from app.ai_engine import AIConfig, AIEngineError, OPENAI_BASE_URLS, generate


@pytest.fixture
def fake_sdks(monkeypatch):
    """Inyecta módulos falsos de openai y anthropic y captura las llamadas."""
    capture: dict = {}

    # --- Fake openai ---
    openai_mod = types.ModuleType("openai")

    class _FakeCompletions:
        def create(self, model, messages, **kwargs):
            capture["openai_model"] = model
            capture["openai_messages"] = messages
            capture["openai_kwargs"] = kwargs
            msg = types.SimpleNamespace(content="OPENAI_REPLY")
            return types.SimpleNamespace(choices=[types.SimpleNamespace(message=msg)])

    class _FakeOpenAI:
        def __init__(self, api_key=None, base_url=None):
            capture["openai_api_key"] = api_key
            capture["openai_base_url"] = base_url
            self.chat = types.SimpleNamespace(completions=_FakeCompletions())

    openai_mod.OpenAI = _FakeOpenAI
    monkeypatch.setitem(sys.modules, "openai", openai_mod)

    # --- Fake anthropic ---
    anthropic_mod = types.ModuleType("anthropic")

    class _FakeMessages:
        def create(self, model, max_tokens, messages):
            capture["anthropic_model"] = model
            capture["anthropic_messages"] = messages
            block = types.SimpleNamespace(type="text", text="CLAUDE_REPLY")
            return types.SimpleNamespace(content=[block])

    class _FakeAnthropic:
        def __init__(self, api_key=None):
            capture["anthropic_api_key"] = api_key
            self.messages = _FakeMessages()

    anthropic_mod.Anthropic = _FakeAnthropic
    monkeypatch.setitem(sys.modules, "anthropic", anthropic_mod)

    return capture


def test_claude_usa_rama_anthropic(fake_sdks):
    cfg = AIConfig(provider="claude", api_key="sk-ant", model="claude-opus-4-8")
    out = generate(cfg, "hola")
    assert out == "CLAUDE_REPLY"
    assert fake_sdks["anthropic_model"] == "claude-opus-4-8"
    assert fake_sdks["anthropic_api_key"] == "sk-ant"


def test_claude_modelo_por_defecto(fake_sdks):
    cfg = AIConfig(provider="claude", api_key="sk-ant")  # sin model
    generate(cfg, "hola")
    assert fake_sdks["anthropic_model"] == "claude-opus-4-8"


@pytest.mark.parametrize("provider", sorted(OPENAI_BASE_URLS.keys()))
def test_proveedores_openai_compatible(fake_sdks, provider):
    cfg = AIConfig(provider=provider, api_key="k", model="some-model")
    out = generate(cfg, "hola")
    assert out == "OPENAI_REPLY"
    # usa el base_url por defecto del proveedor
    assert fake_sdks["openai_base_url"] == OPENAI_BASE_URLS[provider]
    assert fake_sdks["openai_model"] == "some-model"


def test_base_url_override(fake_sdks):
    cfg = AIConfig(provider="vllm", model="m", base_url="http://mi-vllm:9000/v1")
    generate(cfg, "hola")
    assert fake_sdks["openai_base_url"] == "http://mi-vllm:9000/v1"


def test_want_json_pide_response_format(fake_sdks):
    cfg = AIConfig(provider="openai", api_key="k", model="gpt-x")
    generate(cfg, "dame json", want_json=True)
    assert fake_sdks["openai_kwargs"].get("response_format") == {"type": "json_object"}


def test_proveedor_invalido_lanza(fake_sdks):
    cfg = AIConfig(provider="inexistente", model="m")
    with pytest.raises(AIEngineError):
        generate(cfg, "hola")


def test_vision_claude_usa_bloque_image(fake_sdks):
    from app.ai_engine import generate_vision
    cfg = AIConfig(provider="claude", api_key="k", model="claude-opus-4-8")
    out = generate_vision(cfg, "describe", "BASE64DATA")
    assert out == "CLAUDE_REPLY"
    content = fake_sdks["anthropic_messages"][0]["content"]
    types_in_content = [b["type"] for b in content]
    assert "image" in types_in_content
    img = next(b for b in content if b["type"] == "image")
    assert img["source"]["data"] == "BASE64DATA"


@pytest.mark.parametrize("provider", ["openai", "gemini", "ollama"])
def test_vision_openai_compatible_usa_image_url(fake_sdks, provider):
    from app.ai_engine import generate_vision
    cfg = AIConfig(provider=provider, api_key="k", model="m")
    out = generate_vision(cfg, "describe", "BASE64DATA")
    assert out == "OPENAI_REPLY"
    content = fake_sdks["openai_messages"][0]["content"]
    kinds = [b["type"] for b in content]
    assert "image_url" in kinds
    img = next(b for b in content if b["type"] == "image_url")
    assert "BASE64DATA" in img["image_url"]["url"]


def test_vision_proveedor_invalido_lanza(fake_sdks):
    from app.ai_engine import generate_vision
    cfg = AIConfig(provider="inexistente", model="m")
    with pytest.raises(AIEngineError):
        generate_vision(cfg, "describe", "B64")


def test_fallo_de_proveedor_se_envuelve(monkeypatch):
    # openai que revienta al crear el cliente -> AIEngineError
    openai_mod = types.ModuleType("openai")

    class _Boom:
        def __init__(self, *a, **k):
            raise ConnectionError("sin red")

    openai_mod.OpenAI = _Boom
    monkeypatch.setitem(sys.modules, "openai", openai_mod)

    cfg = AIConfig(provider="openai", api_key="k", model="m")
    with pytest.raises(AIEngineError):
        generate(cfg, "hola")
