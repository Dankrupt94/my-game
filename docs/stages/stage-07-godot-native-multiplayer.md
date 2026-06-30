# Stage 07 - Godot-Native Multiplayer

Status: In Progress

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

- Two Godot clients can connect locally, see each other, and interact with one placeholder enemy.

## Documentation To Update During Work

- Networking transport choice.
- Message formats.
- Synchronization strategy.
- Known desync cases.
- Manual multiplayer test steps.
