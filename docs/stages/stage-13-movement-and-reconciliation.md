# Stage 13 - Movement And Reconciliation

Status: Complete for first active movement slice

## Goal

Synchronize client-side player movements (coordinates, state flags, and orientation) with the AzerothCore world server using a two-phased implementation that eliminates movement-loop desyncs.

Stage 13 is the first live active-movement proof. It does not yet implement continuous WASD prediction or spectator-client validation. It proves that Godot/native protocol code can enter world, wait until the server has fully placed the player into the map, send a small movement start/stop sequence, and verify that AzerothCore accepts the new live world position. It also reports the saved character-list position separately because persistence depends on the server logout/session cleanup path.

## Deliverables

- **Phase 13a: Passive Mimicry Module (De-risking)**
  - Establish a secondary connection or parse updates when another official WotLK client moves on the same map.
  - Parse server movement updates and reposition a passive Godot replica avatar in real-time, verifying coordinate scaling, orientation rotation, and packet structure correctness.
- **Phase 13b: Active WASD Input Synchronization**
  - Complete for one controlled step. The native protocol client packages `MSG_MOVE_START_FORWARD` and `MSG_MOVE_STOP` movement packets containing packed GUID, movement flags, tick, coordinates, orientation, and fall time.
  - Continuous third-person WASD controls remain a future expansion of this slice.
- **Reconciliation Engine:**
  - Complete for live-world verification. The Stage 13 probe compares before, target, live login-world position, and saved character-list position, then reports live drift and saved drift separately.
  - Teleport/reposition packet handling remains future work.

## Entry Criteria

- Stage 12 enter-world prototype successfully initializes in 3D coordinate space.

## Result Notes

Completed on 2026-07-01.

- Added movement opcodes for `MSG_MOVE_START_FORWARD`, `MSG_MOVE_STOP`, `MSG_MOVE_JUMP`, `MSG_MOVE_HEARTBEAT`, `SMSG_TIME_SYNC_REQ`, and logout opcodes.
- Added a compact `MovementSample` packet builder following AzerothCore's `ReadMovementInfo` order.
- Added `--move-heartbeat` to the native helper. The command now performs a real start/stop movement step, despite the historical command name.
- Found that sending movement immediately after `SMSG_LOGIN_VERIFY_WORLD` is too early; AzerothCore does not reliably persist movement until after the post-map-add `SMSG_TIME_SYNC_REQ`.
- Found that a bare `MSG_MOVE_HEARTBEAT` does not reliably persist a changed coordinate for this test.
- Implemented the reliable live sequence: enter world, wait for `SMSG_TIME_SYNC_REQ`, send `MSG_MOVE_START_FORWARD`, send `MSG_MOVE_STOP` at the target coordinate, request logout/session cleanup, reconnect into the world, and compare the live login-world position against the movement target.
- Verified live movement with `Codexstage`: native helper reported before `(-8946.9, -132.493, 83.5312)`, target `(-8946.7, -132.493, 83.5312)`, live `(-8946.7, -132.493, 83.5312)`, live drift `0`, saved drift `0.200195`.
- Verified Godot bridge movement with `live_position_accepted=true` and `live_drift=0`.
- Verified the movement scene self-test with `MOVEMENT_RECONCILIATION_SELF_TEST_OK live_drift=0.000 saved_drift=0.200`.
- Added Godot bridge support for the movement probe.
- Added `scenes/movement_reconciliation_view.tscn`, which visualizes before/target/live/saved markers.
- Added `tools/movement_bridge_smoke.gd` for headless movement verification.

## Done Criteria

- [x] Moving from the Godot/native protocol path updates the character position in the live AzerothCore world state.
- [x] Live drift and saved-position drift are measured and reported separately.
- [ ] Reliable saved-position persistence after the fast movement probe. The current slice sometimes observes saved-position catch-up and sometimes records saved drift, so Stage 13 treats persistence as diagnostic data rather than the pass condition.
- [ ] Watching from an external official WotLK client shows the Godot character moving smoothly without stuttering, rapid rubber-banding, or server kicks. This remains future validation because this slice sends one controlled movement step, not a continuous movement stream.

## Documentation To Update During Work

- Client-side movement packet layout (types and header fields).
- Coordinate mapping rules (conversion between WoW scale and Godot units).
- Position reconciliation thresholds and desync logs.

## Packet Layout

Client movement packets first send the mover GUID packed, followed by the `MovementInfo` body:

| Field | Size | Notes |
| --- | ---: | --- |
| packed mover GUID | variable | Must match the logged-in character GUID |
| movement flags | 4 | `MOVEMENTFLAG_FORWARD` is `0x00000001` for start-forward |
| extra movement flags | 2 | `0` in the Stage 13 ground movement slice |
| movement time | 4 | Client tick; AzerothCore may resynchronize it |
| x | 4 | Float |
| y | 4 | Float |
| z | 4 | Float |
| orientation | 4 | Float radians |
| fall time | 4 | `0` for grounded movement in this slice |

Optional transport, pitch, jump, and spline-elevation sections are omitted unless the corresponding movement flags are set.
