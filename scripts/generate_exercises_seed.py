"""Genera el seed SQL de `training.exercises` desde free-exercise-db.

Lee ``reference/free-exercise-db/dist/exercises.json`` (dataset de dominio
público, licencia Unlicense) y emite ``docker/postgres/zz_exercises_seed.sql``,
que Postgres ejecuta en el init tras ``z_init.sql`` (orden alfabético del
directorio ``docker-entrypoint-initdb.d``).

Las imágenes NO se vendorizan: se referencian por URL al raw de GitHub. El
``id`` de la tabla es un surrogate IDENTITY, así que los INSERT no lo fijan; el
slug original del dataset se guarda en ``external_id``.

Uso:
    python scripts/generate_exercises_seed.py
"""

from __future__ import annotations

import json
import pathlib
from typing import Any

# Raíz del repositorio (este archivo vive en <root>/scripts/).
ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "reference" / "free-exercise-db" / "dist" / "exercises.json"
OUT = ROOT / "docker" / "postgres" / "zz_exercises_seed.sql"

# Base para construir las URLs absolutas de las imágenes de referencia.
RAW_BASE = "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises"


def sql_str(value: Any) -> str:
    """Devuelve un literal SQL: ``NULL`` o una cadena con comillas escapadas."""
    if value is None:
        return "NULL"
    return "'" + str(value).replace("'", "''") + "'"


def sql_text_array(items: list[str] | None) -> str:
    """Devuelve un literal ``TEXT[]`` de PostgreSQL a partir de una lista."""
    if not items:
        return "'{}'::text[]"
    return "ARRAY[" + ", ".join(sql_str(i) for i in items) + "]::text[]"


def _first(items: list[str] | None) -> str | None:
    """Primer elemento de una lista o ``None`` si está vacía/ausente."""
    return items[0] if items else None


def build_insert(exercise: dict[str, Any]) -> str:
    """Construye una sentencia ``INSERT`` para un ejercicio del dataset."""
    image_urls = [f"{RAW_BASE}/{path}" for path in exercise.get("images") or []]
    instructions = json.dumps(
        {"en": exercise.get("instructions") or []}, ensure_ascii=False
    )
    primary = _first(exercise.get("primaryMuscles"))
    columns = (
        "external_id, name, category, body_part, target_muscle, "
        "secondary_muscles, equipment, force, level, mechanic, "
        "instructions, image_urls"
    )
    values = ", ".join(
        [
            sql_str(exercise.get("id")),
            sql_str(exercise.get("name")),
            sql_str(exercise.get("category")),
            sql_str(primary),
            sql_str(primary),
            sql_text_array(exercise.get("secondaryMuscles")),
            sql_str(exercise.get("equipment")),
            sql_str(exercise.get("force")),
            sql_str(exercise.get("level")),
            sql_str(exercise.get("mechanic")),
            f"{sql_str(instructions)}::jsonb",
            sql_text_array(image_urls),
        ]
    )
    return f"INSERT INTO training.exercises ({columns}) VALUES ({values});"


def build_seed_sql(rows: list[dict[str, Any]]) -> str:
    """Genera el script SQL completo (transaccional) para todos los ejercicios."""
    lines = [
        "-- Seed autogenerado por scripts/generate_exercises_seed.py",
        "-- Fuente: yuhonas/free-exercise-db (licencia Unlicense / dominio público).",
        "-- NO editar a mano: regenerar con el script.",
        "BEGIN;",
    ]
    lines.extend(build_insert(exercise) for exercise in rows)
    lines.append("COMMIT;")
    return "\n".join(lines) + "\n"


def main() -> None:
    """Lee el dataset, genera el seed y lo escribe en disco."""
    rows = json.loads(SRC.read_text(encoding="utf-8"))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(build_seed_sql(rows), encoding="utf-8")
    print(f"Generado {OUT.relative_to(ROOT)} con {len(rows)} ejercicios.")


if __name__ == "__main__":
    main()
