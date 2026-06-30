# Stage 08 - Persistence Layer

Status: Complete

## Goal

Persist Godot-native gameplay state safely.

## Deliverables

- Godot test identity/account records.
- Godot test character records.
- Saved position.
- Saved health/resource values.
- Placeholder inventory state.
- Logout/login reload flow.

## Storage Options

- Separate SQLite file.
- Separate companion MySQL tables.
- Bridge-managed persistence.

## Entry Criteria

- Stage 07 multiplayer loop works locally.

## Stage Start Notes

- Stage 08 begins after the Godot-native multiplayer smoke test.
- The first persistence slice must not write to AzerothCore `auth`, `characters`, or `world` tables.
- Use local-only ignored storage under `local_runtime/` for Godot sandbox state.
- Persist only original Godot test identity, character, position, health/focus, and placeholder inventory data.

## Done Criteria

- [x] A Godot character can leave and return with saved state.
- [x] Persistence does not corrupt AzerothCore core tables.

## Implementation Notes

- Storage choice: ignored local JSON file at `local_runtime/sandbox-state.json`.
- Added sandbox `Save`, `Load`, and `Reload` buttons.
- `Reload` saves, clears in-memory state, then loads again to simulate logout/login reload.
- Persisted fields:
  - local test identity,
  - local test character,
  - position,
  - health,
  - focus,
  - quest flags,
  - placeholder inventory.
- No AzerothCore database writes are introduced.
- Added `ACORE_SANDBOX_PERSISTENCE_SELF_TEST=1`.

## Schema

- `schema_version`: currently `1`.
- `identity`: local Godot test identity.
- `character`: local Godot test character.
- `position`: `x`, `y`, `z` sandbox coordinates.
- `health`: player health value.
- `focus`: player resource value.
- `quest_started` and `quest_complete`: sandbox task flags.
- `inventory`: placeholder item-name array.

## Migration Notes

- Future schema changes should increment `schema_version`.
- If this grows beyond one local test character, migrate to SQLite under `local_runtime/` or a bridge-managed local table outside AzerothCore core schemas.

## Backup/Restore Notes

- Backup by copying `local_runtime/sandbox-state.json` to another ignored local file.
- Restore by copying the backup back to `local_runtime/sandbox-state.json`.
- Do not commit save files.

## Validation

Completed on 2026-06-30:

- `ACORE_SANDBOX_PERSISTENCE_SELF_TEST=1 snap run godot-4 --headless --quit-after 120 --path ".../godot-azerothcore-companion" --scene res://scenes/gameplay_sandbox.tscn` printed `SANDBOX_PERSISTENCE_SELF_TEST_OK`.
- The generated save file stayed under ignored `local_runtime/`.

## Documentation To Update During Work

- [x] Storage choice.
- [x] Schema.
- [x] Migration notes.
- [x] Backup/restore notes.
