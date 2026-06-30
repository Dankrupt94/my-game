# Stage 08 - Persistence Layer

Status: In Progress

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

- A Godot character can leave and return with saved state.
- Persistence does not corrupt AzerothCore core tables.

## Documentation To Update During Work

- Storage choice.
- Schema.
- Migration notes.
- Backup/restore notes.
