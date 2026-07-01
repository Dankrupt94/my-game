#!/usr/bin/env python3
"""Read nearby AzerothCore world spawns for Godot placeholder visibility."""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from audit_azerothcore_db import DEFAULT_CONFIGS, dedupe_connections, find_executable, parse_config, run_mysql_query


ROOT = Path(__file__).resolve().parents[1]


class QueryError(RuntimeError):
    """Raised when the read-only object query cannot be completed."""


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def load_connections() -> dict[str, Any]:
    parsed = []
    for config in DEFAULT_CONFIGS:
        parsed.extend(parse_config(config))
    return {connection.database: connection for connection in dedupe_connections(parsed)}


def clamp_limit(value: int) -> int:
    return max(1, min(value, 100))


def query_rows(connection: Any, query: str, columns: list[str], timeout: int, mysql_path: str) -> list[dict[str, Any]]:
    ok, output = run_mysql_query(connection, query, timeout, mysql_path)
    if not ok:
        raise QueryError(output)
    rows: list[dict[str, Any]] = []
    for line in output.splitlines():
        values = line.split("\t")
        row = {}
        for index, column in enumerate(columns):
            row[column] = values[index] if index < len(values) else ""
        rows.append(row)
    return rows


def numeric(value: str, fallback: float = 0.0) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return fallback


def normalize_row(kind: str, row: dict[str, str], center_x: float, center_y: float) -> dict[str, Any]:
    counter = int(numeric(row.get("guid", "0")))
    entry = int(numeric(row.get("entry", "0")))
    high_guid = 0xF110 if kind == "gameobject" else 0xF130
    raw_guid = (high_guid << 48) | (entry << 24) | counter
    x = numeric(row.get("x", "0"))
    y = numeric(row.get("y", "0"))
    z = numeric(row.get("z", "0"))
    distance = numeric(row.get("distance", "0"))
    return {
        "kind": kind,
        "guid": row.get("guid", ""),
        "raw_guid": raw_guid,
        "raw_guid_hex": f"0x{raw_guid:x}",
        "entry": row.get("entry", ""),
        "name": row.get("name", "") or f"{kind} {row.get('entry', '')}",
        "map": int(numeric(row.get("map", "0"))),
        "x": x,
        "y": y,
        "z": z,
        "orientation": numeric(row.get("orientation", "0")),
        "distance": distance,
        "relative_x": x - center_x,
        "relative_y": y - center_y,
        "level": row.get("level", ""),
        "faction": row.get("faction", ""),
        "type": row.get("type", ""),
        "npcflag": row.get("npcflag", ""),
    }


def build_nearby(map_id: int, x: float, y: float, radius: float, limit: int, timeout: int) -> dict[str, Any]:
    mysql_path = find_executable("mysql")
    if mysql_path is None:
        return {"ok": False, "error": "mysql command not found", "objects": []}

    connections = load_connections()
    world = connections.get("acore_world")
    if world is None:
        return {"ok": False, "error": "missing configured database: acore_world", "objects": []}

    radius_sq = radius * radius
    creature_limit = max(1, limit // 2)
    gameobject_limit = max(1, limit - creature_limit)
    distance_expr = f"((c.position_x-({x}))*(c.position_x-({x}))+(c.position_y-({y}))*(c.position_y-({y})))"
    creature_columns = [
        "guid",
        "entry",
        "name",
        "map",
        "x",
        "y",
        "z",
        "orientation",
        "distance",
        "level",
        "faction",
        "type",
        "npcflag",
    ]
    creature_query = (
        "SELECT c.guid, c.id1, ct.name, c.map, c.position_x, c.position_y, c.position_z, c.orientation, "
        f"SQRT({distance_expr}), ct.minlevel, ct.faction, ct.type, (c.npcflag | ct.npcflag) "
        "FROM creature c LEFT JOIN creature_template ct ON ct.entry = c.id1 "
        f"WHERE c.map = {map_id} AND {distance_expr} <= {radius_sq} "
        f"ORDER BY {distance_expr}, c.guid LIMIT {creature_limit};"
    )

    go_distance_expr = f"((g.position_x-({x}))*(g.position_x-({x}))+(g.position_y-({y}))*(g.position_y-({y})))"
    gameobject_columns = ["guid", "entry", "name", "map", "x", "y", "z", "orientation", "distance", "level", "faction", "type", "npcflag"]
    gameobject_query = (
        "SELECT g.guid, g.id, gt.name, g.map, g.position_x, g.position_y, g.position_z, g.orientation, "
        f"SQRT({go_distance_expr}), '', '', gt.type, '' "
        "FROM gameobject g LEFT JOIN gameobject_template gt ON gt.entry = g.id "
        f"WHERE g.map = {map_id} AND {go_distance_expr} <= {radius_sq} "
        f"ORDER BY {go_distance_expr}, g.guid LIMIT {gameobject_limit};"
    )

    try:
        creature_rows = query_rows(world, creature_query, creature_columns, timeout, mysql_path)
        gameobject_rows = query_rows(world, gameobject_query, gameobject_columns, timeout, mysql_path)
    except QueryError as exc:
        return {"ok": False, "error": str(exc), "objects": []}

    creatures = [normalize_row("creature", row, x, y) for row in creature_rows]
    gameobjects = [normalize_row("gameobject", row, x, y) for row in gameobject_rows]
    objects = sorted(creatures + gameobjects, key=lambda item: float(item["distance"]))
    return {
        "ok": True,
        "generated_at": utc_now(),
        "map": map_id,
        "center": {"x": x, "y": y},
        "radius": radius,
        "limit": limit,
        "counts": {
            "creatures": len(creatures),
            "gameobjects": len(gameobjects),
            "objects": len(objects),
        },
        "objects": objects,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--map", type=int, required=True)
    parser.add_argument("--x", type=float, required=True)
    parser.add_argument("--y", type=float, required=True)
    parser.add_argument("--radius", type=float, default=80.0)
    parser.add_argument("--limit", type=int, default=50)
    parser.add_argument("--timeout", type=int, default=20)
    args = parser.parse_args()

    report = build_nearby(args.map, args.x, args.y, max(1.0, args.radius), clamp_limit(args.limit), args.timeout)
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0 if report.get("ok") else 1


if __name__ == "__main__":
    raise SystemExit(main())
