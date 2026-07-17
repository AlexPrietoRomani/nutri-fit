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
        raise AssertionError("no debe haber una 4a llamada al LLM (reply es determinista, SF13.1/T13.2.2)")

    monkeypatch.setattr(main, "ai_generate", fake_ai)
    r = client.post("/chat-plan", json={"message": "caminadora y pesa rusa, bajar de peso, y desayuno/almuerzo/cena", "ai": AICFG})
    assert r.status_code == 200
    body = r.json()
    assert body["workout"]["items"] == [{"exercise_id": 5, "sets": 3, "reps": 15, "rpe": 7, "name": "Swing"}]
    assert "cardio_block" in body["workout"]
    assert len(body["meal_plan"]["meals"]) == 1
    # Solo 3 llamadas reales al LLM: extraer intención + generar rutina + generar
    # plan de comidas. Ya no hay una 4a llamada pidiendo "resumir qué generaste"
    # (esa era la causa de la alucinación de guardado, ver SF13.1/T13.2.2).
    assert calls["n"] == 3
    # El reply es determinista y jamás afirma una acción de guardado que no ocurrió
    # (solo puede mencionar el botón "Guardar rutina", nunca decir que ya se guardó).
    assert "se guardó" not in body["reply"].lower()
    assert "cargó" not in body["reply"].lower()
    assert body["reply"] == (
        "Aquí tienes tu rutina sugerida. Usa el botón 'Guardar rutina' si quieres conservarla. "
        "Y tu plan de comidas para hoy."
    )


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


def test_extract_intent_usa_historial_para_resolver_referencia(monkeypatch):
    # El turno previo fue de comida; "hazlo a 3 semanas" debe resolverse como
    # plan de comida (no rutina) gracias al historial (bug T18.1.1).
    prompts = []

    def fake_ai(cfg, prompt, want_json=False):
        prompts.append(prompt)
        return _json.dumps({
            "wants_workout": False, "wants_meal_plan": True,
            "equipment": [], "has_cardio_equipment": False,
            "goal": "maintenance", "preferences": None,
        })

    monkeypatch.setattr(main, "ai_generate", fake_ai)
    history = [
        {"role": "user", "text": "dame un plan de comida"},
        {"role": "assistant", "text": "Aquí tienes tu plan de comidas para hoy."},
    ]
    intent = main._extract_intent(main.AIConfig(**AICFG), "hazlo a 3 semanas", history)
    assert intent["wants_meal_plan"] is True
    assert intent["wants_workout"] is False
    # El historial debe llegar al prompt de extracción.
    assert "plan de comida" in prompts[0]
    assert "asistente:" in prompts[0]


def test_chat_plan_con_historial_resuelve_meal_no_workout(monkeypatch):
    def fake_ai(cfg, prompt, want_json=False):
        if "wants_workout" in prompt:
            assert "plan de comida" in prompt  # historial presente en el prompt
            return _json.dumps({
                "wants_workout": False, "wants_meal_plan": True,
                "equipment": [], "has_cardio_equipment": False,
                "goal": "maintenance", "preferences": None,
            })
        return '{"meals":[{"meal_type":"dinner","food_name":"Pescado","calories":350,' \
               '"protein_g":35,"carbs_g":20,"fat_g":8,"serving_size_g":250}]}'

    monkeypatch.setattr(main, "ai_generate", fake_ai)
    r = client.post("/chat-plan", json={
        "message": "hazlo a 3 semanas",
        "history": [
            {"role": "user", "text": "dame un plan de comida"},
            {"role": "assistant", "text": "Aquí tienes tu plan de comidas."},
        ],
        "ai": AICFG,
    })
    assert r.status_code == 200
    body = r.json()
    assert body["workout"] is None
    assert body["meal_plan"] is not None


def test_extract_intent_sin_historial_no_regresion(monkeypatch):
    # Sin historial el prompt no debe llevar sección de contexto (comportamiento previo).
    prompts = []

    def fake_ai(cfg, prompt, want_json=False):
        prompts.append(prompt)
        return _json.dumps({
            "wants_workout": True, "wants_meal_plan": False,
            "equipment": [], "has_cardio_equipment": False,
            "goal": "muscle_gain", "preferences": None,
        })

    monkeypatch.setattr(main, "ai_generate", fake_ai)
    intent = main._extract_intent(main.AIConfig(**AICFG), "quiero una rutina")
    assert intent["wants_workout"] is True
    assert "Contexto de la conversación" not in prompts[0]


# --- T18.3.1: detección de ambigüedad → pregunta de clarificación ---

def test_chat_plan_ambiguo_repregunta(monkeypatch):
    # "Hazme una rutina" sin equipo ni historial: el LLM marca ambigüedad y el
    # endpoint repregunta en vez de generar.
    def fake_ai(cfg, prompt, want_json=False):
        return _json.dumps({
            "wants_workout": True, "wants_meal_plan": False,
            "equipment": [], "has_cardio_equipment": False,
            "goal": "muscle_gain", "preferences": None,
            "needs_clarification": True,
            "clarifying_question": "¿Qué equipo tienes: casa, gym o sin equipo?",
        })

    monkeypatch.setattr(main, "ai_generate", fake_ai)
    r = client.post("/chat-plan", json={"message": "hazme una rutina", "ai": AICFG})
    assert r.status_code == 200
    body = r.json()
    assert body["needs_clarification"] is True
    assert body["reply"] == "¿Qué equipo tienes: casa, gym o sin equipo?"
    assert body["workout"] is None
    assert body["meal_plan"] is None


def test_chat_plan_completo_no_repregunta(monkeypatch):
    # Con el equipo dado no hay ambigüedad: genera normal y needs_clarification=False.
    monkeypatch.setattr(
        main, "_fetch_exercise_candidates",
        lambda bp, eq, limit=40: [
            {"id": 5, "name": "Swing", "body_part": "full_body", "equipment": "kettlebells"},
        ],
    )

    def fake_ai(cfg, prompt, want_json=False):
        if "wants_workout" in prompt:
            return _json.dumps({
                "wants_workout": True, "wants_meal_plan": False,
                "equipment": ["pesa rusa"], "has_cardio_equipment": False,
                "goal": "muscle_gain", "preferences": None,
                "needs_clarification": False, "clarifying_question": None,
            })
        return '{"items":[{"exercise_id":5,"sets":3,"reps":15,"rpe":7}]}'

    monkeypatch.setattr(main, "ai_generate", fake_ai)
    r = client.post("/chat-plan", json={"message": "rutina con pesa rusa", "ai": AICFG})
    assert r.status_code == 200
    body = r.json()
    assert body["needs_clarification"] is False
    assert body["workout"]["items"] == [{"exercise_id": 5, "sets": 3, "reps": 15, "rpe": 7, "name": "Swing"}]


# --- T18.4.1: planes multi-día variados ---

def test_meal_plan_num_days_1_shape_viejo(monkeypatch):
    # num_days=1 debe mantener el shape plano {"meals":[...]} sin 'days'.
    monkeypatch.setattr(
        main, "ai_generate",
        lambda *a, **k: '{"meals":[{"meal_type":"lunch","food_name":"Pollo","calories":400,'
                        '"protein_g":40,"carbs_g":30,"fat_g":10,"serving_size_g":300}]}',
    )
    plan = main._build_meal_plan(main.AIConfig(**AICFG), {"target_calories": 1800}, None, num_days=1)
    assert "days" not in plan
    assert isinstance(plan["meals"], list) and len(plan["meals"]) == 1


def test_meal_plan_num_days_7_varia(monkeypatch):
    # num_days=7 → 'days' con 7 entradas y platos distintos entre al menos dos días.
    calls = {"n": 0}

    def fake_ai(cfg, prompt, want_json=False):
        calls["n"] += 1
        # Cada día genera un food_name distinto para probar la variación.
        return (
            '{"meals":[{"meal_type":"lunch","food_name":"Plato %d","calories":400,'
            '"protein_g":40,"carbs_g":30,"fat_g":10,"serving_size_g":300}]}' % calls["n"]
        )

    monkeypatch.setattr(main, "ai_generate", fake_ai)
    plan = main._build_meal_plan(main.AIConfig(**AICFG), {"target_calories": 1800}, None, num_days=7)
    assert "meals" not in plan
    assert len(plan["days"]) == 7
    assert [d["day"] for d in plan["days"]] == list(range(1, 8))
    names = {d["meals"][0]["food_name"] for d in plan["days"]}
    assert len(names) >= 2  # contenido distinto entre días


def test_workout_num_days_1_shape_viejo(monkeypatch):
    monkeypatch.setattr(
        main, "_fetch_exercise_candidates",
        lambda bp, eq, limit=40: [{"id": 1, "name": "Press", "body_part": "chest", "equipment": "dumbbell"}],
    )
    monkeypatch.setattr(
        main, "ai_generate",
        lambda *a, **k: '{"items":[{"exercise_id":1,"sets":3,"reps":10,"rpe":8}]}',
    )
    plan = main._build_workout_plan(main.AIConfig(**AICFG), "muscle_gain", None, None, num_days=1)
    assert "days" not in plan
    assert plan["items"] == [{"exercise_id": 1, "sets": 3, "reps": 10, "rpe": 8, "name": "Press"}]


def test_workout_num_days_7_varia_y_filtra(monkeypatch):
    # Devuelve un catálogo distinto por grupo muscular (según body_part pedido) y
    # el modelo elige un id distinto cada día → ejercicios distintos entre días.
    catalog = {
        "chest": [{"id": 1, "name": "Press", "body_part": "chest", "equipment": "dumbbell"}],
        "back": [{"id": 2, "name": "Row", "body_part": "back", "equipment": "dumbbell"}],
        "legs": [{"id": 3, "name": "Squat", "body_part": "legs", "equipment": "dumbbell"}],
        "shoulders": [{"id": 4, "name": "OHP", "body_part": "shoulders", "equipment": "dumbbell"}],
        "arms": [{"id": 5, "name": "Curl", "body_part": "arms", "equipment": "dumbbell"}],
        "core": [{"id": 6, "name": "Plank", "body_part": "core", "equipment": "dumbbell"}],
        "full_body": [{"id": 7, "name": "Swing", "body_part": "full_body", "equipment": "dumbbell"}],
    }
    monkeypatch.setattr(main, "_fetch_exercise_candidates", lambda bp, eq, limit=40: catalog.get(bp, []))

    def fake_ai(cfg, prompt, want_json=False):
        # El modelo devuelve el id del ejercicio presente en el catálogo del día
        # (más un id alucinado que el filtro debe descartar).
        import re
        ids = re.findall(r'"id":\s*(\d+)', prompt)
        real = int(ids[0])
        return '{"items":[{"exercise_id":%d,"sets":3,"reps":10,"rpe":8},{"exercise_id":999,"sets":1,"reps":1}]}' % real

    monkeypatch.setattr(main, "ai_generate", fake_ai)
    plan = main._build_workout_plan(main.AIConfig(**AICFG), "muscle_gain", None, None, num_days=7)
    assert "items" not in plan
    assert len(plan["days"]) == 7
    # Cada día filtra el id alucinado (999) y conserva el real.
    for d in plan["days"]:
        assert all(it["exercise_id"] != 999 for it in d["items"])
    used_ids = {d["items"][0]["exercise_id"] for d in plan["days"]}
    assert len(used_ids) >= 2  # grupos musculares distintos entre días


def test_chat_plan_semana_genera_7_dias(monkeypatch):
    monkeypatch.setattr(
        main, "_fetch_exercise_candidates",
        lambda bp, eq, limit=40: [{"id": 1, "name": "X", "body_part": bp or "full_body", "equipment": "dumbbell"}],
    )

    def fake_ai(cfg, prompt, want_json=False):
        if "wants_workout" in prompt:
            return _json.dumps({
                "wants_workout": False, "wants_meal_plan": True,
                "equipment": [], "has_cardio_equipment": False,
                "goal": "maintenance", "preferences": None,
                "num_days": 7, "needs_clarification": False, "clarifying_question": None,
            })
        return ('{"meals":[{"meal_type":"lunch","food_name":"Plato","calories":400,'
                '"protein_g":40,"carbs_g":30,"fat_g":10,"serving_size_g":300}]}')

    monkeypatch.setattr(main, "ai_generate", fake_ai)
    r = client.post("/chat-plan", json={"message": "plan de comida para la semana", "ai": AICFG})
    assert r.status_code == 200
    body = r.json()
    assert body["meal_plan"] is not None
    assert len(body["meal_plan"]["days"]) == 7
    assert "7 días" in body["reply"]


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
