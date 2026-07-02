#!/usr/bin/env python3
"""Prepare the disposable local character for a repeatable quest-accept test."""

from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
LOCAL_RUNTIME = ROOT / "local_runtime"
TRANSACTION_LOG = LOCAL_RUNTIME / "database-transactions.log"
CHARACTER_NAME_RE = re.compile(r"^[A-Za-z][A-Za-z0-9]{1,11}$")

sys.path.insert(0, str(ROOT / "tools"))
from audit_azerothcore_db import DEFAULT_CONFIGS, dedupe_connections, find_executable, parse_config, run_mysql_query  # noqa: E402


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def append_transaction_log(action: str, ok: bool, detail: dict[str, Any]) -> None:
    LOCAL_RUNTIME.mkdir(parents=True, exist_ok=True)
    entry = {
        "timestamp": utc_now(),
        "action": action,
        "ok": ok,
        "detail": detail,
    }
    with TRANSACTION_LOG.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(entry, sort_keys=True) + "\n")
    TRANSACTION_LOG.chmod(0o600)


def character_database_connection() -> Any:
    parsed = []
    for config in DEFAULT_CONFIGS:
        parsed.extend(parse_config(config))
    by_database = {connection.database: connection for connection in dedupe_connections(parsed)}
    connection = by_database.get("acore_characters")
    if connection is None:
        raise RuntimeError("could not find acore_characters connection in local AzerothCore configs")
    return connection


def sql_string(value: str) -> str:
    return "'" + value.replace("\\", "\\\\").replace("'", "''") + "'"


def run_query(connection: Any, mysql_path: str, query: str, timeout: int) -> str:
    ok, output = run_mysql_query(connection, query, timeout, mysql_path)
    if not ok:
        raise RuntimeError(output)
    return output


def read_character(connection: Any, mysql_path: str, character: str, timeout: int) -> dict[str, Any]:
    output = run_query(
        connection,
        mysql_path,
        "SELECT guid,name,online FROM characters WHERE name=" + sql_string(character) + " LIMIT 1;",
        timeout,
    )
    if not output.strip():
        raise RuntimeError(f"character not found: {character}")
    fields = output.splitlines()[0].split("\t")
    if len(fields) != 3:
        raise RuntimeError("unexpected character query shape")
    return {
        "guid": int(fields[0]),
        "name": fields[1],
        "online": int(fields[2]),
    }


def table_exists(connection: Any, mysql_path: str, table: str, timeout: int) -> bool:
    output = run_query(
        connection,
        mysql_path,
        "SHOW TABLES LIKE " + sql_string(table) + ";",
        timeout,
    )
    return bool(output.strip())


def count_rows(connection: Any, mysql_path: str, table: str, guid: int, quest_id: int, timeout: int) -> int:
    if not table_exists(connection, mysql_path, table, timeout):
        return 0
    output = run_query(
        connection,
        mysql_path,
        f"SELECT COUNT(*) FROM {table} WHERE guid={guid} AND quest={quest_id};",
        timeout,
    )
    return int(output.splitlines()[0]) if output.strip() else 0


def delete_rows(connection: Any, mysql_path: str, table: str, guid: int, quest_id: int, timeout: int) -> None:
    if table_exists(connection, mysql_path, table, timeout):
        run_query(connection, mysql_path, f"DELETE FROM {table} WHERE guid={guid} AND quest={quest_id};", timeout)


def prepare_fixture(args: argparse.Namespace) -> dict[str, Any]:
    if not CHARACTER_NAME_RE.match(args.character):
        raise RuntimeError("character name must be 2 to 12 ASCII letters/digits and start with a letter")
    if args.quest_id <= 0:
        raise RuntimeError("quest id must be positive")

    mysql_path = find_executable("mysql")
    if mysql_path is None:
        raise RuntimeError("mysql command not found")

    connection = character_database_connection()
    character = read_character(connection, mysql_path, args.character, args.timeout)
    if character["online"] != 0 and not args.allow_online:
        raise RuntimeError("character is online; log it out before mutating the local fixture")

    tables = [
        "character_queststatus",
        "character_queststatus_objectives",
    ]
    if args.reset_rewarded:
        tables.append("character_queststatus_rewarded")

    before_counts = {
        table: count_rows(connection, mysql_path, table, character["guid"], args.quest_id, args.timeout)
        for table in tables
    }

    if not args.dry_run:
        for table in tables:
            delete_rows(connection, mysql_path, table, character["guid"], args.quest_id, args.timeout)

    after_counts = {
        table: count_rows(connection, mysql_path, table, character["guid"], args.quest_id, args.timeout)
        for table in tables
    }

    result = {
        "ok": True,
        "dry_run": args.dry_run,
        "reason": args.reason,
        "character": character["name"],
        "guid": character["guid"],
        "online": character["online"],
        "quest_id": args.quest_id,
        "reset_rewarded": args.reset_rewarded,
        "before_counts": before_counts,
        "after_counts": after_counts,
        "rows_removed": sum(before_counts.values()) - sum(after_counts.values()),
        "transaction_log": str(TRANSACTION_LOG),
    }
    append_transaction_log(
        "prepare_quest_accept_fixture",
        True,
        {
            "character": result["character"],
            "guid": result["guid"],
            "quest_id": result["quest_id"],
            "reset_rewarded": result["reset_rewarded"],
            "before_counts": result["before_counts"],
            "after_counts": result["after_counts"],
            "rows_removed": result["rows_removed"],
            "dry_run": result["dry_run"],
            "reason": result["reason"],
        },
    )
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--character", default="Codexstage")
    parser.add_argument("--quest-id", type=int, default=783)
    parser.add_argument("--reason", default="stage17-quest-accept-fixture")
    parser.add_argument("--timeout", type=int, default=8)
    parser.add_argument("--reset-rewarded", action=argparse.BooleanOptionalAction, default=True)
    parser.add_argument("--allow-online", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    try:
        result = prepare_fixture(args)
    except Exception as exc:
        detail = {
            "character": args.character,
            "quest_id": args.quest_id,
            "reset_rewarded": args.reset_rewarded,
            "dry_run": args.dry_run,
            "reason": args.reason,
            "error": str(exc),
        }
        append_transaction_log("prepare_quest_accept_fixture", False, detail)
        print(json.dumps({"ok": False, "error": str(exc)}, indent=2, sort_keys=True))
        return 1

    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
