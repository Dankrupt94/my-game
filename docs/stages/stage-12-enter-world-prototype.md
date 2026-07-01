# Stage 12 - Enter World Prototype

Status: Complete for first enter-world prototype

## Goal

Initiate character world entry, verify authentication responses, extract player coordinates, and render a basic 3D marker at the server-reported starting location.

Stage 12 is the first real "enter world" milestone. It is not a complete object-replication client yet. It proves that Godot can select a live AzerothCore character, send `CMSG_PLAYER_LOGIN`, receive `SMSG_LOGIN_VERIFY_WORLD`, and place a local 3D marker from the authoritative server position.

## Deliverables

- **Login Selection Request:** Complete. The native protocol client sends the selected character's GUID via `CMSG_PLAYER_LOGIN`.
- **Verify World Packets Parser:** Complete. The parser extracts Map ID, position coordinates `(X, Y, Z)`, and player orientation from `SMSG_LOGIN_VERIFY_WORLD`.
- **Initial Update Object Parser:** Started. The parser can recognize `SMSG_UPDATE_OBJECT` and `SMSG_COMPRESSED_UPDATE_OBJECT`, inflate compressed update payloads, read the update block count, read the first update type, and compare the first packed GUID against the selected player GUID. The current local login stream did not emit an update-object packet during the observed Stage 12 window, so full object-value parsing remains the next packet-layer task.
- **Godot 3D Grid Space:** Complete. `scenes/enter_world_view.tscn` builds a 3D grid with axis labels and a camera.
- **Player Marker Placement:** Complete for login verification. The scene maps the server-reported WoW coordinates into Godot space and places a placeholder marker when the visual scene is running.

## Entry Criteria

- [x] Stage 11 minimal protocol client successfully retrieves character enumeration data over TCP.
- [x] Godot-native `AcoreProtocolClient` extension can run the authenticated character-flow check through the dashboard bridge.

## Stage Start Notes

Started on 2026-07-01.

Stage 12 begins after Stage 11 proved authserver SRP6, realm parsing, world auth, encrypted `CMSG_CHAR_ENUM`, and Godot-native character enumeration through the `AcoreProtocolClient` GDExtension.

The immediate local blocker is that the ignored `CODEXPROTO` smoke-test account has no characters. The first step is to create a disposable local-only test character through the protocol path, then use that character to validate `CMSG_PLAYER_LOGIN` and `SMSG_LOGIN_VERIFY_WORLD`.

## Result Notes

Completed on 2026-07-01.

- Created the disposable local-only test character `Codexstage` on the ignored protocol test account.
- Verified character enumeration now returns `Codexstage` with GUID `0x2ee4`, level `1`, race `1`, class `1`, map `0`, and starting position `(-8949.95, -132.493, 83.5312)`.
- Added `--create-character` and `--enter-world` commands to the native protocol helper.
- Added Godot-native `AcoreProtocolClient.create_character(...)` and `AcoreProtocolClient.enter_world(...)` methods.
- Added helper fallback support in `scripts/protocol_client_bridge.gd` without shell-sourcing the local account file. Godot reads the ignored account file directly and passes the account/password only to the local child process.
- Added `scenes/enter_world_view.tscn`, which enters the world as `Codexstage`, displays a grid, and places the marker from `SMSG_LOGIN_VERIFY_WORLD`.
- Added `tools/enter_world_bridge_smoke.gd` for a small headless bridge check.
- Validated the scene headlessly with `ACORE_ENTER_WORLD_SELF_TEST=1`, receiving map `0` and position `(-8949.95, -132.49, 83.53)`.
- Observed no `SMSG_UPDATE_OBJECT` or `SMSG_COMPRESSED_UPDATE_OBJECT` in the current enter-world packet window. The Stage 12 code records this truthfully as `update_object_seen=false`.

## Done Criteria

- [x] Godot completes the world login sequence and transitions the UI to the 3D grid viewport.
- [x] The 3D player mesh aligns with the `(X, Y, Z)` coordinates returned in the login verification payload after applying the documented WoW-to-Godot coordinate scale.
- [x] Headless validation confirms the live server map and position without requiring proprietary assets.
- [ ] Full initial object-replication parsing. Deferred to the next packet-layer stage because Stage 12 did not observe a live update-object payload after login.

## Documentation To Update During Work

- Login verify packet fields map.
- SMSG_UPDATE_OBJECT value bitmask specifications.
- World space coordinate orientation documentation (mapping WoW coordinates to Godot coordinate space).

## Coordinate Mapping

The Stage 12 scene uses a temporary scaled mapping for visualization:

| WoW field | Godot field | Notes |
| --- | --- | --- |
| `x` | `position.x = x * 0.02` | East-west placeholder axis |
| `y` | `position.z = -y * 0.02` | WoW Y maps to Godot Z with a sign flip |
| `z` | `position.y = z * 0.02` | WoW height maps to Godot Y |

The scale is intentionally small so the first live login marker fits inside a readable prototype grid. A later terrain/map stage must replace this with a map-aware world transform.
