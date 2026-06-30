# Server Stack Discovery Summary

## Purpose

This document records the first safe discovery pass for the local AzerothCore runtime stack.

Detailed generated reports are local-only and ignored by Git:

```text
local_reports/server-stack-audit.json
local_reports/server-stack-audit.md
```

## Known Control Scripts

The local AzerothCore bundle provides these Linux scripts:

- Start stack: `/run/media/doodbro/New 1tb/AzerothCore/scripts/start.sh`
- Stop stack: `/run/media/doodbro/New 1tb/AzerothCore/scripts/stop.sh`
- Status check: `/run/media/doodbro/New 1tb/AzerothCore/scripts/status.sh`
- Shared config/helpers: `/run/media/doodbro/New 1tb/AzerothCore/scripts/common.sh`

The Godot companion should call these scripts rather than duplicate their behavior.

## Status Tool

Added:

```text
tools/audit_server_stack.py
```

The tool checks:

- MySQL, authserver, worldserver, and Ollama ports.
- `authserver`, `worldserver`, LLM bridge, and Ollama processes.
- Docker `ac-mysql` container state.
- Existing start/stop/status scripts.
- Linux auth/world binaries.
- Required local runtime data directories and file counts for maps, DBC, VMap, and MMap output.
- Known log file paths.
- WotLK client launch candidates.

## First Run Result

Current safe-status result:

- Listening ports: Ollama only.
- MySQL port `3306`: not listening.
- Authserver port `3724`: not listening.
- Worldserver port `8085`: not listening.
- Docker `ac-mysql` container: not found during this audit.
- Linux `authserver` binary under `run/bin`: not found.
- Linux `worldserver` binary under `run/bin`: not found.
- Bundle client `Wow.exe`: found.

This matches the read-only database audit result: the database configs are present, but the local MySQL runtime is not currently up.

## 2026-06-30 Runtime Repair Checkpoint

Safe-status result after building and installing Linux server binaries, before runtime data extraction:

- MySQL port `3306`: listening on localhost.
- Authserver port `3724`: not listening after world startup attempt.
- Worldserver port `8085`: not listening.
- Docker `ac-mysql` container: found and running.
- Linux `authserver` binary under `run/bin`: found and executable.
- Linux `worldserver` binary under `run/bin`: found and executable.
- Database audit: all configured auth/world/characters databases reachable.
- Bundle client `Wow.exe`: found.

Runtime repairs are recorded in [local-runtime-repairs.md](local-runtime-repairs.md).

The earlier blocker was missing local runtime data under `/run/media/doodbro/New 1tb/AzerothCore/data`. That blocker is now cleared. The audit records directory readiness and file counts for maps, DBC, VMap, and MMap output.

## 2026-06-30 Runtime Data And Startup Checkpoint

Current safe-status result after runtime data extraction and startup-script repair:

- MySQL port `3306`: listening.
- Authserver port `3724`: listening.
- Worldserver port `8085`: listening.
- Ollama port `11434`: listening.
- Docker `ac-mysql` container: found and running.
- Linux `authserver` binary under `run/bin`: found and executable.
- Linux `worldserver` binary under `run/bin`: found and executable.
- Runtime data ready: true.
- Data counts: 5744 map files, 246 DBC files, 2794 VMap files, and 3780 MMap files.
- LLM bridge process: running.

The local `start.sh` script was repaired so it checks real runtime-data counts, detaches long-lived server processes for desktop/script launches, and disables the interactive worldserver console in copied runtime configs.

## Godot Snap Runtime Note

When the dashboard is launched through Snap Godot, its child processes cannot currently see Docker. Terminal-launched audits can see `/usr/bin/docker`, but Godot-launched audits report Docker as unavailable inside the Snap sandbox.

Current dashboard behavior:

- Status refresh still works for paths, ports, and client checks.
- Start/stop buttons are guarded when Docker is unavailable inside Snap.
- A localhost bridge or native/non-Snap Godot runner is the next clean way to let the Godot UI control Docker-backed services.

Bridge work has started in [host-control-bridge.md](host-control-bridge.md).

## Next Stage 01 Actions

- Use the live stack as the local server target for the next Godot/AzerothCore bridge and data-inspection steps.
- Keep start/stop actions routed through the existing AzerothCore scripts and host bridge.
- Keep runtime data local-only and out of Git.
