# Stage 08 - Persistence Layer

Status: Planned

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

## Done Criteria

- A Godot character can leave and return with saved state.
- Persistence does not corrupt AzerothCore core tables.

## Documentation To Update During Work

- Storage choice.
- Schema.
- Migration notes.
- Backup/restore notes.

