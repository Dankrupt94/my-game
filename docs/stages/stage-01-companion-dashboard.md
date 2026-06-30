# Stage 01 - Companion Dashboard

Status: In Progress

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
