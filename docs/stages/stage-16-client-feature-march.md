# Stage 16 - WotLK Client Feature March

Status: In Progress

## Goal

Rebuild the WotLK client feature set in Godot as faithfully as possible, one vertical slice at a time.

This stage is not a loose inspiration pass. It is the long feature-parity march toward a fully functional Godot-native WotLK client. The original WotLK client may be used for local comparison and validation, but it is not an acceptable runtime dependency.

## Feature Areas

- Chat. Working expanded slice: local say-message and self-whisper send/receive probes.
- Inventory.
- Equipment.
- Loot.
- Vendors.
- Quests.
- Trainers.
- Spells. Working expanded slice: initial spellbook, no-target cast, and live unit-target cast.
- Action bars. Working expanded slice: server-provided slots plus spell-slot casting.
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
- 2026-07-01: First action-bar slice is working. Godot parses `SMSG_ACTION_BUTTONS`, unpacks the 144 server-provided action slots, and displays populated slots in a read-only action-bar scene.
- 2026-07-01: First spell-cast slice is working. Godot sends `CMSG_CAST_SPELL` for the local warrior stance spell `2457` and receives `SMSG_SPELL_GO` opcode `0x132`.
- 2026-07-01: Targeted spell-cast slice is working. Godot selects a live creature, sends a unit-target `CMSG_CAST_SPELL` for spell `78`, and receives `SMSG_SPELL_START` opcode `0x131`.
- 2026-07-01: Action-button spell-cast slice is working. Godot renders all 144 action slots, clicks server action button `73`, casts spell `78`, and receives `SMSG_SPELL_START` opcode `0x131`.
- 2026-07-01: Action-button edit slice is working. Godot sends `CMSG_SET_ACTION_BUTTON`, confirms slot `0` can be set to spell `78`, restores the original empty slot, and confirms the restore.
- 2026-07-01: Combat damage parser slice is working. Godot answers AzerothCore time-sync requests, approaches and faces a live hostile target, keeps listening through attack-start/attack-stop state markers, and parses `SMSG_ATTACKERSTATEUPDATE` opcode `0x14A` into hit-info, total damage, overkill, sub-hit count, target state, and blocked amount fields.

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
- [x] Tolerate AzerothCore initial-spell packets where the advertised cooldown-map count is larger than the cooldown rows actually serialized.
- [x] Send a safe no-target `CMSG_CAST_SPELL` and parse the accepted `SMSG_SPELL_GO` response.
- [x] Add a Godot spell-cast scene with a headless self-test.
- [x] Send a live unit-target `CMSG_CAST_SPELL` after selecting and attacking a nearby creature.
- [x] Reuse the spell-cast scene for a targeted headless self-test.

Remaining spell parity work:

- Resolve spell names, ranks, icons, and descriptions from local-only data sources.
- Expand `CMSG_CAST_SPELL` support with friendly targets, item targets, source/destination targets, string targets, and cast-count edge cases.
- Parse cooldown, cast-fail, interrupt, aura, damage/healing, threat, and combat-result packets.

## Active Slice: Action Bars

Completed first target:

- [x] Parse `SMSG_ACTION_BUTTONS`.
- [x] Unpack all 144 action slots as `action = packed & 0x00FFFFFF` and `type = packed >> 24`.
- [x] Expose action-button data through the native helper and Godot extension.
- [x] Add a Godot action-bar scene with a headless self-test.
- [x] Render all 144 action slots in Godot.
- [x] Connect populated spell slots to the no-target and unit-target cast paths.
- [x] Add a Godot action-button cast self-test that casts server button `73`.
- [x] Build and validate `CMSG_SET_ACTION_BUTTON` against a controlled local character.
- [x] Add a reversible Godot set-action-button self-test that restores the original slot state.

Remaining action-bar parity work:

- Resolve spell/item/macro/equipment-set actions to display names and local-only icons.
- Add drag/drop placement, remove-slot behavior, paging, and keybinds.
- Preserve exact server persistence behavior and document any Godot UI compatibility tweaks.
- Add item use, macro, equipment set, paging, and non-spell action behavior.
