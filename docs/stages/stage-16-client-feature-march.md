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
- 2026-07-01: First chat slice is working. Godot sends a local say-message through `CMSG_MESSAGECHAT` and receives the AzerothCore echo through `SMSG_MESSAGECHAT` opcode `0x096`.
- 2026-07-01: Chat slice expanded to self-whisper. Godot now sends a whisper packet addressed to the local test character and receives both whisper and whisper-inform responses.
- 2026-07-01: First spellbook slice is working. Godot parses `SMSG_INITIAL_SPELLS` and displays the server-provided initial spell IDs.

## Active Slice: Chat

Initial target:

- [x] Send a local say-message from the Godot protocol client path.
- [x] Observe the server response or echo in Godot.
- [x] Document packet fields and behavior in the protocol notes.
- [x] Add a simple chat frame scene with input and log history.
- Keep the implementation generic and local-test focused; do not import proprietary assets or client data.

Remaining chat parity work:

- True receiver-side whisper tests with a second account/session.
- Channel, party, raid, guild, officer, battleground, emote, AFK, and DND message types.
- Chat tabs, filters, timestamps, scrollback, message colors, and command parsing.
- System messages and server notifications as first-class UI events.
- Multi-character/session tests for receiver-side behavior.

## Active Slice: Spellbook

Completed first target:

- [x] Parse `SMSG_INITIAL_SPELLS`.
- [x] Expose initial spell IDs and cooldown count through the native helper and Godot extension.
- [x] Add a Godot spellbook scene with a headless self-test.

Remaining spell parity work:

- Resolve spell names, ranks, icons, and descriptions from local-only data sources.
- Add action bars and keybind-driven spell placement.
- Build `CMSG_CAST_SPELL` support with target flags and cast-count handling.
- Parse cooldown, cast-fail, interrupt, aura, and combat-result packets.
