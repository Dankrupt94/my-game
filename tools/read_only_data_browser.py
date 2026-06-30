#!/usr/bin/env python3
"""Read safe, read-only AzerothCore data views for the Godot dashboard."""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from audit_azerothcore_db import DEFAULT_CONFIGS, dedupe_connections, find_executable, parse_config, run_mysql_query


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT_DIR = ROOT / "local_reports"
VIEW_CHOICES = ["summary", "accounts", "characters", "online", "creatures", "items", "quests", "spells", "all"]


class QueryError(RuntimeError):
    """Raised when a read-only query cannot be completed."""


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def sql_literal(value: str) -> str:
    return "'" + value.replace("\\", "\\\\").replace("'", "''") + "'"


def like_clause(columns: list[str], search: str | None) -> str:
    if not search:
        return ""
    pattern = sql_literal("%" + search + "%")
    return " WHERE " + " OR ".join(f"{column} LIKE {pattern}" for column in columns)


def order_clause(order_by: str, search: str | None) -> str:
    if search:
        return ""
    return " ORDER BY " + order_by


def clamp_limit(value: int) -> int:
    return max(1, min(value, 100))


def load_connections() -> dict[str, Any]:
    parsed = []
    for config in DEFAULT_CONFIGS:
        parsed.extend(parse_config(config))
    return {connection.database: connection for connection in dedupe_connections(parsed)}


def query_rows(connection: Any, query: str, columns: list[str], timeout: int, mysql_path: str) -> list[dict[str, Any]]:
    ok, output = run_mysql_query(connection, query, timeout, mysql_path)
    if not ok:
        raise QueryError(output)
    if not output:
        return []

    rows = []
    for line in output.splitlines():
        values = line.split("\t")
        row = {}
        for index, column in enumerate(columns):
            row[column] = values[index] if index < len(values) else None
        rows.append(row)
    return rows


def query_scalar(connection: Any, query: str, timeout: int, mysql_path: str) -> int:
    ok, output = run_mysql_query(connection, query, timeout, mysql_path)
    if not ok:
        raise QueryError(output)
    if not output:
        return 0
    return int(output.splitlines()[0])


def build_summary(connections: dict[str, Any], timeout: int, mysql_path: str) -> dict[str, Any]:
    auth = connections["acore_auth"]
    characters = connections["acore_characters"]
    world = connections["acore_world"]
    realm_columns = ["id", "name", "address", "port", "gamebuild", "population"]

    return {
        "counts": {
            "accounts": query_scalar(auth, "SELECT COUNT(*) FROM account;", timeout, mysql_path),
            "characters": query_scalar(characters, "SELECT COUNT(*) FROM characters;", timeout, mysql_path),
            "online_characters": query_scalar(characters, "SELECT COUNT(*) FROM characters WHERE online = 1;", timeout, mysql_path),
            "creature_templates": query_scalar(world, "SELECT COUNT(*) FROM creature_template;", timeout, mysql_path),
            "item_templates": query_scalar(world, "SELECT COUNT(*) FROM item_template;", timeout, mysql_path),
            "quest_templates": query_scalar(world, "SELECT COUNT(*) FROM quest_template;", timeout, mysql_path),
            "spell_dbc_rows": query_scalar(world, "SELECT COUNT(*) FROM spell_dbc;", timeout, mysql_path),
        },
        "realms": query_rows(
            auth,
            "SELECT id, name, address, port, gamebuild, population FROM realmlist ORDER BY id LIMIT 20;",
            realm_columns,
            timeout,
            mysql_path,
        ),
    }


def build_accounts(connections: dict[str, Any], limit: int, timeout: int, mysql_path: str) -> dict[str, Any]:
    columns = ["id", "username", "online", "expansion", "locale", "os", "totaltime"]
    rows = query_rows(
        connections["acore_auth"],
        f"SELECT id, username, online, expansion, locale, os, totaltime FROM account ORDER BY id LIMIT {limit};",
        columns,
        timeout,
        mysql_path,
    )
    return {"rows": rows}


def build_characters(connections: dict[str, Any], limit: int, timeout: int, mysql_path: str, online_only: bool) -> dict[str, Any]:
    columns = ["guid", "account", "name", "race", "class", "gender", "level", "online", "map", "zone", "totaltime"]
    where = "WHERE online = 1 " if online_only else ""
    rows = query_rows(
        connections["acore_characters"],
        "SELECT guid, account, name, race, class, gender, level, online, map, zone, totaltime "
        f"FROM characters {where}ORDER BY name LIMIT {limit};",
        columns,
        timeout,
        mysql_path,
    )
    return {"rows": rows}


def build_creatures(connections: dict[str, Any], search: str | None, limit: int, timeout: int, mysql_path: str) -> dict[str, Any]:
    columns = ["entry", "name", "subname", "minlevel", "maxlevel", "rank", "faction", "npcflag"]
    where = like_clause(["name", "subname"], search)
    rows = query_rows(
        connections["acore_world"],
        "SELECT entry, name, subname, minlevel, maxlevel, `rank`, faction, npcflag "
        f"FROM creature_template{where}{order_clause('name', search)} LIMIT {limit};",
        columns,
        timeout,
        mysql_path,
    )
    return {"search": search or "", "rows": rows}


def build_items(connections: dict[str, Any], search: str | None, limit: int, timeout: int, mysql_path: str) -> dict[str, Any]:
    columns = ["entry", "name", "quality", "inventory_type", "item_level", "required_level", "class", "subclass"]
    where = like_clause(["name"], search)
    rows = query_rows(
        connections["acore_world"],
        "SELECT entry, name, Quality, InventoryType, ItemLevel, RequiredLevel, `class`, subclass "
        f"FROM item_template{where}{order_clause('name', search)} LIMIT {limit};",
        columns,
        timeout,
        mysql_path,
    )
    return {"search": search or "", "rows": rows}


def build_quests(connections: dict[str, Any], search: str | None, limit: int, timeout: int, mysql_path: str) -> dict[str, Any]:
    columns = ["id", "title", "quest_level", "min_level", "quest_type", "quest_sort_id"]
    where = like_clause(["LogTitle"], search)
    rows = query_rows(
        connections["acore_world"],
        "SELECT ID, LogTitle, QuestLevel, MinLevel, QuestType, QuestSortID "
        f"FROM quest_template{where}{order_clause('LogTitle', search)} LIMIT {limit};",
        columns,
        timeout,
        mysql_path,
    )
    return {"search": search or "", "rows": rows}


def build_spells(connections: dict[str, Any], search: str | None, limit: int, timeout: int, mysql_path: str) -> dict[str, Any]:
    columns = ["id", "name", "rank", "description", "spell_level", "base_level", "power_type", "mana_cost"]
    where = like_clause(["Name_Lang_enUS", "NameSubtext_Lang_enUS"], search)
    rows = query_rows(
        connections["acore_world"],
        "SELECT ID, Name_Lang_enUS, NameSubtext_Lang_enUS, Description_Lang_enUS, SpellLevel, BaseLevel, PowerType, ManaCost "
        f"FROM spell_dbc{where}{order_clause('Name_Lang_enUS', search)} LIMIT {limit};",
        columns,
        timeout,
        mysql_path,
    )
    return {"search": search or "", "rows": rows}


def build_view(view: str, search: str | None, limit: int, timeout: int) -> dict[str, Any]:
    mysql_path = find_executable("mysql")
    if mysql_path is None:
        return {"ok": False, "error": "mysql command not found", "views": {}}

    connections = load_connections()
    missing = [database for database in ["acore_auth", "acore_characters", "acore_world"] if database not in connections]
    if missing:
        return {"ok": False, "error": "missing configured databases: " + ", ".join(missing), "views": {}}

    builders = {
        "summary": lambda: build_summary(connections, timeout, mysql_path),
        "accounts": lambda: build_accounts(connections, limit, timeout, mysql_path),
        "characters": lambda: build_characters(connections, limit, timeout, mysql_path, False),
        "online": lambda: build_characters(connections, limit, timeout, mysql_path, True),
        "creatures": lambda: build_creatures(connections, search, limit, timeout, mysql_path),
        "items": lambda: build_items(connections, search, limit, timeout, mysql_path),
        "quests": lambda: build_quests(connections, search, limit, timeout, mysql_path),
        "spells": lambda: build_spells(connections, search, limit, timeout, mysql_path),
    }
    selected = list(builders) if view == "all" else [view]
    views: dict[str, Any] = {}
    errors: dict[str, str] = {}

    for name in selected:
        try:
            views[name] = builders[name]()
        except QueryError as exc:
            errors[name] = str(exc)

    return {
        "ok": not errors,
        "generated_at": utc_now(),
        "view": view,
        "search": search or "",
        "limit": limit,
        "views": views,
        "errors": errors,
    }


def write_markdown(report: dict[str, Any], path: Path) -> None:
    lines = [
        "# Read-Only Data Browser",
        "",
        "This local-only report is generated through SELECT queries.",
        "",
        f"Generated: `{report.get('generated_at', utc_now())}`",
        f"View: `{report.get('view')}`",
        f"Search: `{report.get('search', '')}`",
        f"Limit: `{report.get('limit')}`",
        "",
    ]

    summary = report.get("views", {}).get("summary") if isinstance(report.get("views"), dict) else None
    if isinstance(summary, dict):
        lines.extend(["## Summary Counts", ""])
        for name, count in summary.get("counts", {}).items():
            lines.append(f"- `{name}`: {count}")
        lines.extend(["", "## Realms", ""])
        for realm in summary.get("realms", []):
            lines.append(f"- `{realm.get('id')}` `{realm.get('name')}` at `{realm.get('address')}:{realm.get('port')}`")

    views = report.get("views", {})
    if isinstance(views, dict):
        for name, payload in views.items():
            if name == "summary" or not isinstance(payload, dict):
                continue
            rows = payload.get("rows", [])
            lines.extend(["", f"## {name.title()}", "", f"- Rows returned: {len(rows)}"])

    errors = report.get("errors", {})
    if errors:
        lines.extend(["", "## Errors", ""])
        for name, error in errors.items():
            lines.append(f"- `{name}`: `{error}`")

    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--view", choices=VIEW_CHOICES, default="summary")
    parser.add_argument("--search", default="")
    parser.add_argument("--limit", type=int, default=25)
    parser.add_argument("--timeout", type=int, default=8)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--compact", action="store_true")
    args = parser.parse_args()

    limit = clamp_limit(args.limit)
    search = args.search.strip() or None
    report = build_view(args.view, search, limit, args.timeout)

    args.output_dir.mkdir(parents=True, exist_ok=True)
    json_path = args.output_dir / "read-only-data-browser.json"
    md_path = args.output_dir / "read-only-data-browser.md"
    json_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    write_markdown(report, md_path)

    if args.compact:
        output = {
            "ok": report["ok"],
            "view": report.get("view"),
            "search": report.get("search"),
            "limit": report.get("limit"),
            "summary": report.get("views", {}).get("summary", {}),
            "errors": report.get("errors", {}),
        }
    else:
        output = report
    print(json.dumps(output, indent=2, sort_keys=True))
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
