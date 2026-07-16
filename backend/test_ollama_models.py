"""Tests de gestión de modelos Ollama (SF12.2): listar y descargar modelos."""

from __future__ import annotations

import json

import pytest
from fastapi.testclient import TestClient

import app.main as main
from app.main import app, _native_ollama_host, _run_ollama_pull, _ollama_pull_status

client = TestClient(app)


# --- _native_ollama_host ---

def test_native_host_quita_sufijo_v1():
    assert _native_ollama_host("http://foo:11434/v1") == "http://foo:11434"


def test_native_host_sin_sufijo_v1_queda_igual():
    assert _native_ollama_host("http://foo:11434") == "http://foo:11434"


def test_native_host_none_usa_default():
    assert _native_ollama_host(None) == main.OLLAMA_HOST


# --- GET /ollama/models ---

class _FakeResponse:
    def __init__(self, payload):
        self._payload = payload

    def raise_for_status(self):
        pass

    def json(self):
        return self._payload


class _FakeAsyncClient:
    def __init__(self, *a, **k):
        pass

    async def __aenter__(self):
        return self

    async def __aexit__(self, *a):
        return False

    async def get(self, url, timeout=None):
        return _FakeResponse({"models": [{"name": "qwen2.5:3b", "size": 123}, {"name": "llama3.2:latest", "size": 456}]})


def test_list_models_ok(monkeypatch):
    monkeypatch.setattr(main.httpx, "AsyncClient", _FakeAsyncClient)
    r = client.get("/ollama/models")
    assert r.status_code == 200
    assert r.json() == {"models": [{"name": "qwen2.5:3b", "size": 123}, {"name": "llama3.2:latest", "size": 456}]}


def test_list_models_con_base_url_v1(monkeypatch):
    seen = {}

    class RecordingClient(_FakeAsyncClient):
        async def get(self, url, timeout=None):
            seen["url"] = url
            return _FakeResponse({"models": []})

    monkeypatch.setattr(main.httpx, "AsyncClient", RecordingClient)
    r = client.get("/ollama/models", params={"base_url": "http://otro:11434/v1"})
    assert r.status_code == 200
    assert seen["url"] == "http://otro:11434/api/tags"


class _FailingAsyncClient:
    def __init__(self, *a, **k):
        pass

    async def __aenter__(self):
        return self

    async def __aexit__(self, *a):
        return False

    async def get(self, url, timeout=None):
        raise ConnectionError("conexión rechazada")


def test_list_models_503_si_falla_conexion(monkeypatch):
    monkeypatch.setattr(main.httpx, "AsyncClient", _FailingAsyncClient)
    r = client.get("/ollama/models")
    assert r.status_code == 503
    assert "No se pudo listar modelos" in r.json()["detail"]


# --- _run_ollama_pull / GET /ollama/pull-status ---

class _FakeStreamResponse:
    def __init__(self, lines):
        self._lines = lines

    async def aiter_lines(self):
        for line in self._lines:
            yield line


class _FakeStreamCtx:
    def __init__(self, resp):
        self._resp = resp

    async def __aenter__(self):
        return self._resp

    async def __aexit__(self, *a):
        return False


class _FakePullClient:
    def __init__(self, *a, **k):
        pass

    async def __aenter__(self):
        return self

    async def __aexit__(self, *a):
        return False

    def stream(self, method, url, json=None):
        lines = [
            '{"status": "pulling manifest"}',
            '{"status": "verifying digest"}',
            '{"status": "success"}',
        ]
        return _FakeStreamCtx(_FakeStreamResponse(lines))


@pytest.mark.anyio
async def test_run_pull_termina_en_success(monkeypatch):
    monkeypatch.setattr(main.httpx, "AsyncClient", _FakePullClient)
    await _run_ollama_pull("http://host:11434", "qwen2.5:3b")
    status = _ollama_pull_status["qwen2.5:3b"]
    assert status["done"] is True
    assert status["status"] == "success"


class _FailingPullClient:
    def __init__(self, *a, **k):
        pass

    async def __aenter__(self):
        return self

    async def __aexit__(self, *a):
        return False

    def stream(self, method, url, json=None):
        raise ConnectionError("red caída")


@pytest.mark.anyio
async def test_run_pull_error_de_red_no_cuelga(monkeypatch):
    monkeypatch.setattr(main.httpx, "AsyncClient", _FailingPullClient)
    await _run_ollama_pull("http://host:11434", "modelo-roto")
    status = _ollama_pull_status["modelo-roto"]
    assert status["done"] is True
    assert status["error"] is True


def test_pull_status_modelo_nunca_pedido():
    r = client.get("/ollama/pull-status", params={"model": "algo-nunca-pedido"})
    assert r.status_code == 200
    assert r.json() == {"status": "not_started", "done": False}


@pytest.fixture
def anyio_backend():
    return "asyncio"
