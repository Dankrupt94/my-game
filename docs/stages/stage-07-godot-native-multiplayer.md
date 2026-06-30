# Stage 07 - Godot-Native Multiplayer

Status: Complete

## Goal

Prove Godot can run a small multiplayer RPG loop with its own networking.

## Deliverables

- Local Godot server mode.
- Two local Godot clients.
- Player spawn and despawn.
- Position synchronization.
- Basic animation-state synchronization.
- Target selection synchronization.
- Simple attack/combat message.
- Shared placeholder NPC health.

## Entry Criteria

- Stage 05 sandbox exists.
- Basic gameplay systems are modular.

## Stage Start Notes

- Stage 07 begins after the data-driven sandbox slice.
- This stage uses Godot-native networking only, not the WotLK protocol.
- The target is a small local proof: one server, two clients, player spawn/despawn, position sync, target sync, attack messages, and shared placeholder NPC health.
- This remains Path A risk reduction. It does not satisfy the final Godot-native WotLK client goal by itself.

## Done Criteria

- [x] Two Godot clients can connect locally, see each other, and interact with one placeholder enemy.

## Implementation Notes

- Added `scenes/multiplayer_sandbox.tscn`.
- Added `scripts/multiplayer_sandbox.gd`.
- Added `tools/run_multiplayer_smoke_test.py`.
- Added an `Open Multiplayer` dashboard action.
- Transport: Godot `ENetMultiplayerPeer` on localhost port `19107`.
- The server owns player snapshots and shared placeholder NPC health.
- Clients register names, send position/target/state updates, and send simple attack messages.
- Server broadcasts snapshots to clients using Godot RPC.

## Message Formats

- Client to server: `_server_register(name)`.
- Client to server: `_server_player_state(position, target, state)`.
- Client to server: `_server_attack(target, amount)`.
- Server to clients: `_client_snapshot(snapshot, shared_npc_health, events)`.

## Synchronization Strategy

- Server is authoritative for the shared snapshot.
- Clients send lightweight state updates.
- Clients render peer capsules from the latest snapshot.
- Shared placeholder NPC health changes only on the server and is replicated by snapshot.

## Known Desync Cases

- No interpolation yet, so remote movement is snapshot-stepped.
- No server-side cooldown or range validation yet.
- No reconnect/session restore.
- No animation tree yet; animation state is a replicated string only.

## Validation

Completed on 2026-06-30:

- `snap run godot-4 --headless --quit-after 5 --path ".../godot-azerothcore-companion" --scene res://scenes/multiplayer_sandbox.tscn` exited `0`.
- `python3 tools/run_multiplayer_smoke_test.py` launched one headless server and two headless clients.
- Smoke test printed `MULTIPLAYER_CLIENT_SELF_TEST_OK ClientOne`.
- Smoke test printed `MULTIPLAYER_CLIENT_SELF_TEST_OK ClientTwo`.
- Smoke test printed `MULTIPLAYER_SERVER_SELF_TEST_OK`.
- Smoke test printed `MULTIPLAYER_SMOKE_TEST_OK`.

## Documentation To Update During Work

- [x] Networking transport choice.
- [x] Message formats.
- [x] Synchronization strategy.
- [x] Known desync cases.
- [x] Manual multiplayer test steps.
