# Toolchain And Client Audit Summary

## Purpose

This document records the first autonomous tooling pass for the Godot-AzerothCore-WotLK prototype.

Detailed generated reports are local-only and ignored by Git:

```text
local_reports/toolchain-audit.json
local_reports/toolchain-audit.md
local_reports/client-file-manifest.json
local_reports/client-file-manifest.md
```

## Toolchain Result

Confirmed present on this machine:

- Godot 4.7 Mono through `godot-4`.
- Git and GitHub CLI.
- Python and pip.
- Node and npm.
- Rust and Cargo.
- CMake, Make, GCC, and G++.
- Docker.
- Ollama with `qwen-agent:latest` and `qwen2.5-coder:7b`.
- `ffmpeg`, `7z`, `unzip`, `jq`, `rg`, `sqlite3`, and `mysql_config`.

Missing or deferred:

- `mysql` and `mysqldump`: recommended soon for safe read-only database inspection and snapshots.
- `blender`: needed later for model conversion and Godot visual pipeline experiments.
- `wine`: needed later if Linux launch automation around the Windows WotLK client is required.
- `go`: optional unless future tooling needs Go.
- `podman`: optional because Docker is already available.

## Client Manifest Result

The metadata-only client scanner completed successfully.

Summary:

- Files scanned: 26,928.
- Total bytes represented by local metadata: 37,074,818,552.
- Files with proprietary client-style extensions: 986.
- Bytes with proprietary client-style extensions: 34,456,393,810.
- Existing client roots scanned:
  - `/run/media/doodbro/New 1tb/AzerothCore/client`
  - `/run/media/doodbro/5e07d7d7-039f-43a8-94da-999f100ab1fb/World of Warcraft - WoTLK`

The detailed manifest stays in `local_reports/` and is not committed.

## Local AI Review

`qwen-agent:latest` was used as a safe advisory reviewer for this tooling slice. It recommended keeping optional hashes available and making the scanner friendlier to large directories.

Follow-up applied:

- `client_manifest_scan.py` keeps hashing disabled by default, with explicit optional hash modes.
- `client_manifest_scan.py` now walks directories incrementally instead of sorting the entire recursive file list at once.

## Next Tooling Actions

- Install or otherwise enable `mysql` and `mysqldump`.
- Add a database read-only connection audit after the MySQL client tools exist.
- Add a Godot dashboard action that can run the local audits and show friendly status text.
- Defer Blender/Wine installation until the project reaches the asset conversion or client-launch automation stage.
