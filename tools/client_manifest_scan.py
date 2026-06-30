#!/usr/bin/env python3
"""Scan local WotLK client files and write metadata-only local reports."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from collections import Counter
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT_DIR = ROOT / "local_reports"
DEFAULT_CLIENT_ROOTS = [
    Path("/run/media/doodbro/New 1tb/AzerothCore/client"),
    Path("/run/media/doodbro/5e07d7d7-039f-43a8-94da-999f100ab1fb/World of Warcraft - WoTLK"),
]

PROPRIETARY_EXTENSIONS = {
    ".adt",
    ".anim",
    ".blp",
    ".dbc",
    ".db2",
    ".m2",
    ".mpq",
    ".wdl",
    ".wdt",
    ".wmo",
}


@dataclass
class FileEntry:
    root: str
    relative_path: str
    extension: str
    size_bytes: int
    modified_at: str
    sha256: str | None


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def should_hash(path: Path, mode: str, size_bytes: int, limit_bytes: int) -> bool:
    if mode == "none":
        return False
    if mode == "sha256":
        return True
    if mode == "small":
        return size_bytes <= limit_bytes
    if mode == "proprietary-small":
        return path.suffix.lower() in PROPRIETARY_EXTENSIONS and size_bytes <= limit_bytes
    raise ValueError(f"unknown hash mode: {mode}")


def iter_files(root: Path, max_files: int | None) -> Iterable[Path]:
    seen = 0
    for directory, dirnames, filenames in os.walk(root):
        dirnames.sort()
        for filename in sorted(filenames):
            path = Path(directory) / filename
            if path.is_symlink():
                continue
            yield path
            seen += 1
            if max_files is not None and seen >= max_files:
                return


def scan_root(root: Path, hash_mode: str, hash_limit_bytes: int, max_files: int | None) -> list[FileEntry]:
    entries: list[FileEntry] = []
    if not root.exists():
        return entries

    for path in iter_files(root, max_files):
        try:
            stat = path.stat()
        except OSError:
            continue
        digest = sha256_file(path) if should_hash(path, hash_mode, stat.st_size, hash_limit_bytes) else None
        entries.append(
            FileEntry(
                root=str(root),
                relative_path=str(path.relative_to(root)),
                extension=path.suffix.lower(),
                size_bytes=stat.st_size,
                modified_at=datetime.fromtimestamp(stat.st_mtime, timezone.utc).isoformat(),
                sha256=digest,
            )
        )
    return entries


def summarize(entries: list[FileEntry], roots: list[Path]) -> dict[str, object]:
    by_extension: Counter[str] = Counter(entry.extension or "[none]" for entry in entries)
    bytes_by_extension: Counter[str] = Counter()
    by_root: Counter[str] = Counter(entry.root for entry in entries)
    for entry in entries:
        bytes_by_extension[entry.extension or "[none]"] += entry.size_bytes

    largest = sorted(entries, key=lambda item: item.size_bytes, reverse=True)[:20]
    proprietary = [entry for entry in entries if entry.extension in PROPRIETARY_EXTENSIONS]

    return {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "project_root": str(ROOT),
        "requested_roots": [str(root) for root in roots],
        "existing_roots": [str(root) for root in roots if root.exists()],
        "total_files": len(entries),
        "total_bytes": sum(entry.size_bytes for entry in entries),
        "proprietary_extension_files": len(proprietary),
        "proprietary_extension_bytes": sum(entry.size_bytes for entry in proprietary),
        "file_count_by_root": dict(sorted(by_root.items())),
        "file_count_by_extension": dict(sorted(by_extension.items())),
        "bytes_by_extension": dict(sorted(bytes_by_extension.items())),
        "largest_files": [asdict(entry) for entry in largest],
    }


def write_markdown(summary: dict[str, object], entries: list[FileEntry], path: Path) -> None:
    by_extension = summary["file_count_by_extension"]  # type: ignore[assignment]
    bytes_by_extension = summary["bytes_by_extension"]  # type: ignore[assignment]
    by_root = summary["file_count_by_root"]  # type: ignore[assignment]
    largest = summary["largest_files"]  # type: ignore[assignment]

    lines = [
        "# Client File Manifest Summary",
        "",
        "This is a metadata-only local report. It does not contain proprietary file payloads.",
        "",
        f"Generated: `{summary['generated_at']}`",
        "",
        "## Totals",
        "",
        f"- Files scanned: {summary['total_files']}",
        f"- Total bytes: {summary['total_bytes']}",
        f"- Files with proprietary client extensions: {summary['proprietary_extension_files']}",
        f"- Bytes with proprietary client extensions: {summary['proprietary_extension_bytes']}",
        "",
        "## Roots",
        "",
    ]
    for root, count in by_root.items():
        lines.append(f"- `{root}`: {count} files")

    lines.extend(["", "## Extension Counts", "", "| Extension | Files | Bytes |", "| --- | ---: | ---: |"])
    for extension, count in by_extension.items():
        lines.append(f"| `{extension}` | {count} | {bytes_by_extension.get(extension, 0)} |")

    lines.extend(["", "## Largest Files", "", "| Relative Path | Extension | Bytes | Root |", "| --- | --- | ---: | --- |"])
    for item in largest:
        lines.append(
            f"| `{item['relative_path']}` | `{item['extension'] or '[none]'}` | {item['size_bytes']} | `{item['root']}` |"
        )

    hashed = sum(1 for entry in entries if entry.sha256)
    lines.extend(["", "## Hashing", "", f"- Files with SHA-256 hashes in JSON manifest: {hashed}"])
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", action="append", type=Path, dest="roots", help="Client root to scan. May be used more than once.")
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument(
        "--hash-mode",
        choices=["none", "small", "proprietary-small", "sha256"],
        default="none",
        help="Hashing mode. Default avoids reading file payloads beyond normal metadata.",
    )
    parser.add_argument("--hash-limit-mib", type=int, default=64, help="Per-file hash cap for small hashing modes.")
    parser.add_argument("--max-files", type=int, default=None, help="Optional file cap per root.")
    args = parser.parse_args()

    roots = args.roots if args.roots else DEFAULT_CLIENT_ROOTS
    hash_limit_bytes = args.hash_limit_mib * 1024 * 1024
    entries: list[FileEntry] = []
    for root in roots:
        entries.extend(scan_root(root, args.hash_mode, hash_limit_bytes, args.max_files))

    args.output_dir.mkdir(parents=True, exist_ok=True)
    summary = summarize(entries, roots)
    manifest = {
        "summary": summary,
        "files": [asdict(entry) for entry in entries],
    }

    json_path = args.output_dir / "client-file-manifest.json"
    md_path = args.output_dir / "client-file-manifest.md"
    json_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    write_markdown(summary, entries, md_path)

    print(f"Wrote {json_path}")
    print(f"Wrote {md_path}")
    print(f"Files scanned: {summary['total_files']}")
    print(f"Proprietary-extension files: {summary['proprietary_extension_files']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
