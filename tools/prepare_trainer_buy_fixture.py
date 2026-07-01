#!/usr/bin/env python3
"""Prepare the disposable local character for a repeatable trainer-buy success test."""

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
        "SELECT guid,name,money,online FROM characters WHERE name=" + sql_string(character) + " LIMIT 1;",
        timeout,
    )
    if not output.strip():
        raise RuntimeError(f"character not found: {character}")
    fields = output.splitlines()[0].split("\t")
    if len(fields) != 4:
        raise RuntimeError("unexpected character query shape")
    return {
        "guid": int(fields[0]),
        "name": fields[1],
        "money": int(fields[2]),
        "online": int(fields[3]),
    }


def count_spell(connection: Any, mysql_path: str, guid: int, spell_id: int, timeout: int) -> int:
    output = run_query(
        connection,
        mysql_path,
        f"SELECT COUNT(*) FROM character_spell WHERE guid={guid} AND spell={spell_id};",
        timeout,
    )
    return int(output.splitlines()[0]) if output.strip() else 0


def prepare_fixture(args: argparse.Namespace) -> dict[str, Any]:
    if not CHARACTER_NAME_RE.match(args.character):
        raise RuntimeError("character name must be 2 to 12 ASCII letters/digits and start with a letter")
    if args.minimum_copper < 0:
        raise RuntimeError("minimum copper must be zero or greater")
    if args.reset_spell_id < 0:
        raise RuntimeError("reset spell id must be zero or greater")

    mysql_path = find_executable("mysql")
    if mysql_path is None:
        raise RuntimeError("mysql command not found")

    connection = character_database_connection()
    before = read_character(connection, mysql_path, args.character, args.timeout)
    if before["online"] != 0 and not args.allow_online:
        raise RuntimeError("character is online; log it out before mutating the local fixture")

    spell_rows_before = count_spell(connection, mysql_path, before["guid"], args.reset_spell_id, args.timeout) \
        if args.reset_spell_id > 0 else 0

    if not args.dry_run:
        run_query(
            connection,
            mysql_path,
            f"UPDATE characters SET money=GREATEST(money,{args.minimum_copper}) WHERE guid={before['guid']};",
            args.timeout,
        )
        if args.reset_spell_id > 0:
            run_query(
                connection,
                mysql_path,
                f"DELETE FROM character_spell WHERE guid={before['guid']} AND spell={args.reset_spell_id};",
                args.timeout,
            )

    after = read_character(connection, mysql_path, args.character, args.timeout)
    spell_rows_after = count_spell(connection, mysql_path, after["guid"], args.reset_spell_id, args.timeout) \
        if args.reset_spell_id > 0 else 0

    result = {
        "ok": True,
        "dry_run": args.dry_run,
        "reason": args.reason,
        "character": after["name"],
        "guid": after["guid"],
        "online": after["online"],
        "minimum_copper": args.minimum_copper,
        "before_money": before["money"],
        "after_money": after["money"],
        "money_changed": before["money"] != after["money"],
        "reset_spell_id": args.reset_spell_id,
        "spell_rows_before": spell_rows_before,
        "spell_rows_after": spell_rows_after,
        "spell_reset": spell_rows_before > spell_rows_after,
        "transaction_log": str(TRANSACTION_LOG),
    }
    append_transaction_log(
        "prepare_trainer_buy_fixture",
        True,
        {
            "character": result["character"],
            "guid": result["guid"],
            "minimum_copper": result["minimum_copper"],
            "before_money": result["before_money"],
            "after_money": result["after_money"],
            "reset_spell_id": result["reset_spell_id"],
            "spell_rows_before": result["spell_rows_before"],
            "spell_rows_after": result["spell_rows_after"],
            "dry_run": result["dry_run"],
            "reason": result["reason"],
        },
    )
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--character", default="Codexstage")
    parser.add_argument("--minimum-copper", type=int, default=10000)
    parser.add_argument("--reset-spell-id", type=int, default=6673)
    parser.add_argument("--reason", default="stage17-trainer-buy-success-fixture")
    parser.add_argument("--timeout", type=int, default=8)
    parser.add_argument("--allow-online", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    try:
        result = prepare_fixture(args)
    except Exception as exc:
        detail = {
            "character": args.character,
            "minimum_copper": args.minimum_copper,
            "reset_spell_id": args.reset_spell_id,
            "dry_run": args.dry_run,
            "reason": args.reason,
            "error": str(exc),
        }
        append_transaction_log("prepare_trainer_buy_fixture", False, detail)
        print(json.dumps({"ok": False, "error": str(exc)}, indent=2, sort_keys=True))
        return 1

    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
