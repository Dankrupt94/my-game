#!/usr/bin/env python3
"""Prepare (or reset) a local character's quest state for a repeatable
quest turn-in test.

Setup mode (default) marks a no-objective quest as COMPLETE in the character's
quest log and clears any prior "rewarded" record, so the live turn-in probe can
request the reward screen and hand the quest in. Reset mode removes both rows,
restoring the character's quest slate.

The default quest 783 is a talk-to-complete Northshire quest (no kill/item
objectives, no prerequisite) started by Deputy Willem (823) and ended by NPC 197,
which spawns next to the test character; it rewards no money, items, spell, or
title, so turning it in leaves the character effectively unchanged.

The character must be logged out: the worldserver loads quest status from the DB
at login, so it must be offline for these writes to take effect on the next login.

Usage:
    python3 tools/prepare_quest_turnin_fixture.py                # set up quest 783 for Codexstage
    python3 tools/prepare_quest_turnin_fixture.py --reset        # clean up afterwards
    python3 tools/prepare_quest_turnin_fixture.py --dry-run      # show intended writes only
"""

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

# QuestStatus::QUEST_STATUS_COMPLETE from AzerothCore QuestDef.h
QUEST_STATUS_COMPLETE = 1

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
    return {"guid": int(fields[0]), "name": fields[1], "online": int(fields[2])}


def quest_state(connection: Any, mysql_path: str, guid: int, quest_id: int, timeout: int) -> dict[str, Any]:
    status_out = run_query(
        connection,
        mysql_path,
        f"SELECT status FROM character_queststatus WHERE guid={guid} AND quest={quest_id};",
        timeout,
    )
    rewarded_out = run_query(
        connection,
        mysql_path,
        f"SELECT COUNT(*) FROM character_queststatus_rewarded WHERE guid={guid} AND quest={quest_id};",
        timeout,
    )
    status = int(status_out.splitlines()[0]) if status_out.strip() else None
    rewarded = int(rewarded_out.splitlines()[0]) if rewarded_out.strip() else 0
    return {"status": status, "rewarded": rewarded}


def prepare_fixture(args: argparse.Namespace) -> dict[str, Any]:
    if not CHARACTER_NAME_RE.match(args.character):
        raise RuntimeError("character name must be 2 to 12 ASCII letters/digits and start with a letter")
    if args.quest_id <= 0:
        raise RuntimeError("quest id must be a positive integer")

    mysql_path = find_executable("mysql")
    if mysql_path is None:
        raise RuntimeError("mysql command not found")

    connection = character_database_connection()
    before = read_character(connection, mysql_path, args.character, args.timeout)
    if before["online"] != 0 and not args.allow_online:
        raise RuntimeError("character is online; log it out before mutating the local fixture")

    guid = before["guid"]
    state_before = quest_state(connection, mysql_path, guid, args.quest_id, args.timeout)

    if not args.dry_run:
        if args.reset:
            run_query(connection, mysql_path,
                      f"DELETE FROM character_queststatus WHERE guid={guid} AND quest={args.quest_id};", args.timeout)
            run_query(connection, mysql_path,
                      f"DELETE FROM character_queststatus_rewarded WHERE guid={guid} AND quest={args.quest_id};", args.timeout)
        else:
            # Clear any prior turn-in so the quest can be handed in again.
            run_query(connection, mysql_path,
                      f"DELETE FROM character_queststatus_rewarded WHERE guid={guid} AND quest={args.quest_id};", args.timeout)
            # Mark the quest COMPLETE in the log (no-objective quest: all counts 0).
            run_query(connection, mysql_path,
                      "REPLACE INTO character_queststatus "
                      "(guid,quest,status,explored,timer,"
                      "mobcount1,mobcount2,mobcount3,mobcount4,"
                      "itemcount1,itemcount2,itemcount3,itemcount4,itemcount5,itemcount6,playercount) "
                      f"VALUES ({guid},{args.quest_id},{QUEST_STATUS_COMPLETE},1,0,0,0,0,0,0,0,0,0,0,0,0);",
                      args.timeout)

    state_after = quest_state(connection, mysql_path, guid, args.quest_id, args.timeout)

    result = {
        "ok": True,
        "dry_run": args.dry_run,
        "mode": "reset" if args.reset else "setup",
        "reason": args.reason,
        "character": before["name"],
        "guid": guid,
        "online": before["online"],
        "quest_id": args.quest_id,
        "status_before": state_before["status"],
        "status_after": state_after["status"],
        "rewarded_before": state_before["rewarded"],
        "rewarded_after": state_after["rewarded"],
        "transaction_log": str(TRANSACTION_LOG),
    }
    append_transaction_log("prepare_quest_turnin_fixture", True, {
        k: result[k] for k in
        ("mode", "character", "guid", "quest_id", "status_before", "status_after",
         "rewarded_before", "rewarded_after", "dry_run", "reason")
    })
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--character", default="Codexstage")
    parser.add_argument("--quest-id", type=int, default=783)
    parser.add_argument("--reset", action="store_true", help="remove the quest status/rewarded rows instead of setting up")
    parser.add_argument("--reason", default="stage17-quest-turnin-fixture")
    parser.add_argument("--timeout", type=int, default=8)
    parser.add_argument("--allow-online", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    try:
        result = prepare_fixture(args)
    except Exception as exc:
        append_transaction_log("prepare_quest_turnin_fixture", False, {
            "character": args.character, "quest_id": args.quest_id,
            "reset": args.reset, "dry_run": args.dry_run, "reason": args.reason, "error": str(exc),
        })
        print(json.dumps({"ok": False, "error": str(exc)}, indent=2, sort_keys=True))
        return 1

    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
