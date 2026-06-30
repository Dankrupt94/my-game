# Persistence Layer

## Purpose

Stage 08 persists Godot-native sandbox state without writing into AzerothCore core tables.

This is local Path A persistence only. It is not WotLK character persistence and does not touch `acore_auth`, `acore_characters`, or `acore_world`.

## Storage Choice

Current storage:

```text
local_runtime/sandbox-state.json
```

This file is ignored by Git through the existing `local_runtime/` rule.

JSON was chosen for the first slice because it is simple for Godot to read/write directly and easy for a beginner to inspect. SQLite can still replace it later if Stage 08 grows into multiple characters/accounts/inventories.

## Schema

```json
{
  "schema_version": 1,
  "identity": {
    "id": "local_sandbox_user",
    "display_name": "Local Sandbox User"
  },
  "character": {
    "id": "local_sandbox_character",
    "name": "Sandbox Scout"
  },
  "position": {
    "x": 0.0,
    "y": 1.0,
    "z": 4.0
  },
  "health": 100.0,
  "focus": 100.0,
  "quest_started": false,
  "quest_complete": false,
  "inventory": ["Practice Token"]
}
```

## Sandbox Flow

- `Save`: writes current sandbox state.
- `Load`: reloads the saved sandbox state.
- `Reload`: saves, resets in-memory values, then loads again to simulate a logout/login reload.

## Backup And Restore

Backup:

```bash
cp local_runtime/sandbox-state.json local_runtime/sandbox-state.backup.json
```

Restore:

```bash
cp local_runtime/sandbox-state.backup.json local_runtime/sandbox-state.json
```

## Validation

Validated on 2026-06-30:

- `ACORE_SANDBOX_PERSISTENCE_SELF_TEST=1` created a local save file.
- The self-test restored position, health, focus, quest flags, and placeholder inventory.
- The self-test printed `SANDBOX_PERSISTENCE_SELF_TEST_OK`.
- The save file stayed under ignored `local_runtime/`.
