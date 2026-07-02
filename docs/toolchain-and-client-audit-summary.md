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

- **Godot Engine:** Godot 4.7 Mono (via `godot-4`).
- **Core VCS/CLI:** Git and GitHub CLI.
- **Languages/Packages:** Python3/pip3, Node/npm, Rust/Cargo.
- **Compilers/Linkers:** CMake, Make, GCC, and G++.
- **Containerization:** Docker.
- **Local AI:** Ollama running `qwen-agent:latest` and `qwen2.5-coder:7b`.
- **System Utilities:** `ffmpeg`, `7z`, `unzip`, `jq`, `sqlite3`, and `mysql_config`.
- **Database Client:** `mysql` and `mysqldump` (via `default-mysql-client`).
- **Database Convenience:** `mycli`.
- **Protocol/Socket Diagnostics:** `tshark`, `termshark`, `socat`, `ss`, and `tc`.
- **Binary/Native Debugging:** `hexyl`, `strace`, `lsof`, `gdb`, and `heaptrack`.
- **Native Build Speed/IDE Tools:** `ninja-build`, `ccache`, `clang-tidy`,
  `clangd`, and `lldb` were installed on 2026-07-01 for faster repeated
  protocol/Godot extension work and easier native debugging.
- **GDScript Quality:** `gdformat` and `gdlint`.
- **Shell/Workflow Helpers:** `delta`, `btop`, `entr`, `direnv`, and `shellcheck`.

Developer/debugging tools added after the first audit:

- **Graphics/Visuals:** `blender`, `assimp`, `gltf-transform`, `gltfpack`,
  `magick`, and `convert`.
- **Multi-Client Test Automation:** `xdotool` and `wmctrl`.
- **Headless GUI Testing:** `xvfb-run`.
- **Rust GDExtension Building:** `cargo-watch`.
- **Local DB Exporters:** `sqlite-utils`.
- **Protocol Crafting:** `scapy`.
- **Client Automation:** `wine`.
- **Graphics Diagnostics:** `apitrace`.

Still missing or deferred developer/debugging tools:

- **MPQ Parsing:** `mpqtool` (recommended MPQ viewer/extractor).
- **GPU Frame Debugging:** `renderdoccmd` (not available from apt or Snap on
  this machine during the 2026-07-01 playable-toolchain pass).
- **Other:** `go` (optional) and `podman` (optional, since Docker is present).

The repeatable checker is documented in
[playable-toolchain.md](playable-toolchain.md) and implemented at
`tools/check_playable_toolchain.sh`.

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

## Database Audit Result

The read-only AzerothCore database audit script completed and wrote detailed local reports to:

```text
local_reports/azerothcore-db-audit.json
local_reports/azerothcore-db-audit.md
```

Summary:

- Unique database connections parsed from local AzerothCore configs: 3.
- Databases detected: `acore_auth`, `acore_world`, `acore_characters`.
- Reachable databases during this run: 0.
- Local result: MySQL refused connections on `127.0.0.1:3306`, so the database service is likely stopped or not listening there.

The script only performs read-only checks and redacts credentials in reports.

## Local AI Review

`qwen-agent:latest` was used as a safe advisory reviewer for this tooling slice. It recommended keeping optional hashes available and making the scanner friendlier to large directories.

Follow-up applied:

- `client_manifest_scan.py` keeps hashing disabled by default, with explicit optional hash modes.
- `client_manifest_scan.py` now walks directories incrementally instead of sorting the entire recursive file list at once.

## Next Tooling Actions

- Standing project preference: install or integrate needed development tools
  proactively as the Godot port demands them, then record the reason, validation,
  and Git/privacy boundary in the project docs.
- Use `tools/build_godot_protocol_build_image.sh` to build the cached Docker
  image `acore-godot-protocol-build:24.04`. The compatibility extension build
  now uses this image by default and avoids reinstalling compiler packages every
  run. The image was built locally on 2026-07-01 and the compatibility build
  was re-run successfully through it.
- `tools/build_godot_protocol_extension_compat.sh` now preserves existing CMake
  build folders but uses Ninja automatically for fresh ones and enables ccache
  for the CMake protocol/extension builds. Set
  `ACORE_REBUILD_GODOT_EXTENSION_BUILD_IMAGE=1` when intentionally refreshing
  the cached Docker tool image.
- Add a Godot dashboard action that can run the local audits and show friendly status text.
- Add read-only database summaries to the dashboard once the local AzerothCore MySQL service is reachable.
- Add server-stack discovery so the dashboard can find or start the local MySQL/auth/world services.
- Use `tools/check_playable_toolchain.sh` before asset-pipeline, GUI
  automation, or local reference-client comparison work.
