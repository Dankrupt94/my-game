# Stage 01 - Companion Dashboard

Status: Planned

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

