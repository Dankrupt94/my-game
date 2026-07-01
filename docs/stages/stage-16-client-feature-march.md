# Stage 16 - WotLK Client Feature March

Status: In Progress

## Goal

Rebuild the WotLK client feature set in Godot as faithfully as possible, one vertical slice at a time.

This stage is not a loose inspiration pass. It is the long feature-parity march toward a fully functional Godot-native WotLK client. The original WotLK client may be used for local comparison and validation, but it is not an acceptable runtime dependency.

## Feature Areas

- Chat. Current first slice: local say-message send/receive probe.
- Inventory.
- Equipment.
- Loot.
- Vendors.
- Quests.
- Trainers.
- Spells.
- Auras.
- Groups.
- Guilds.
- Mail.
- Auction house.
- Maps/minimap.
- Addon-like UI customization, if feasible.

## Entry Criteria

- Stage 15 combat and interaction works.

## Done Criteria

- Each feature area has a working Godot implementation, a test checklist, and a documented parity status.
- Any deviation from original WotLK behavior is documented as a compatibility tweak with a reason.
- No feature is permanently skipped unless a later explicit decision says exact parity is impossible or intentionally deferred.

## Documentation To Update During Work

- [Client Feature Parity Matrix](../client-feature-parity-matrix.md).
- Feature checklist.
- Protocol packets per feature.
- UI screens.
- Known behavior differences from WotLK.
- Test cases against AzerothCore.

## Current Stage 16 Checkpoints

- 2026-07-01: Stage 16 opened with a dedicated parity matrix. Chat is the first feature slice because it is a core client feature with a narrow protocol surface and a simple Godot UI proof path.

## Active Slice: Chat

Initial target:

- Send a local say-message from the Godot protocol client path.
- Observe the server response or echo in Godot.
- Document packet fields and behavior in the protocol notes.
- Add a simple chat frame scene with input and log history.
- Keep the implementation generic and local-test focused; do not import proprietary assets or client data.
