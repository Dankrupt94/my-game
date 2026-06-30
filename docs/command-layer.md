# Command Layer

## Purpose

The dashboard now routes button clicks through named actions instead of calling scattered handlers directly.

This is the Stage 02 foundation for adding more AzerothCore/Godot tooling without turning the UI into one-off command glue.

## Current Action Registry

The action registry lives in `scripts/companion_dashboard.gd`.

Current actions:

- `status`: refresh bridge/direct server-stack status and reload the local report.
- `start_stack`: start the AzerothCore stack through the host bridge when available, with direct script fallback.
- `stop_stack`: stop the AzerothCore stack through the host bridge when available, with direct script fallback.
- `restart_stack`: run stop then start through the same command path.
- `data_browser`: fetch the selected read-only AzerothCore data view through the host bridge and update the dashboard Data Snapshot/results panel.
- `open_logs`: open the local AzerothCore logs folder.
- `open_reports`: open this repo's ignored local reports folder.
- `launch_client`: launch the bundle `Wow.exe` through Wine if Wine is installed.

## Command Output

Every action writes to the dashboard command output panel.

Command results include:

- action name,
- exit code,
- command output or friendly message,
- refreshed status after start/stop/restart actions.

## Safety Notes

- The status action is read-only.
- The data summary action is read-only.
- Start/stop/restart use the existing local AzerothCore scripts.
- Snap-limited direct start/stop remains guarded when the host bridge is offline.
- No database writes are introduced by this command layer.

## Validation

Validated on 2026-06-30:

- Godot 4.7 loads the dashboard scene headlessly after the command-layer refactor.
- The host bridge is online during the launch.
- The live stack remains visible through the bridge.
