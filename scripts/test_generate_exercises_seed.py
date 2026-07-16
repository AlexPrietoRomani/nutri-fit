"""Tests unitarios del generador de seed de ejercicios (T7.2.1 / T7.2.2)."""

from __future__ import annotations

import re

from generate_exercises_seed import (
    RAW_BASE,
    build_insert,
    build_seed_sql,
    sql_str,
    sql_text_array,
)

# Fixture: dos ejercicios que ejercitan los casos borde.
#  - uno con comilla simple en el nombre y sin imágenes ni músculos secundarios
#  - uno normal con imágenes y equipment nulo
FIXTURE = [
    {
        "id": "Farmer's_Walk",
        "name": "Farmer's Walk",
        "category": "strongman",
        "equipment": "other",
        "force": "static",
        "level": "beginner",
        "mechanic": "compound",
        "primaryMuscles": ["forearms"],
        "secondaryMuscles": [],
        "instructions": ["Grab the handles", "Walk"],
        "images": [],
    },
    {
        "id": "3_4_Sit-Up",
        "name": "3/4 Sit-Up",
        "category": "strength",
        "equipment": None,  # equipment ausente en el dataset real
        "force": "pull",
        "level": "beginner",
        "mechanic": "compound",
        "primaryMuscles": ["abdominals"],
        "secondaryMuscles": ["hip flexors", "lower back"],
        "instructions": ["Lie down", "Flex", "Return"],
        "images": ["3_4_Sit-Up/0.jpg", "3_4_Sit-Up/1.jpg"],
    },
]


def test_sql_str_escapa_comillas():
    assert sql_str("Farmer's Walk") == "'Farmer''s Walk'"


def test_sql_str_none_es_null():
    assert sql_str(None) == "NULL"


def test_array_vacio():
    assert sql_text_array([]) == "'{}'::text[]"
    assert sql_text_array(None) == "'{}'::text[]"


def test_array_con_elementos():
    assert sql_text_array(["a", "b"]) == "ARRAY['a', 'b']::text[]"


def test_insert_incluye_jsonb_y_escapa():
    stmt = build_insert(FIXTURE[0])
    assert stmt.startswith("INSERT INTO training.exercises (")
    assert "::jsonb" in stmt
    assert "'Farmer''s Walk'" in stmt  # comilla escapada
    assert "'{}'::text[]" in stmt  # imágenes/secundarios vacíos


def test_insert_equipment_nulo():
    # El segundo ejercicio tiene equipment None -> debe emitir NULL, no ''.
    stmt = build_insert(FIXTURE[1])
    # posición de equipment: tras secondary_muscles(array) viene equipment
    assert ", NULL," in stmt


def test_urls_de_imagen_bien_formadas():
    stmt = build_insert(FIXTURE[1])
    pattern = re.escape(RAW_BASE) + r"/3_4_Sit-Up/0\.jpg"
    assert re.search(pattern, stmt)


def test_seed_completo_transaccional_y_conteo():
    sql = build_seed_sql(FIXTURE)
    assert sql.strip().startswith("-- Seed autogenerado")
    assert "BEGIN;" in sql and sql.strip().endswith("COMMIT;")
    # un INSERT por ejercicio
    assert sql.count("INSERT INTO training.exercises") == len(FIXTURE)
