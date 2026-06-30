# Stage 06 - Data-Driven Sandbox

Status: In Progress

## Goal

Make the Godot sandbox consume AzerothCore-shaped data through the bridge.

## Deliverables

- Load selected character records into Godot UI.
- Load creature template names/stats as placeholder enemies.
- Load quest text/objectives as UI data.
- Load item names/basic metadata as inventory placeholders.
- Spawn original placeholder objects based on database records.

## Entry Criteria

- Stage 05 gameplay sandbox exists.
- Stage 04 bridge can expose safe read-only data.

## Stage Start Notes

- Stage 06 begins after the playable original sandbox and hardened bridge boundary.
- Data access must remain read-only through `GET /data`.
- AzerothCore records can influence placeholder labels, UI rows, and spawned primitive placeholders, but no proprietary assets or copied client UI should be introduced.
- The first slice should stay small and testable: load a few characters, creatures, quests, and items, then prove the sandbox can spawn original placeholder objects from those records.

## Done Criteria

- Godot can display and spawn placeholder gameplay objects based on real AzerothCore records.
- All data access is read-only unless a later stage explicitly allows writes.

## Documentation To Update During Work

- Bridge endpoints used.
- Data models consumed by Godot.
- Mapping rules from AzerothCore data to Godot placeholders.
- Known missing fields.
