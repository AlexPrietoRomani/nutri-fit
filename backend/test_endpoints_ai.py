"""Tests de los endpoints de IA (SF8.2), mockeando la capa de IA y el catálogo."""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

import app.main as main
from app.main import app
from app.ai_engine import AIEngineError

client = TestClient(app)
AICFG = {"provider": "openai", "api_key": "k", "model": "m"}


def test_chat_ok(monkeypatch):
    monkeypatch.setattr(main, "ai_generate", lambda cfg, prompt, want_json=False: "¡hola!")
    r = client.post("/chat", json={"message": "hola", "ai": AICFG})
    assert r.status_code == 200
    assert r.json()["reply"] == "¡hola!"


def test_chat_503_cuando_motor_falla(monkeypatch):
    def boom(*a, **k):
        raise AIEngineError("ningún proveedor disponible")

    monkeypatch.setattr(main, "ai_generate", boom)
    r = client.post("/chat", json={"message": "hola", "ai": AICFG})
    assert r.status_code == 503


def test_meal_plan_ok(monkeypatch):
    monkeypatch.setattr(
        main, "ai_generate",
        lambda *a, **k: '{"meals":[{"meal_type":"lunch","food_name":"Pollo","calories":400,'
                        '"protein_g":40,"carbs_g":30,"fat_g":10,"serving_size_g":300}]}',
    )
    r = client.post("/generate-meal-plan", json={"goals": {"target_calories": 1800}, "ai": AICFG})
    assert r.status_code == 200
    assert len(r.json()["meals"]) == 1


def test_meal_plan_json_invalido_502(monkeypatch):
    monkeypatch.setattr(main, "ai_generate", lambda *a, **k: "esto no es json")
    r = client.post("/generate-meal-plan", json={"goals": {}, "ai": AICFG})
    assert r.status_code == 502


def test_workout_filtra_ids_alucinados(monkeypatch):
    monkeypatch.setattr(
        main, "_fetch_exercise_candidates",
        lambda bp, eq, limit=40: [
            {"id": 1, "name": "Press", "body_part": "chest", "equipment": "dumbbell"},
            {"id": 2, "name": "Fly", "body_part": "chest", "equipment": "dumbbell"},
        ],
    )
    monkeypatch.setattr(
        main, "ai_generate",
        lambda *a, **k: '{"items":[{"exercise_id":1,"sets":3,"reps":10,"rpe":8},'
                        '{"exercise_id":999,"sets":3,"reps":10}]}',
    )
    r = client.post("/generate-workout-plan", json={"body_part": "chest", "ai": AICFG})
    assert r.status_code == 200
    ids = [it["exercise_id"] for it in r.json()["items"]]
    assert ids == [1]  # 999 (alucinado) descartado


def test_workout_sin_candidatos_404(monkeypatch):
    monkeypatch.setattr(main, "_fetch_exercise_candidates", lambda bp, eq, limit=40: [])
    r = client.post("/generate-workout-plan", json={"body_part": "zzz", "ai": AICFG})
    assert r.status_code == 404


def test_progress_ok(monkeypatch):
    monkeypatch.setattr(main, "ai_generate", lambda *a, **k: "Sube 100 kcal y descansa más.")
    r = client.post("/analyze-progress", json={"summary": {"deficit_sostenido": True}, "ai": AICFG})
    assert r.status_code == 200
    assert "analysis" in r.json()


# --- F9: visión ---
import json as _json

_IMG = {"file": ("meal.jpg", b"\xff\xd8\xff\xe0fakejpeg", "image/jpeg")}


def test_analyze_meal_con_ai(monkeypatch):
    reply = _json.dumps({
        "food_items": ["huevo", "avena"], "calories": 400, "protein": 25.0,
        "carbohydrates": 45.0, "fat": 12.0, "confidence_score": 0.8, "notes": "ok",
    })
    monkeypatch.setattr(main, "ai_generate_vision", lambda *a, **k: reply)
    r = client.post("/analyze-meal", files=_IMG, data={"ai": _json.dumps(AICFG)})
    assert r.status_code == 200
    assert r.json()["food_items"] == ["huevo", "avena"]
    assert r.json()["calories"] == 400


def test_analyze_meal_sin_ai_cae_a_mock(monkeypatch):
    # Sin config y sin Ollama alcanzable -> mock (200, no crash)
    r = client.post("/analyze-meal", files=_IMG)
    assert r.status_code == 200
    assert "food_items" in r.json()


# --- F11: /chat-plan (orquestador) ---

def test_chat_plan_workout_y_meal(monkeypatch):
    monkeypatch.setattr(
        main, "_fetch_exercise_candidates",
        lambda bp, eq, limit=40: [
            {"id": 5, "name": "Swing", "body_part": "full_body", "equipment": "kettlebells"},
        ],
    )
    calls = {"n": 0}

    def fake_ai(cfg, prompt, want_json=False):
        calls["n"] += 1
        if calls["n"] == 1:  # _extract_intent
            return _json.dumps({
                "wants_workout": True, "wants_meal_plan": True,
                "equipment": ["caminadora", "pesa rusa"], "has_cardio_equipment": True,
                "goal": "weight_loss", "preferences": None,
            })
        if calls["n"] == 2:  # _build_workout_plan
            return '{"items":[{"exercise_id":5,"sets":3,"reps":15,"rpe":7}]}'
        if calls["n"] == 3:  # _build_meal_plan
            return '{"meals":[{"meal_type":"lunch","food_name":"Pollo","calories":400,' \
                   '"protein_g":40,"carbs_g":30,"fat_g":10,"serving_size_g":300}]}'
        return "Listo, aquí tienes tu rutina y plan de comidas."

    monkeypatch.setattr(main, "ai_generate", fake_ai)
    r = client.post("/chat-plan", json={"message": "caminadora y pesa rusa, bajar de peso, y desayuno/almuerzo/cena", "ai": AICFG})
    assert r.status_code == 200
    body = r.json()
    assert body["workout"]["items"] == [{"exercise_id": 5, "sets": 3, "reps": 15, "rpe": 7, "name": "Swing"}]
    assert "cardio_block" in body["workout"]
    assert len(body["meal_plan"]["meals"]) == 1


def test_chat_plan_solo_meal_plan(monkeypatch):
    def fake_ai(cfg, prompt, want_json=False):
        if "wants_workout" in prompt:
            return _json.dumps({
                "wants_workout": False, "wants_meal_plan": True,
                "equipment": [], "has_cardio_equipment": False,
                "goal": "maintenance", "preferences": None,
            })
        if "meals" in prompt:
            return '{"meals":[{"meal_type":"dinner","food_name":"Pescado","calories":350,' \
                   '"protein_g":35,"carbs_g":20,"fat_g":8,"serving_size_g":250}]}'
        return "Aquí tienes tu plan de comidas."

    monkeypatch.setattr(main, "ai_generate", fake_ai)
    r = client.post("/chat-plan", json={"message": "quiero un plan de comidas", "ai": AICFG})
    assert r.status_code == 200
    body = r.json()
    assert body["workout"] is None
    assert body["meal_plan"] is not None


def test_chat_plan_degrada_sin_equipo_reconocido(monkeypatch):
    monkeypatch.setattr(main, "_fetch_exercise_candidates", lambda bp, eq, limit=40: [])

    def fake_ai(cfg, prompt, want_json=False):
        if "wants_workout" in prompt:
            return _json.dumps({
                "wants_workout": True, "wants_meal_plan": False,
                "equipment": ["banda elástica"], "has_cardio_equipment": False,
                "goal": "muscle_gain", "preferences": None,
            })
        return "Aquí tienes lo que pude armar."

    monkeypatch.setattr(main, "ai_generate", fake_ai)
    r = client.post("/chat-plan", json={"message": "solo tengo una banda elástica", "ai": AICFG})
    assert r.status_code == 200
    assert r.json()["workout"] == {"items": []}


def test_identify_machine_con_ai(monkeypatch):
    reply = _json.dumps({
        "machine_name": "Leg Press", "description": "empuje de piernas",
        "target_muscles": ["cuádriceps"], "associated_exercises": ["prensa"],
        "safety_tips": ["no bloquear rodillas"], "confidence_score": 0.9,
    })
    monkeypatch.setattr(main, "ai_generate_vision", lambda *a, **k: reply)
    r = client.post("/identify-machine", files=_IMG, data={"ai": _json.dumps(AICFG)})
    assert r.status_code == 200
    assert r.json()["machine_name"] == "Leg Press"
