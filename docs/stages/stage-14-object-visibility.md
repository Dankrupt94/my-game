# Stage 14 - Object Visibility

Status: Complete for first read-only visibility slice

## Goal

Build an in-memory Client Object Manager to parse entity creation, value modification, and destruction blocks from server update packets, rendering 3D placeholder representations for visible objects.

Stage 14's first completed slice builds the Godot object manager and renders real nearby AzerothCore world spawns as placeholders using read-only local database queries. It does not yet complete the full `SMSG_UPDATE_OBJECT` bitmask parser. That packet parser remains the next visibility hardening step.

## Deliverables

- **Client Object Manager:** Implement a registry (GUID map) inside Godot that tracks visible entities (players, creatures, items, game objects).
- **SMSG_UPDATE_OBJECT Parser:** Implement a binary parser for the core world update packet, supporting:
  - `UPDATETYPE_CREATE_OBJECT` & `UPDATETYPE_CREATE_OBJECT2`: Extract GUID, position vector, orientation, type ID, and active field bitmasks.
  - `UPDATETYPE_VALUES`: Update properties (health, display ID, level, faction) of an existing entity.
  - `UPDATETYPE_OUT_OF_RANGE_OBJECTS`: Extract GUID arrays of entities that have left visibility range.
- **Dynamic 3D Spawner:**
  - Complete for the first placeholder slice. The scene instantiates a yellow capsule for the local player, red capsule meshes for nearby creatures, and grey box meshes for nearby game objects.
  - Automatic packet-driven destruction is still pending full update-object out-of-range parsing.

## Entry Criteria

- Stage 13 live movement synchronization functions correctly without server disconnects.

## Result Notes

Completed on 2026-07-01 for the first read-only visibility slice.

- Added `tools/nearby_world_objects.py`, a read-only local query for nearby `creature` and `gameobject` world spawns.
- Added `GET /nearby` to the localhost host bridge and `nearby` support to `tools/bridge_client.py`.
- Added `scripts/client_object_manager.gd`, a GUID-keyed object registry for Godot.
- Added `scenes/object_visibility_view.tscn` and `scripts/object_visibility_view.gd`.
- Added a dashboard `Objects` action.
- Verified the scene self-test spawned 15 nearby creature placeholders and 15 nearby gameobject placeholders around `Codexstage`.
- Documented the packet-parser boundary in `docs/object-visibility.md`.

## Done Criteria

- [x] Godot dynamically spawns 3D placeholders representing the local player, nearby creatures, and nearby gameobjects around the character.
- [x] Placeholder data comes from real local AzerothCore world data and uses the live player login position as the scene center.
- [ ] Packet-driven dynamic spawn/despawn from `SMSG_UPDATE_OBJECT` and out-of-range update blocks.
- [ ] Placeholder updates while the character moves continuously.

## Documentation To Update During Work

- Update field bitmask indices and layouts for each object type (WotLK values).
- Object manager dictionary API documentation.
- Debug log reports showing entity visibility changes.
