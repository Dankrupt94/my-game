# Stage 12 - Enter World Prototype

Status: In Progress

## Goal

Initiate character world entry, verify authentication responses, extract player coordinates, and render a basic 3D marker at the server-reported starting location.

## Deliverables

- **Login Selection Request:** Send the selected character's GUID via `CMSG_PLAYER_LOGIN`.
- **Verify World Packets Parser:** Read and extract Map ID, position coordinates `(X, Y, Z)`, and player orientation from the `SMSG_LOGIN_VERIFY_WORLD` packet.
- **Initial Update Object Parser:** Parse the initial `SMSG_UPDATE_OBJECT` data payload. Identify the player's own GUID within the object values blocks and save the character's properties (such as race, class, level).
- **Godot 3D Grid Space:** Instantiating a clean 3D coordinate space containing basic axis indicators and grid line visual aids.
- **Player Marker Placement:** Position a camera and a custom 3D player mesh placeholder at the server-reported coordinates.

## Entry Criteria

- [x] Stage 11 minimal protocol client successfully retrieves character enumeration data over TCP.
- [x] Godot-native `AcoreProtocolClient` extension can run the authenticated character-flow check through the dashboard bridge.

## Stage Start Notes

Started on 2026-07-01.

Stage 12 begins after Stage 11 proved authserver SRP6, realm parsing, world auth, encrypted `CMSG_CHAR_ENUM`, and Godot-native character enumeration through the `AcoreProtocolClient` GDExtension.

The immediate local blocker is that the ignored `CODEXPROTO` smoke-test account has no characters. The first step is to create a disposable local-only test character through the protocol path, then use that character to validate `CMSG_PLAYER_LOGIN` and `SMSG_LOGIN_VERIFY_WORLD`.

## Done Criteria

- Godot completes the world login sequence and transitions the UI to the 3D grid viewport.
- The 3D player mesh aligns exactly with the `(X, Y, Z)` coordinates returned in the login verification payload.

## Documentation To Update During Work

- Login verify packet fields map.
- SMSG_UPDATE_OBJECT value bitmask specifications.
- World space coordinate orientation documentation (mapping WoW coordinates to Godot coordinate space).
