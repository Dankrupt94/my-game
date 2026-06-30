# Stage 14 - Object Visibility

Status: Planned

## Goal

Build an in-memory Client Object Manager to parse entity creation, value modification, and destruction blocks from server update packets, rendering 3D placeholder representations for visible objects.

## Deliverables

- **Client Object Manager:** Implement a registry (GUID map) inside Godot that tracks visible entities (players, creatures, items, game objects).
- **SMSG_UPDATE_OBJECT Parser:** Implement a binary parser for the core world update packet, supporting:
  - `UPDATETYPE_CREATE_OBJECT` & `UPDATETYPE_CREATE_OBJECT2`: Extract GUID, position vector, orientation, type ID, and active field bitmasks.
  - `UPDATETYPE_VALUES`: Update properties (health, display ID, level, faction) of an existing entity.
  - `UPDATETYPE_OUT_OF_RANGE_OBJECTS`: Extract GUID arrays of entities that have left visibility range.
- **Dynamic 3D Spawner:**
  - Instantiate and label capsule meshes for nearby players.
  - Instantiate red capsule meshes for visible creatures (NPCs/monsters).
  - Instantiate grey box meshes for visible game objects (chests, doors).
  - Automatically call `queue_free()` on object nodes when their GUID is removed from the registry.

## Entry Criteria

- Stage 13 active movement synchronization functions correctly without server disconnects.

## Done Criteria

- Godot dynamically spawns and destroys 3D placeholders representing visible players, creatures, and objects in the surrounding server bubble as the character moves.

## Documentation To Update During Work

- Update field bitmask indices and layouts for each object type (WotLK values).
- Object manager dictionary API documentation.
- Debug log reports showing entity visibility changes.
