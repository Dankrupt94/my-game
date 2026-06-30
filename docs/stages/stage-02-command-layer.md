# Stage 02 - Command Layer

Status: Planned

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

