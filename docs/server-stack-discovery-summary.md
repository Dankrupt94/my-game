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

## Godot Snap Runtime Note

When the dashboard is launched through Snap Godot, its child processes cannot currently see Docker. Terminal-launched audits can see `/usr/bin/docker`, but Godot-launched audits report Docker as unavailable inside the Snap sandbox.

Current dashboard behavior:

- Status refresh still works for paths, ports, and client checks.
- Start/stop buttons are guarded when Docker is unavailable inside Snap.
- A localhost bridge or native/non-Snap Godot runner is the next clean way to let the Godot UI control Docker-backed services.

Bridge work has started in [host-control-bridge.md](host-control-bridge.md).

## Next Stage 01 Actions

- Add Godot dashboard buttons for status, start, stop, and log opening.
- Make the dashboard show the current status from this tool or an equivalent Godot-side status check.
- Keep start/stop actions routed through the existing AzerothCore scripts.
- Add a localhost bridge or native runner so the Snap dashboard can request host-side start/stop safely.
