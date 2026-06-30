# Stage 06 - Data-Driven Sandbox

Status: Planned

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

## Done Criteria

- Godot can display and spawn placeholder gameplay objects based on real AzerothCore records.
- All data access is read-only unless a later stage explicitly allows writes.

## Documentation To Update During Work

- Bridge endpoints used.
- Data models consumed by Godot.
- Mapping rules from AzerothCore data to Godot placeholders.
- Known missing fields.

