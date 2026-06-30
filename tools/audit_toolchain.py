#!/usr/bin/env python3
"""Audit local development tools for the Godot/AzerothCore prototype."""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT_DIR = ROOT / "local_reports"

KNOWN_PATHS = {
    "project": ROOT,
    "azerothcore_bundle": Path("/run/media/doodbro/New 1tb/AzerothCore"),
    "azerothcore_source": Path("/run/media/doodbro/New 1tb/AzerothCore/source"),
    "azerothcore_build": Path("/home/doodbro/azeroth-build"),
    "azerothcore_run": Path("/run/media/doodbro/New 1tb/AzerothCore/run"),
    "wotlk_client": Path("/run/media/doodbro/5e07d7d7-039f-43a8-94da-999f100ab1fb/World of Warcraft - WoTLK"),
    "bundle_client": Path("/run/media/doodbro/New 1tb/AzerothCore/client"),
}

TOOL_GROUPS = {
    "core": ["git", "gh", "python3", "pip3", "node", "npm", "rg", "jq"],
    "godot": ["godot-4"],
    "build": ["cmake", "make", "gcc", "g++", "rustc", "cargo", "go"],
    "data": ["sqlite3", "mysql", "mysql_config", "mysqldump", "mycli"],
    "containers": ["docker", "podman"],
    "diagnostics": ["tshark", "termshark", "socat", "hexyl", "gdformat", "gdlint", "mpqtool"],
    "assets": ["ffmpeg", "blender", "7z", "unzip", "wine"],
    "ai": ["ollama"],
}

VERSION_COMMANDS = {
    "7z": ["7z"],
    "blender": ["blender", "--version"],
    "cargo": ["cargo", "--version"],
    "cmake": ["cmake", "--version"],
    "docker": ["docker", "--version"],
    "ffmpeg": ["ffmpeg", "-version"],
    "g++": ["g++", "--version"],
    "gcc": ["gcc", "--version"],
    "gdformat": ["gdformat", "--version"],
    "gdlint": ["gdlint", "--version"],
    "gh": ["gh", "--version"],
    "git": ["git", "--version"],
    "godot-4": ["godot-4", "--version"],
    "go": ["go", "version"],
    "hexyl": ["hexyl", "--version"],
    "jq": ["jq", "--version"],
    "make": ["make", "--version"],
    "mpqtool": ["mpqtool", "--version"],
    "mycli": ["mycli", "--version"],
    "mysql": ["mysql", "--version"],
    "mysql_config": ["mysql_config", "--version"],
    "mysqldump": ["mysqldump", "--version"],
    "node": ["node", "--version"],
    "npm": ["npm", "--version"],
    "ollama": ["ollama", "--version"],
    "pip3": ["pip3", "--version"],
    "podman": ["podman", "--version"],
    "python3": ["python3", "--version"],
    "rg": ["rg", "--version"],
    "rustc": ["rustc", "--version"],
    "socat": ["socat", "-V"],
    "sqlite3": ["sqlite3", "--version"],
    "tshark": ["tshark", "--version"],
    "termshark": ["termshark", "--version"],
    "unzip": ["unzip", "-v"],
    "wine": ["wine", "--version"],
}

MISSING_TOOL_NOTES = {
    "go": {
        "priority": "optional",
        "note": "Useful if future protocol or asset tools are written in Go.",
    },
    "mysql": {
        "priority": "recommended",
        "note": "Needed for direct read-only database inspection from scripts.",
    },
    "mysqldump": {
        "priority": "recommended",
        "note": "Useful for safe database snapshots before read/write experiments.",
    },
    "mycli": {
        "priority": "recommended",
        "note": "Terminal MySQL client with auto-completion and syntax highlighting.",
    },
    "tshark": {
        "priority": "recommended",
        "note": "Lightweight packet capture utility for analyzing the WotLK socket protocol.",
    },
    "termshark": {
        "priority": "optional",
        "note": "Terminal-UI viewer for tshark packet captures.",
    },
    "socat": {
        "priority": "optional",
        "note": "Socket debugger for testing local network connections.",
    },
    "hexyl": {
        "priority": "recommended",
        "note": "Colored hex viewer for inspecting binary packets and client files.",
    },
    "gdformat": {
        "priority": "recommended",
        "note": "GDScript code formatter for style guidelines.",
    },
    "gdlint": {
        "priority": "recommended",
        "note": "GDScript linter to maintain code quality.",
    },
    "mpqtool": {
        "priority": "recommended",
        "note": "CLI reader and extractor for Blizzard .MPQ archives.",
    },
    "podman": {
        "priority": "optional",
        "note": "Docker is already available, so Podman is not required.",
    },
    "blender": {
        "priority": "needed later",
        "note": "Needed for model conversion and visual asset pipeline experiments.",
    },
    "wine": {
        "priority": "needed later",
        "note": "Needed if Linux launches or automation around the Windows WotLK client is required.",
    },
}


@dataclass
class ToolResult:
    name: str
    group: str
    present: bool
    path: str | None
    version: str | None


def run_version(command: list[str]) -> str | None:
    try:
        completed = subprocess.run(
            command,
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=10,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None

    output = completed.stdout.strip().splitlines()
    return output[0].strip() if output else None


def audit_tools() -> list[ToolResult]:
    results: list[ToolResult] = []
    for group, names in TOOL_GROUPS.items():
        for name in names:
            path = shutil.which(name)
            version = run_version(VERSION_COMMANDS.get(name, [name, "--version"])) if path else None
            results.append(
                ToolResult(
                    name=name,
                    group=group,
                    present=path is not None,
                    path=path,
                    version=version,
                )
            )
    return results


def audit_paths() -> dict[str, dict[str, str | bool]]:
    return {
        name: {
            "path": str(path),
            "exists": path.exists(),
            "is_dir": path.is_dir(),
            "is_file": path.is_file(),
        }
        for name, path in KNOWN_PATHS.items()
    }


def docker_containers() -> list[str]:
    if shutil.which("docker") is None:
        return []
    try:
        completed = subprocess.run(
            ["docker", "ps", "--format", "{{.Names}}"],
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            timeout=10,
        )
    except (OSError, subprocess.TimeoutExpired):
        return []
    return [line.strip() for line in completed.stdout.splitlines() if line.strip()]


def ollama_models() -> list[str]:
    if shutil.which("ollama") is None:
        return []
    try:
        completed = subprocess.run(
            ["ollama", "list"],
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            timeout=10,
        )
    except (OSError, subprocess.TimeoutExpired):
        return []

    lines = [line for line in completed.stdout.splitlines()[1:] if line.strip()]
    return [line.split()[0] for line in lines]


def build_report() -> dict[str, object]:
    tools = audit_tools()
    missing = [tool.name for tool in tools if not tool.present]
    return {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "project_root": str(ROOT),
        "tools": [asdict(tool) for tool in tools],
        "paths": audit_paths(),
        "docker_containers": docker_containers(),
        "ollama_models": ollama_models(),
        "missing_tools": missing,
        "missing_tool_notes": {
            name: MISSING_TOOL_NOTES.get(name, {"priority": "unknown", "note": "No project-specific note yet."})
            for name in missing
        },
    }


def markdown_table(rows: Iterable[ToolResult]) -> str:
    lines = [
        "| Group | Tool | Status | Version | Path |",
        "| --- | --- | --- | --- | --- |",
    ]
    for tool in rows:
        status = "present" if tool.present else "missing"
        version = tool.version or ""
        path = tool.path or ""
        lines.append(f"| {tool.group} | `{tool.name}` | {status} | {version} | `{path}` |")
    return "\n".join(lines)


def write_markdown(report: dict[str, object], path: Path) -> None:
    tool_rows = [ToolResult(**item) for item in report["tools"]]  # type: ignore[arg-type]
    path_rows = report["paths"]  # type: ignore[assignment]
    missing = report["missing_tools"]  # type: ignore[assignment]
    missing_notes = report["missing_tool_notes"]  # type: ignore[assignment]
    docker = report["docker_containers"]  # type: ignore[assignment]
    models = report["ollama_models"]  # type: ignore[assignment]

    lines = [
        "# Toolchain Audit",
        "",
        f"Generated: `{report['generated_at']}`",
        "",
        "## Summary",
        "",
        f"- Present tools: {sum(1 for tool in tool_rows if tool.present)}",
        f"- Missing tools: {len(missing)}",
        f"- Running Docker containers seen: {len(docker)}",
        f"- Ollama models seen: {len(models)}",
        "",
        "## Missing Tools",
        "",
    ]
    if missing:
        for name in missing:
            note = missing_notes[name]
            lines.append(f"- `{name}`: {note['priority']} - {note['note']}")
    else:
        lines.append("- None")
    lines.extend(["", "## Tools", "", markdown_table(tool_rows), "", "## Known Paths", ""])
    for name, info in path_rows.items():
        status = "exists" if info["exists"] else "missing"
        lines.append(f"- `{name}`: {status} - `{info['path']}`")
    lines.extend(["", "## Ollama Models", ""])
    lines.extend([f"- `{model}`" for model in models] or ["- None seen"])
    lines.extend(["", "## Docker Containers", ""])
    lines.extend([f"- `{container}`" for container in docker] or ["- None seen"])
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    args = parser.parse_args()

    args.output_dir.mkdir(parents=True, exist_ok=True)
    report = build_report()

    json_path = args.output_dir / "toolchain-audit.json"
    md_path = args.output_dir / "toolchain-audit.md"
    json_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    write_markdown(report, md_path)

    print(f"Wrote {json_path}")
    print(f"Wrote {md_path}")
    print(f"Missing tools: {', '.join(report['missing_tools']) or 'none'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
