#!/usr/bin/env python3
"""Run a safe read-only audit of local AzerothCore database connectivity."""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import tempfile
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT_DIR = ROOT / "local_reports"
DEFAULT_CONFIGS = [
    Path("/run/media/doodbro/New 1tb/AzerothCore/configs/authserver.conf"),
    Path("/run/media/doodbro/New 1tb/AzerothCore/configs/worldserver.conf"),
]
DATABASE_KEYS = ["LoginDatabaseInfo", "WorldDatabaseInfo", "CharacterDatabaseInfo"]


@dataclass(frozen=True)
class DatabaseConnection:
    source_config: str
    key: str
    host: str
    port: int
    user: str
    password: str
    database: str

    def redacted(self) -> dict[str, object]:
        return {
            "source_config": self.source_config,
            "key": self.key,
            "host": self.host,
            "port": self.port,
            "user": self.user,
            "password": "***",
            "database": self.database,
        }


def parse_config(path: Path) -> list[DatabaseConnection]:
    if not path.exists():
        return []

    text = path.read_text(errors="replace")
    connections: list[DatabaseConnection] = []
    for key in DATABASE_KEYS:
        pattern = re.compile(r"^\s*" + re.escape(key) + r'\s*=\s*"([^"]+)"', re.MULTILINE)
        match = pattern.search(text)
        if not match:
            continue

        parts = match.group(1).split(";")
        if len(parts) < 5:
            continue

        host, port_text, user, password, database = parts[:5]
        try:
            port = int(port_text)
        except ValueError:
            continue

        connections.append(
            DatabaseConnection(
                source_config=str(path),
                key=key,
                host=host,
                port=port,
                user=user,
                password=password,
                database=database,
            )
        )
    return connections


def dedupe_connections(connections: list[DatabaseConnection]) -> list[DatabaseConnection]:
    seen: set[tuple[str, int, str, str]] = set()
    unique: list[DatabaseConnection] = []
    for connection in connections:
        key = (connection.host, connection.port, connection.user, connection.database)
        if key in seen:
            continue
        seen.add(key)
        unique.append(connection)
    return unique


def write_defaults_file(connection: DatabaseConnection, directory: Path) -> Path:
    defaults = directory / "mysql-client.cnf"
    defaults.write_text(
        "\n".join(
            [
                "[client]",
                f"host={connection.host}",
                f"port={connection.port}",
                f"user={connection.user}",
                f"password={connection.password}",
                "",
            ]
        ),
        encoding="utf-8",
    )
    defaults.chmod(0o600)
    return defaults


def run_mysql_query(connection: DatabaseConnection, query: str, timeout: int) -> tuple[bool, str]:
    with tempfile.TemporaryDirectory(prefix="acore-db-audit-") as tmp:
        defaults = write_defaults_file(connection, Path(tmp))
        command = [
            "mysql",
            f"--defaults-extra-file={defaults}",
            "--batch",
            "--raw",
            "--skip-column-names",
            connection.database,
            "--execute",
            query,
        ]
        try:
            completed = subprocess.run(
                command,
                check=False,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=timeout,
            )
        except (OSError, subprocess.TimeoutExpired) as exc:
            return False, str(exc)

    if completed.returncode != 0:
        return False, completed.stderr.strip()
    return True, completed.stdout.strip()


def audit_connection(connection: DatabaseConnection, timeout: int, no_query: bool) -> dict[str, object]:
    result: dict[str, object] = {
        "connection": connection.redacted(),
        "reachable": False,
        "server_version": None,
        "table_count": None,
        "sample_tables": [],
        "error": None,
    }

    if no_query:
        result["error"] = "query skipped by --no-query"
        return result

    if shutil.which("mysql") is None:
        result["error"] = "mysql command not found"
        return result

    version_ok, version_output = run_mysql_query(connection, "SELECT VERSION();", timeout)
    if not version_ok:
        result["error"] = version_output
        return result

    result["reachable"] = True
    result["server_version"] = version_output

    table_ok, table_output = run_mysql_query(
        connection,
        "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = DATABASE();",
        timeout,
    )
    if table_ok and table_output:
        try:
            result["table_count"] = int(table_output.splitlines()[0])
        except ValueError:
            result["table_count"] = table_output

    sample_ok, sample_output = run_mysql_query(
        connection,
        "SELECT table_name FROM information_schema.tables WHERE table_schema = DATABASE() ORDER BY table_name LIMIT 20;",
        timeout,
    )
    if sample_ok and sample_output:
        result["sample_tables"] = sample_output.splitlines()

    return result


def write_markdown(report: dict[str, object], path: Path) -> None:
    lines = [
        "# AzerothCore Database Audit",
        "",
        "This is a local-only report. Credentials are redacted.",
        "",
        f"Generated: `{report['generated_at']}`",
        "",
        "## Summary",
        "",
        f"- Config files found: {report['config_files_found']}",
        f"- Unique database connections found: {report['connection_count']}",
        f"- Reachable databases: {report['reachable_count']}",
        f"- MySQL client present: {report['mysql_client_present']}",
        "",
        "## Connections",
        "",
    ]

    for item in report["audits"]:  # type: ignore[index]
        connection = item["connection"]
        reachable = "yes" if item["reachable"] else "no"
        table_count = item["table_count"] if item["table_count"] is not None else "unknown"
        lines.append(
            f"- `{connection['database']}` from `{connection['key']}` at `{connection['host']}:{connection['port']}`: "
            f"reachable={reachable}, tables={table_count}"
        )
        if item["error"]:
            lines.append(f"  - Error: `{item['error']}`")

    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", action="append", type=Path, dest="configs", help="Config file to parse. May repeat.")
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--timeout", type=int, default=8)
    parser.add_argument("--no-query", action="store_true", help="Only parse configs; skip database connection attempts.")
    args = parser.parse_args()

    configs = args.configs if args.configs else DEFAULT_CONFIGS
    parsed: list[DatabaseConnection] = []
    for config in configs:
        parsed.extend(parse_config(config))

    unique = dedupe_connections(parsed)
    audits = [audit_connection(connection, args.timeout, args.no_query) for connection in unique]
    report = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "project_root": str(ROOT),
        "config_files_requested": [str(config) for config in configs],
        "config_files_found": sum(1 for config in configs if config.exists()),
        "connections": [connection.redacted() for connection in unique],
        "connection_count": len(unique),
        "mysql_client_present": shutil.which("mysql") is not None,
        "reachable_count": sum(1 for audit in audits if audit["reachable"]),
        "audits": audits,
    }

    args.output_dir.mkdir(parents=True, exist_ok=True)
    json_path = args.output_dir / "azerothcore-db-audit.json"
    md_path = args.output_dir / "azerothcore-db-audit.md"
    json_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    write_markdown(report, md_path)

    print(f"Wrote {json_path}")
    print(f"Wrote {md_path}")
    print(f"Connections found: {report['connection_count']}")
    print(f"Reachable databases: {report['reachable_count']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
