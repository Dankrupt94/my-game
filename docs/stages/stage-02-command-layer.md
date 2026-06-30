# Stage 02 - Command Layer

Status: Complete

## Goal

Create a safe command layer so UI buttons call named actions instead of scattered shell commands.

## Deliverables

- Godot command runner module.
- Action registry for `status`, `start`, `stop`, `restart`, `open_log`, and `launch_client`.
- Output capture panel.
- Exit code handling.
- Friendly errors for missing Docker, missing binaries, missing maps, stopped MySQL, or missing client.

## Entry Criteria

- Stage 01 dashboard buttons exist.

## Done Criteria

- Dashboard buttons use named command actions.
- Command output is visible inside Godot.
- Failed commands do not crash the app.

## Documentation To Update During Work

- List each command action.
- Record command arguments.
- Record expected output/exit-code behavior.

## Current Notes

- Added a named action registry in `scripts/companion_dashboard.gd`.
- Dashboard buttons now route through action IDs instead of direct one-off callbacks.
- Added a `restart_stack` action to the registry and UI.
- Added a `data_browser` action for Stage 03 read-only views.
- The current action list is documented in [../command-layer.md](../command-layer.md).
- Godot 4.7 loads the dashboard scene headlessly after the refactor.

## Completion Notes

- Dashboard buttons use named command actions.
- Command output is visible inside Godot.
- Failed or unavailable bridge actions report to the output panel instead of crashing the app.
