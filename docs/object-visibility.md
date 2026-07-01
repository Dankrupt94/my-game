# Object Visibility

Status: Stage 14 first visibility slice

Stage 14 adds a Godot-side `ClientObjectManager` and a 3D object visibility scene. The scene enters the live AzerothCore world as the local test character, asks the localhost host bridge for nearby read-only world spawns, and renders placeholder meshes around the player.

## Current Flow

1. `ProtocolClientBridge.enter_world("Codexstage")` logs into the local worldserver and reads the authoritative player map and position.
2. `tools/host_control_bridge.py` exposes `GET /nearby` as a read-only endpoint.
3. `tools/nearby_world_objects.py` queries local `acore_world.creature` and `acore_world.gameobject` rows near the player coordinate.
4. `scripts/client_object_manager.gd` stores object dictionaries by GUID.
5. `scenes/object_visibility_view.tscn` spawns yellow player, red creature, and gray gameobject placeholders.

## Safety Boundary

- The query is read-only.
- No proprietary client assets are copied, parsed, or committed.
- Placeholder meshes are generated in Godot.
- Runtime reports, credentials, and local logs remain ignored.

## Parser Boundary

The scene still reports whether `SMSG_UPDATE_OBJECT` or `SMSG_COMPRESSED_UPDATE_OBJECT` was observed during login, but it does not claim full update-object replication yet.

Full Stage 14 parity still requires parsing create/update/out-of-range blocks from the server packet stream:

- `UPDATETYPE_CREATE_OBJECT`
- `UPDATETYPE_CREATE_OBJECT2`
- `UPDATETYPE_VALUES`
- `UPDATETYPE_OUT_OF_RANGE_OBJECTS`

## Validation

Latest validation on 2026-07-01:

- `python3 tools/bridge_client.py nearby --compact --map 0 --x -8946.3 --y -132.493 --radius 80 --limit 6`
- `godot-4 --headless --path . --script res://tools/object_visibility_smoke.gd`
- `ACORE_OBJECT_VISIBILITY_SELF_TEST=1 godot-4 --headless --path . res://scenes/object_visibility_view.tscn`

The scene self-test spawned 15 creature placeholders and 15 gameobject placeholders near `Codexstage`.
