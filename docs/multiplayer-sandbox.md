# Multiplayer Sandbox

## Purpose

Stage 07 proves a tiny Godot-native multiplayer loop on localhost.

This is Path A risk reduction only. It uses Godot ENet networking, not the WotLK protocol and not AzerothCore world networking.

## Files

```text
scenes/multiplayer_sandbox.tscn
scripts/multiplayer_sandbox.gd
tools/run_multiplayer_smoke_test.py
```

The dashboard opens the scene through `Open Multiplayer`.

## Transport

- Godot `ENetMultiplayerPeer`.
- Default localhost port: `19107`.
- Server mode: `ACORE_MP_MODE=server`.
- Client mode: `ACORE_MP_MODE=client`.

## Message Formats

Client to server:

- `_server_register(name: String)`: register display name.
- `_server_player_state(position: Vector3, target: String, state: String)`: send position, target selection, and animation/state string.
- `_server_attack(target: String, amount: int)`: send a simple attack message for the shared placeholder NPC.

Server to clients:

- `_client_snapshot(snapshot: Dictionary, shared_npc_health: int, events: Array)`: broadcast all known players, shared NPC health, and recent event text.

## Sync Strategy

- Server owns the authoritative player dictionary and shared placeholder NPC health.
- Clients send state updates and attack messages.
- Server broadcasts snapshots to all clients.
- Clients render colored primitive player capsules from snapshots.

## Known Desync Cases

- Movement is snapshot-only; no interpolation yet.
- Attack messages are reliable, but there is no cooldown validation yet.
- No reconnect/session restore yet.
- Server host is included in the player dictionary as `ServerHost`.

## Smoke Test

Run:

```bash
python3 tools/run_multiplayer_smoke_test.py
```

Expected markers:

```text
MULTIPLAYER_CLIENT_SELF_TEST_OK ClientOne
MULTIPLAYER_CLIENT_SELF_TEST_OK ClientTwo
MULTIPLAYER_SERVER_SELF_TEST_OK
MULTIPLAYER_SMOKE_TEST_OK
```

The test launches one headless server and two headless clients, verifies both clients receive a shared snapshot with at least two players, verifies an attack changes shared NPC health, then exits cleanly.

## Manual Test

Start server:

```bash
ACORE_MP_MODE=server snap run godot-4 --path "/run/media/doodbro/New 1tb/AzerothCore/godot-azerothcore-companion" --scene res://scenes/multiplayer_sandbox.tscn
```

Start clients in two more terminals:

```bash
ACORE_MP_MODE=client ACORE_MP_CLIENT_NAME=ClientOne snap run godot-4 --path "/run/media/doodbro/New 1tb/AzerothCore/godot-azerothcore-companion" --scene res://scenes/multiplayer_sandbox.tscn
ACORE_MP_MODE=client ACORE_MP_CLIENT_NAME=ClientTwo snap run godot-4 --path "/run/media/doodbro/New 1tb/AzerothCore/godot-azerothcore-companion" --scene res://scenes/multiplayer_sandbox.tscn
```
