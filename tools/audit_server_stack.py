#!/usr/bin/env python3
"""Audit local AzerothCore server-stack status without changing service state."""

from __future__ import annotations

import argparse
import json
import shutil
import socket
import subprocess
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT_DIR = ROOT / "local_reports"
ACORE_ROOT = Path("/run/media/doodbro/New 1tb/AzerothCore")
SCRIPTS_DIR = ACORE_ROOT / "scripts"
RUN_DIR = ACORE_ROOT / "run"
BIN_DIR = RUN_DIR / "bin"
LOGS_DIR = ACORE_ROOT / "logs"
CLIENT_DIR = ACORE_ROOT / "client"

PORTS = {
    "mysql": 3306,
    "authserver": 3724,
    "worldserver": 8085,
    "ollama": 11434,
}

PROCESSES = {
    "authserver": ["pgrep", "-a", "authserver"],
    "worldserver": ["pgrep", "-a", "worldserver"],
    "llm_bridge": ["pgrep", "-a", "-f", "llm_chatter_bridge.py"],
    "ollama": ["pgrep", "-a", "-f", "ollama serve"],
}

SCRIPT_PATHS = {
    "start": SCRIPTS_DIR / "start.sh",
    "stop": SCRIPTS_DIR / "stop.sh",
    "status": SCRIPTS_DIR / "status.sh",
    "common": SCRIPTS_DIR / "common.sh",
    "setup_linux_build": SCRIPTS_DIR / "setup-linux-build.sh",
}

LOG_PATHS = {
    "authserver": LOGS_DIR / "authserver.log",
    "worldserver": LOGS_DIR / "worldserver.log",
    "llm_bridge": LOGS_DIR / "llm-chatter-bridge.log",
    "ollama": LOGS_DIR / "ollama.log",
}

BINARY_PATHS = {
    "authserver": BIN_DIR / "authserver",
    "worldserver": BIN_DIR / "worldserver",
}

CLIENT_CANDIDATES = [
    CLIENT_DIR / "Wow.exe",
    CLIENT_DIR / "Wow-64.exe",
    CLIENT_DIR / "Wow.app",
]


@dataclass
class PathStatus:
    path: str
    exists: bool
    executable: bool
    is_file: bool
    is_dir: bool
    size_bytes: int | None
    modified_at: str | None


def path_status(path: Path) -> PathStatus:
    try:
        stat = path.stat()
    except OSError:
        stat = None

    return PathStatus(
        path=str(path),
        exists=stat is not None,
        executable=path.is_file() and path.stat().st_mode & 0o111 != 0 if stat else False,
        is_file=path.is_file(),
        is_dir=path.is_dir(),
        size_bytes=stat.st_size if stat else None,
        modified_at=datetime.fromtimestamp(stat.st_mtime, timezone.utc).isoformat() if stat else None,
    )


def port_open(port: int, host: str = "127.0.0.1") -> bool:
    try:
        with socket.create_connection((host, port), timeout=0.5):
            return True
    except OSError:
        return False


def run_command(command: list[str], timeout: int = 5) -> tuple[int, str]:
    try:
        completed = subprocess.run(
            command,
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=timeout,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        return 1, str(exc)
    return completed.returncode, completed.stdout.strip()


def process_status() -> dict[str, dict[str, object]]:
    results: dict[str, dict[str, object]] = {}
    for name, command in PROCESSES.items():
        code, output = run_command(command)
        lines = [line for line in output.splitlines() if line.strip()]
        results[name] = {
            "running": code == 0 and bool(lines),
            "matches": lines,
        }
    return results


def docker_mysql_status() -> dict[str, object]:
    if shutil.which("docker") is None:
        return {"docker_present": False, "container_found": False, "container_running": False, "rows": []}

    code, output = run_command(["docker", "ps", "-a", "--format", "{{.Names}}\t{{.Status}}\t{{.Ports}}"], timeout=8)
    rows = []
    for line in output.splitlines():
        parts = line.split("\t")
        if not parts or parts[0] != "ac-mysql":
            continue
        rows.append(
            {
                "name": parts[0],
                "status": parts[1] if len(parts) > 1 else "",
                "ports": parts[2] if len(parts) > 2 else "",
            }
        )

    return {
        "docker_present": code == 0,
        "container_found": bool(rows),
        "container_running": any("Up " in row["status"] or row["status"].startswith("Up") for row in rows),
        "rows": rows,
    }


def run_bundle_status(timeout: int) -> dict[str, object]:
    status_script = SCRIPT_PATHS["status"]
    if not status_script.exists():
        return {"ran": False, "returncode": None, "output": "status.sh not found"}
    code, output = run_command([str(status_script)], timeout=timeout)
    return {"ran": True, "returncode": code, "output": output}


def build_report(include_bundle_status: bool, timeout: int) -> dict[str, object]:
    ports = {name: {"port": port, "listening": port_open(port)} for name, port in PORTS.items()}
    scripts = {name: asdict(path_status(path)) for name, path in SCRIPT_PATHS.items()}
    logs = {name: asdict(path_status(path)) for name, path in LOG_PATHS.items()}
    binaries = {name: asdict(path_status(path)) for name, path in BINARY_PATHS.items()}
    clients = {path.name: asdict(path_status(path)) for path in CLIENT_CANDIDATES}

    report: dict[str, object] = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "project_root": str(ROOT),
        "azerothcore_root": str(ACORE_ROOT),
        "ports": ports,
        "processes": process_status(),
        "docker_mysql": docker_mysql_status(),
        "scripts": scripts,
        "binaries": binaries,
        "logs": logs,
        "client_candidates": clients,
    }

    if include_bundle_status:
        report["bundle_status_script"] = run_bundle_status(timeout)

    return report


def write_markdown(report: dict[str, object], path: Path) -> None:
    lines = [
        "# Server Stack Audit",
        "",
        "This is a local-only status report. It does not start or stop services.",
        "",
        f"Generated: `{report['generated_at']}`",
        "",
        "## Ports",
        "",
    ]

    for name, info in report["ports"].items():  # type: ignore[index]
        state = "listening" if info["listening"] else "not listening"
        lines.append(f"- `{name}` on `{info['port']}`: {state}")

    lines.extend(["", "## Processes", ""])
    for name, info in report["processes"].items():  # type: ignore[index]
        state = "running" if info["running"] else "not found"
        lines.append(f"- `{name}`: {state}")

    docker = report["docker_mysql"]  # type: ignore[assignment]
    lines.extend(
        [
            "",
            "## Docker MySQL",
            "",
            f"- Docker present: {docker['docker_present']}",
            f"- `ac-mysql` container found: {docker['container_found']}",
            f"- `ac-mysql` running: {docker['container_running']}",
            "",
            "## Scripts",
            "",
        ]
    )
    for name, info in report["scripts"].items():  # type: ignore[index]
        lines.append(f"- `{name}`: exists={info['exists']}, executable={info['executable']} - `{info['path']}`")

    lines.extend(["", "## Binaries", ""])
    for name, info in report["binaries"].items():  # type: ignore[index]
        lines.append(f"- `{name}`: exists={info['exists']}, executable={info['executable']} - `{info['path']}`")

    lines.extend(["", "## Client Candidates", ""])
    for name, info in report["client_candidates"].items():  # type: ignore[index]
        lines.append(f"- `{name}`: exists={info['exists']} - `{info['path']}`")

    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--include-bundle-status", action="store_true", help="Also run AzerothCore scripts/status.sh.")
    parser.add_argument("--timeout", type=int, default=12)
    args = parser.parse_args()

    args.output_dir.mkdir(parents=True, exist_ok=True)
    report = build_report(args.include_bundle_status, args.timeout)

    json_path = args.output_dir / "server-stack-audit.json"
    md_path = args.output_dir / "server-stack-audit.md"
    json_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    write_markdown(report, md_path)

    listening = [name for name, info in report["ports"].items() if info["listening"]]  # type: ignore[index]
    print(f"Wrote {json_path}")
    print(f"Wrote {md_path}")
    print(f"Listening ports: {', '.join(listening) or 'none'}")
    print(f"MySQL container found: {report['docker_mysql']['container_found']}")  # type: ignore[index]
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
