# Stage 15 - Combat And Interaction

Status: Complete

## Goal

Perform real AzerothCore interactions from Godot.

## Deliverables

- Target a nearby live server object by parsing AzerothCore update-object packets.
- Send one basic NPC interaction.
- Send one basic attack swing.
- Receive server interaction and combat feedback.
- Show a simple combat log.
- Show target frame updates.

## Entry Criteria

- Stage 14 object visibility works.

## Done Criteria

- Godot can target and affect one creature through AzerothCore.

## Completed Slice

- Added a minimal live `SMSG_UPDATE_OBJECT` / `SMSG_COMPRESSED_UPDATE_OBJECT` create-block parser to recover server-created object GUIDs, object type, entry, and position.
- Corrected the Stage 15 targeting model: database spawn GUIDs are not live packet GUIDs, so Godot must target the live object GUIDs emitted by the world session.
- Added `--npc-interaction`, which logs in, finds a live target by entry, sends `CMSG_SET_SELECTION`, sends `CMSG_GOSSIP_HELLO`, and waits for `SMSG_GOSSIP_MESSAGE`.
- Added `--combat-probe`, which logs in, finds a live creature by entry, sends `CMSG_SET_SELECTION`, sends `CMSG_ATTACKSWING`, and waits for combat feedback such as `SMSG_ATTACKSTART`.
- Added `res://scenes/interaction_combat_view.tscn`, which runs both probes from Godot and displays target-frame and combat-log status.
- Added the dashboard `Interact` action.

## Validation Evidence

- `native/protocol_client/build/acore_protocol_client --self-test`
  - Passed `PROTOCOL_CLIENT_SELF_TEST_OK`, `SRP6_SELF_TEST_OK`, and `WORLD_PACKET_SELF_TEST_OK`.
- `native/protocol_client/build/acore_protocol_client --npc-interaction 127.0.0.1 3724 ... Codexstage 823 "Nearby NPC"`
  - Passed with `live_target_found=1`, `selection_sent=1`, `gossip_sent=1`, `gossip_response_seen=1`, and `response_opcode=0x17d`.
- `native/protocol_client/build/acore_protocol_client --combat-probe 127.0.0.1 3724 ... Codexstage 721 "Nearby Creature"`
  - Passed with `live_target_found=1`, `selection_sent=1`, `attack_sent=1`, `combat_response_seen=1`, and `response_opcode=0x143`.
- `ACORE_INTERACTION_COMBAT_SELF_TEST=1 godot-4 --headless --path . res://scenes/interaction_combat_view.tscn`
  - Passed with `INTERACTION_COMBAT_SELF_TEST_OK gossip_opcode=0x17d combat_opcode=0x143`.
- Regression checks also passed for enter-world, movement reconciliation, and object visibility scenes.

## Compatibility Notes

- The first Stage 15 failure came from using a database spawn GUID as a packet target. AzerothCore creates runtime low GUIDs for world objects, so live targeting must come from the update stream.
- Current combat feedback proves target selection, attack-swing send, and server combat response. Full health deltas, damage rolls, death state, threat, and spell combat remain Stage 16 feature-march work.
- Current interaction feedback proves gossip hello and server gossip-message response. Full gossip menu parsing and option selection remain Stage 16 feature-march work.

## Documentation To Update During Work

- Interaction packet notes.
- Combat result notes.
- Targeting behavior.
- Server validation errors.
