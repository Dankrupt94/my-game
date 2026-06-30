# Stage 01 - Companion Dashboard

Status: Complete

## Goal

Make the Godot app useful immediately as a friendly control panel for the local AzerothCore setup.

## Deliverables

- Status panel for MySQL, authserver, worldserver, Ollama, and optional bridge service.
- Buttons for start, stop, restart, and status.
- Buttons to open auth/world/bridge logs.
- Button to launch the WotLK client.
- Path display for server, source, build, run output, and client.

## Entry Criteria

- Stage 00 complete.
- Existing AzerothCore shell scripts remain available under `/run/media/doodbro/New 1tb/AzerothCore/scripts`.

## Done Criteria

- A user can manage the local server stack from Godot without using a terminal.
- Every action reports success or failure in the UI.
- No direct database writes.

## Documentation To Update During Work

- Add button/action list.
- Record any script path assumptions.
- Record launch command for the WotLK client.
- Record screenshots or manual test notes if useful.

## Current Notes

- Existing stack scripts are under `/run/media/doodbro/New 1tb/AzerothCore/scripts`.
- Status script: `/run/media/doodbro/New 1tb/AzerothCore/scripts/status.sh`.
- Start script: `/run/media/doodbro/New 1tb/AzerothCore/scripts/start.sh`.
- Stop script: `/run/media/doodbro/New 1tb/AzerothCore/scripts/stop.sh`.
- Added `tools/audit_server_stack.py` as a safe status source for ports, processes, Docker MySQL, scripts, binaries, logs, and client candidates.
- First audit found only Ollama listening; MySQL, authserver, and worldserver were not listening.
- First audit did not find Linux auth/world binaries under `/run/media/doodbro/New 1tb/AzerothCore/run/bin`.
- First audit found the bundle client executable at `/run/media/doodbro/New 1tb/AzerothCore/client/Wow.exe`.
- Godot Snap cannot currently see Docker from child processes, so dashboard start/stop buttons are guarded until a localhost bridge or native runner exists.
- Added a localhost bridge client path so the dashboard can use host-side status/start/stop when `tools/host_control_bridge.py` is running.
- Linux `authserver` and `worldserver` binaries are now installed under `/run/media/doodbro/New 1tb/AzerothCore/run/bin`.
- The configured auth/world/characters databases are reachable.
- Runtime data extraction is complete and tracked in `docs/runtime-data-extraction-plan.md`.
- Runtime data readiness is tracked by file counts in the dashboard and `tools/audit_server_stack.py`.
- The local stack has been verified with MySQL `3306`, authserver `3724`, worldserver `8085`, Ollama `11434`, and the LLM bridge running.
- The host bridge has been verified against the live stack for health, status, and idempotent start.
- Godot 4.7 loads the dashboard scene headlessly through `scripts/run_game.sh` with the bridge online.
## Completion Notes

- The visible restart action exists through the Stage 02 command layer.
- The dashboard launches through `scripts/run_game.sh` with the host bridge online.
- The bridge stop/start path was tested during Stage 09. The first restart exposed a local AzerothCore `scripts/start.sh` issue where an existing stopped `ac-mysql` container was not restarted. That local script was repaired to start the existing container before creating a new one.
- After repair, the local stack returned to live ports for MySQL `3306`, authserver `3724`, worldserver `8085`, and Ollama `11434`.
