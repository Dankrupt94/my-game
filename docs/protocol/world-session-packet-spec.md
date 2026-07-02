# World Session Packet Spec

Status: Stage 10 draft

Primary sources:

- `source/src/server/game/Server/WorldSocket.h`
- `source/src/server/game/Server/WorldSocket.cpp`
- `source/src/server/game/Server/Protocol/ServerPktHeader.h`
- `source/src/server/game/Handlers/AuthHandler.cpp`
- `source/src/server/game/Handlers/CharacterHandler.cpp`
- `source/src/server/game/Entities/Player/Player.cpp`

This document covers the first direct worldserver flow on port `8085`.

## Header Formats

### Client To Server Header

Before authentication this header is plaintext. After `_authCrypt.Init(session_key)`, only this 6-byte header is encrypted.

| Offset | Size | Field | Byte order | Notes |
| ---: | ---: | --- | --- | --- |
| 0 | 2 | `size` | big-endian | Includes the 4-byte opcode. Must be at least 4. |
| 2 | 4 | `cmd` | little-endian | Client opcode. |

AzerothCore subtracts 4 from `size` after reading the header to get payload length.

### Server To Client Header

Before world auth this header is plaintext. After auth crypt initializes, only the server header is encrypted.

Normal server header:

| Offset | Size | Field | Byte order | Notes |
| ---: | ---: | --- | --- | --- |
| 0 | 2 | `size` | big-endian | Payload length plus 2-byte opcode. |
| 2 | 2 | `cmd` | little-endian | Server opcode. |

Large server header:

| Offset | Size | Field | Byte order | Notes |
| ---: | ---: | --- | --- | --- |
| 0 | 3 | `size` | big-endian with high bit set in first byte | Used when `size > 0x7FFF`. |
| 3 | 2 | `cmd` | little-endian | Server opcode. |

## Initial World Challenge

When a TCP world socket opens, AzerothCore sends `SMSG_AUTH_CHALLENGE`.

Opcode: `0x1EC`

Payload:

| Field | Size | Notes |
| --- | ---: | --- |
| challenge marker | 4 | AzerothCore writes `uint32(1)` |
| server seed | 4 | `_authSeed`; needed by `CMSG_AUTH_SESSION` digest |
| extra seed bytes | 32 | Random bytes currently appended by server |

## Client World Auth

Opcode: `CMSG_AUTH_SESSION` (`0x1ED`)

Payload in server read order:

| Field | Size | Notes |
| --- | ---: | --- |
| `Build` | 4 | WotLK build `12340` for this project |
| `LoginServerID` | 4 | Login-server id field |
| `Account` | variable | Null-terminated account name string |
| `LoginServerType` | 4 | Login-server type field |
| `LocalChallenge` | 4 | Client-generated seed |
| `RegionID` | 4 | Region field |
| `BattlegroupID` | 4 | Battlegroup field |
| `RealmID` | 4 | Must match local `realmlist.id` |
| `DosResponse` | 8 | Client DoS response field |
| `Digest` | 20 | SHA-1 digest described below |
| `AddonInfo` | rest | Compressed/addon metadata blob consumed by `ReadAddonsInfo` |

Digest formula from AzerothCore:

```text
SHA1(account_name, four_zero_bytes, LocalChallenge, server_seed, session_key)
```

The account name is the account string as sent in the packet. The session key is the 40-byte key from authserver SRP6 login.

After account lookup, AzerothCore initializes header crypto with the account session key before sending auth responses.

## Server World Auth Response

Opcode: `SMSG_AUTH_RESPONSE` (`0x1EE`)

Failure short form payload:

| Field | Size | Notes |
| --- | ---: | --- |
| result code | 1 | For example unknown account, failed auth, banned, unavailable |

Success payload from `WorldSession::SendAuthResponse`:

| Field | Size | Notes |
| --- | ---: | --- |
| result code | 1 | `AUTH_OK` (`0x0C`) on success |
| billing time remaining | 4 | `0` in current source |
| billing plan flags | 1 | From account/session |
| billing time rested | 4 | `0` in current source |
| expansion | 1 | WotLK account expansion should resolve to `2` |
| queue position | 4 | Present in non-short form; normal `AUTH_OK` uses short form in current source |
| free character migration | 1 | Present in non-short form; normal `AUTH_OK` uses short form in current source |

## Character Enumeration

Client request:

| Opcode | Payload |
| --- | --- |
| `CMSG_CHAR_ENUM` (`0x037`) | Empty payload |

Server response:

| Opcode | First field |
| --- | --- |
| `SMSG_CHAR_ENUM` (`0x03B`) | `uint8` character count |

Then one repeated character block per character. The block is written by `Player::BuildEnumData`:

| Field | Size | Notes |
| --- | ---: | --- |
| guid | 8 | Raw `ObjectGuid` value, little-endian uint64 |
| name | variable | Null-terminated string |
| race | 1 | Character race id |
| class | 1 | Character class id |
| gender | 1 | Character gender id |
| skin | 1 | Appearance |
| face | 1 | Appearance |
| hair style | 1 | Appearance |
| hair color | 1 | Appearance |
| facial hair | 1 | Appearance |
| level | 1 | Character level |
| zone | 4 | Zone id |
| map | 4 | Map id |
| x | 4 | Float |
| y | 4 | Float |
| z | 4 | Float |
| guild id | 4 | Guild id or 0 |
| character flags | 4 | Resting, ghost, rename, etc. |
| customize flags | 4 | Customize/faction/race change flags |
| first login | 1 | `1` when first login cinematic/setup applies |
| pet display id | 4 | Selection-screen pet display |
| pet level | 4 | Pet level |
| pet family | 4 | Pet family |
| equipment slots | variable | For each slot before `INVENTORY_SLOT_BAG_END`: `uint32 display`, `uint8 inventory type`, `uint32 enchant aura` |

## Character Creation

Client request:

| Opcode | Payload |
| --- | --- |
| `CMSG_CHAR_CREATE` (`0x036`) | Name and appearance fields |

Payload in `WorldSession::HandleCharCreateOpcode` read order:

| Field | Size | Stage 12 test value |
| --- | ---: | --- |
| name | variable | Null-terminated test character name |
| race | 1 | `1` human |
| class | 1 | `1` warrior |
| gender | 1 | `0` male |
| skin | 1 | `0` |
| face | 1 | `0` |
| hair style | 1 | `0` |
| hair color | 1 | `0` |
| facial hair | 1 | `0` |
| outfit id | 1 | `0`; ignored by AzerothCore during create |

Server response:

| Opcode | Payload |
| --- | --- |
| `SMSG_CHAR_CREATE` (`0x03A`) | One `uint8` result code |

Observed Stage 12 behavior:

- First create of `Codexstage` produced a character visible in the next enum.
- Re-running create with the same name returns response `0x32`, which is the expected duplicate-name/name-unavailable path for the already-created local test character.

## Character Select

Client request:

| Opcode | Payload |
| --- | --- |
| `CMSG_PLAYER_LOGIN` (`0x03D`) | Raw `ObjectGuid`, 8-byte little-endian value |

First expected world-position response:

| Opcode | Payload |
| --- | --- |
| `SMSG_LOGIN_VERIFY_WORLD` (`0x236`) | `uint32 map`, `float x`, `float y`, `float z`, `float orientation` |

Observed Stage 12 login response for local test character `Codexstage`:

| Field | Value |
| --- | --- |
| map | `0` |
| x | `-8949.95` |
| y | `-132.493` |
| z | `83.5312` |
| orientation | `0` |

After that, the server sends the broader login packet stream. The Stage 12 trace observed feature status, account data times, MOTD, bind point, initial spells, and related login packets, but did not observe `SMSG_UPDATE_OBJECT` or `SMSG_COMPRESSED_UPDATE_OBJECT` within the current packet window.

## Update Object Boundary

Relevant opcodes:

| Opcode | Value | Stage 12 support |
| --- | ---: | --- |
| `SMSG_UPDATE_OBJECT` | `0x0A9` | Parser reads block count and first update block boundary when present |
| `SMSG_COMPRESSED_UPDATE_OBJECT` | `0x1F6` | Parser inflates zlib payload, then reads the same summary fields |

Uncompressed update payload begins with:

| Field | Size | Notes |
| --- | ---: | --- |
| block count | 4 | Number of update blocks, plus out-of-range block when present |
| update type | 1 | First update block type |
| packed guid | variable | Present for the create/values/movement update types handled by the Stage 12 summary parser |

Stage 12 intentionally stopped at a summary parser. Stage 15 extends this into a minimal live-object parser:

- Inflates `SMSG_COMPRESSED_UPDATE_OBJECT`.
- Reads update block count and create/update block type.
- Reads packed GUIDs.
- Recovers live object type, high GUID, entry id, counter, position, orientation, movement flags, and update flags from create blocks.
- Skips movement speed and spline-create payloads enough to keep walking later blocks.
- Skips value-update masks generically by counting mask bits and advancing `4` bytes per populated value.

Stage 17 begins reading owner-only player inventory fields from value updates:

| Field | AzerothCore index | Size | Stage 17 use |
| --- | ---: | ---: | --- |
| `PLAYER_FIELD_INV_SLOT_HEAD` | `UNIT_END + 0x00B0` | 46 x `uint32` | Equipment slots `0..18` and bag slots `19..22`, two fields per item GUID |
| `PLAYER_FIELD_PACK_SLOT_1` | `UNIT_END + 0x00DE` | 32 x `uint32` | Backpack item slots `23..38`, two fields per item GUID |
| `PLAYER_FIELD_COINAGE` | `UNIT_END + 0x03FE` | 1 x `uint32` | Money value when the server includes the field |

Stage 17 now also reads item object value fields for inventory item GUIDs:

| Field | AzerothCore index | Size | Stage 17 use |
| --- | ---: | ---: | --- |
| `OBJECT_FIELD_ENTRY` | `0x0003` | 1 x `uint32` | Item template entry for a slot item GUID |
| `ITEM_FIELD_STACK_COUNT` | `OBJECT_END + 0x0008` | 1 x `uint32` | Stack count for consumables and stacked items |
| `ITEM_FIELD_DURABILITY` | `OBJECT_END + 0x0036` | 1 x `uint32` | Current durability when present |
| `ITEM_FIELD_MAXDURABILITY` | `OBJECT_END + 0x0037` | 1 x `uint32` | Maximum durability when present |

Stage 17 corpse-loot work also reads unit state from creature value updates:

| Field | AzerothCore index | Size | Stage 17 use |
| --- | ---: | ---: | --- |
| `UNIT_FIELD_HEALTH` | `OBJECT_END + 0x0012` | 1 x `uint32` | Detect server-confirmed target death when health becomes `0` |
| `UNIT_FIELD_MAXHEALTH` | `OBJECT_END + 0x001A` | 1 x `uint32` | Report target max health for validation and future unit frames |
| `UNIT_FIELD_FLAGS` | `OBJECT_END + 0x0035` | 1 x `uint32` | Preserve server unit flags for future combat/interaction rules |
| `UNIT_DYNAMIC_FLAGS` | `OBJECT_END + 0x0049` | 1 x `uint32` | Detect `UNIT_DYNFLAG_LOOTABLE` (`0x0001`) before opening corpse loot |

Item template query:

| Direction | Opcode | Payload | Stage 17 use |
| --- | ---: | --- | --- |
| Client to server | `CMSG_ITEM_QUERY_SINGLE` (`0x056`) | `uint32 item_entry` | Request display/template metadata for a discovered item entry |
| Server to client | `SMSG_ITEM_QUERY_SINGLE_RESPONSE` (`0x058`) | Starts with `uint32 item_entry`, class/subclass fields, four name strings, display id, quality, prices, inventory type, allowable masks, item level, and required level | Parses the early stable fields needed for read-only inventory names and future tooltips |

Base inventory swap:

| Direction | Opcode | Payload | Stage 17 use |
| --- | ---: | --- | --- |
| Client to server | `CMSG_SWAP_INV_ITEM` (`0x10D`) | `uint8 destination_slot`, then `uint8 source_slot` | Moves or swaps items inside `INVENTORY_SLOT_BAG_0`, including equipped inventory slots and base backpack slots. Stage 17 uses backpack source slot `23` to destination slot `25`, then restores `25` back to `23`; it also uses equipment source slot `15` to backpack slot `26`, then restores `26` back to `15`. |
| Client to server | `CMSG_SPLIT_ITEM` (`0x10E`) | `uint8 source_bag`, `uint8 source_slot`, `uint8 destination_bag`, `uint8 destination_slot`, `uint32 count` | Splits a stack. For base inventory slots, AzerothCore expects bag id `255`. Stage 17 splits count `1` from slot `23` into slot `25`, then uses `CMSG_SWAP_INV_ITEM` to merge slot `25` back into slot `23`. |
| Server to client | `SMSG_INVENTORY_CHANGE_FAILURE` (`0x112`) | Failure payload varies by reason | Treated as a failed move during the bounded probe. |

The AzerothCore handler reads destination first, then source, and calls `Player::SwapItem` with `INVENTORY_SLOT_BAG_0`. Stage 17 confirms the mutation by reading inventory snapshots before the move, after the move, and after the restore.
The split handler reads source bag and slot first, then destination bag and slot, then count. The base player inventory bag id is `255`; `0` is `NULL_BAG` and fails explicit-position validation for this packet.

Stage 17 inventory snapshot behavior:

- `parse_update_object_summary` now reads value update masks into field/value pairs instead of only skipping them.
- When the update GUID matches the selected player GUID, the parser reconstructs 64-bit item GUIDs for 39 equipment, bag, and backpack slots.
- Item object create/update blocks are routed to inventory item detail parsing instead of the general nearby-object list.
- After item entries are known, the flow sends bounded item-template queries and applies resolved names back onto matching slots.
- The Godot scene `scenes/stage17_inventory_view.tscn` displays these slots as live server state with item names, entries, stack counts, and durability where present.
- The same scene can run a reversible base-backpack move/restore probe through the Godot protocol bridge.
- Local validation observed 39 slots, 7 populated item GUIDs, 7 item-detail rows, and 7 resolved item names for `Codexstage`; coinage was `0`, and the zero-valued coinage field was not included in that live update packet.
- Local validation also moved the slot `23` item to slot `25`, confirmed the destination held the same GUID, restored the item to slot `23`, and confirmed slot `25` was empty again.
- A follow-up validation moved the equipped slot `15` item to backpack slot `26`, confirmed the destination held the same GUID, restored the item to slot `15`, and confirmed slot `26` was empty again.
- Stack-split validation split one item from slot `23` into slot `25`, confirmed source stack `3` and destination stack `1`, merged slot `25` back into slot `23`, and confirmed source stack `4` with slot `25` empty.

Important Stage 15 correction: database spawn GUIDs are not live packet GUIDs. AzerothCore creates runtime object counters when the map instantiates creatures/gameobjects. Client actions must target the live `ObjectGuid` from the update stream.

## Movement Start/Stop Slice

Stage 13 uses the shared movement opcodes handled by `WorldSession::HandleMovementOpcodes`.

| Opcode | Value | Stage 13 use |
| --- | ---: | --- |
| `MSG_MOVE_START_FORWARD` | `0x0B5` | Sent at the current server login coordinate with `MOVEMENTFLAG_FORWARD` |
| `MSG_MOVE_STOP` | `0x0B7` | Sent at the target coordinate with no movement flags |
| `MSG_MOVE_HEARTBEAT` | `0x0EE` | Packet builder support exists, but bare heartbeat did not reliably persist a changed coordinate in the Stage 13 test |
| `SMSG_TIME_SYNC_REQ` | `0x390` | Used as the post-map-add signal before movement packets are sent |
| `CMSG_TIME_SYNC_RESP` | `0x391` | Stage 16 client helper now answers with the server counter and local client movement clock |
| `CMSG_LOGOUT_REQUEST` | `0x04B` | Sent after movement so AzerothCore follows the normal save/logout path |

Client movement body, after the packed mover GUID:

| Field | Size | Notes |
| --- | ---: | --- |
| movement flags | 4 | `0x00000001` for forward movement |
| extra movement flags | 2 | `0` in the Stage 13 ground movement test |
| movement time | 4 | Client tick; server resynchronizes when needed |
| x | 4 | Float |
| y | 4 | Float |
| z | 4 | Float |
| orientation | 4 | Float |
| fall time | 4 | `0` for the grounded movement test |

Live Stage 13 result:

- Sending movement immediately after `SMSG_LOGIN_VERIFY_WORLD` was too early.
- Waiting for `SMSG_TIME_SYNC_REQ`, then sending `MSG_MOVE_START_FORWARD` followed by `MSG_MOVE_STOP`, advances the live AzerothCore player position.
- The Stage 13 probe now records both the live login-world position and the saved character-list position. Live movement is the pass condition; saved persistence is reported separately because logout/session cleanup timing can lag behind the fast probe.
- Latest native result for `Codexstage`: before `(-8946.9, -132.493, 83.5312)`, target `(-8946.7, -132.493, 83.5312)`, live `(-8946.7, -132.493, 83.5312)`, live drift `0`, saved drift `0.200195`.

## Interaction And Combat Slice

Stage 15 uses live object GUIDs recovered from the update stream.

| Opcode | Value | Stage 15 use |
| --- | ---: | --- |
| `CMSG_SET_SELECTION` | `0x13D` | Selects the live target GUID before interaction or combat |
| `CMSG_GOSSIP_HELLO` | `0x17B` | Starts a basic NPC interaction |
| `SMSG_GOSSIP_MESSAGE` | `0x17D` | Confirms the server accepted the NPC interaction |
| `CMSG_ATTACKSWING` | `0x141` | Sends a basic attack swing at a live creature GUID |
| `CMSG_ATTACKSTOP` | `0x142` | Clears attack state after the probe |
| `SMSG_ATTACKSTART` | `0x143` | Confirms the server accepted the attack start |
| `SMSG_ATTACKSTOP` | `0x144` | Combat stop/validation feedback |
| `SMSG_ATTACKSWING_NOTINRANGE` | `0x145` | Combat validation feedback |
| `SMSG_ATTACKSWING_BADFACING` | `0x146` | Combat validation feedback |
| `SMSG_ATTACKSWING_DEADTARGET` | `0x148` | Combat validation feedback |
| `SMSG_ATTACKSWING_CANT_ATTACK` | `0x149` | Combat validation feedback |
| `SMSG_ATTACKERSTATEUPDATE` | `0x14A` | Stage 16 parser reads melee damage/combat-state fields |

Stage 15 native evidence:

- NPC interaction against entry `823` resolved live GUID `0xf130000337000cea` and received `SMSG_GOSSIP_MESSAGE` (`0x17D`).
- Combat probe against entry `721` resolved live GUID `0xf1300002d1000cef` and received `SMSG_ATTACKSTART` (`0x143`).

Stage 16 should parse gossip menu payloads, health updates, spell casts, threat/death state, and target frame deltas instead of treating response opcodes as the final state surface.

Stage 16 combat damage parser:

| Field | Size | Notes |
| --- | ---: | --- |
| hit info | 4 | Bitmask; current parser handles absorb, resist, block, rage-gain, and debug-field flags |
| attacker GUID | packed | Parsed to a raw 64-bit GUID |
| target GUID | packed | Parsed to a raw 64-bit GUID |
| total damage | 4 | Full damage across sub-damage rows |
| overkill | 4 | Server-reported overkill amount |
| sub-damage count | 1 | Current parser accepts 1 or 2 rows |
| per-sub-damage school mask | 4 each | Spell-school mask |
| per-sub-damage float damage | 4 each | Float duplicate of sub-damage |
| per-sub-damage damage | 4 each | Integer sub-damage |
| per-sub-damage absorb | 4 each, conditional | Present when hit info has full or partial absorb |
| per-sub-damage resist | 4 each, conditional | Present when hit info has full or partial resist |
| target state | 1 | Victim state such as hit, dodge, parry, block, etc. |
| attacker state | 4 | Server writes `0` in the observed AzerothCore melee path |
| melee spell id | 4 | Server writes `0` in the observed AzerothCore melee path |
| blocked amount | 4, conditional | Present when hit info has block |
| rage gain | 4, conditional | Skipped when present |
| debug fields | 48, conditional | Skipped when AzerothCore debug hit-info flag is present |

Observed Stage 16 result:

- Native `--combat-probe` against hostile entry `69` reached a live target, sent movement approach/facing, selected the target, sent `CMSG_ATTACKSWING`, and parsed `SMSG_ATTACKERSTATEUPDATE` opcode `0x14A`.
- Godot scene `scenes/interaction_combat_view.tscn` uses hostile entry `38` for a stable stationary self-test and passed with `INTERACTION_COMBAT_SELF_TEST_OK gossip_opcode=0x17d combat_opcode=0x14a damage=2 attacker_state=true`.

## Loot Slice

Stage 17 adds the first loot gameplay path. The initial quick probe attempts to open loot on a live nearby target and expects the server to close/deny it. The expanded corpse-loot probe fights a live target until AzerothCore reports death or `UNIT_DYNFLAG_LOOTABLE`, opens the corpse loot window, picks up item slots, optionally requests money loot, and releases the loot window.

| Opcode | Value | Stage 17 use |
| --- | ---: | --- |
| `CMSG_AUTOSTORE_LOOT_ITEM` | `0x108` | Picks up a specific loot slot; payload is `uint8 loot_slot` |
| `CMSG_LOOT` | `0x15D` | Opens loot for a creature GUID; payload is the raw 8-byte GUID |
| `CMSG_LOOT_MONEY` | `0x15E` | Requests copper pickup from an open loot window; payload is empty |
| `CMSG_LOOT_RELEASE` | `0x15F` | Closes an accepted loot window; payload is the raw 8-byte GUID |
| `SMSG_LOOT_RESPONSE` | `0x160` | Parsed as either a loot error or a loot window |
| `SMSG_LOOT_RELEASE_RESPONSE` | `0x161` | Parsed as raw GUID plus success byte |
| `SMSG_LOOT_REMOVED` | `0x162` | Confirms a loot slot was removed after pickup |
| `SMSG_LOOT_MONEY_NOTIFY` | `0x163` | Confirms money pickup; current live corpse tests had `gold=0`, so this path is implemented but not yet observed with nonzero copper |
| `SMSG_LOOT_ITEM_NOTIFY` | `0x164` | Item-loot notification path; not yet parsed in the Stage 17 probe |
| `SMSG_LOOT_CLEAR_MONEY` | `0x165` | Clears money from the open loot window; not yet observed in the latest zero-copper runs |

`SMSG_LOOT_RESPONSE` error payload:

| Field | Size | Notes |
| --- | ---: | --- |
| target GUID | 8 | Raw little-endian object GUID |
| loot type | 1 | `0` (`LOOT_NONE`) means the next byte is an error |
| error code | 1 | AzerothCore `LootError`, such as `0` for did-not-kill or `4` for too-far |

`SMSG_LOOT_RESPONSE` success payload:

| Field | Size | Notes |
| --- | ---: | --- |
| target GUID | 8 | Raw little-endian object GUID |
| loot type | 1 | `1` for corpse loot in the normal creature path |
| gold | 4 | Copper |
| item count | 1 | Number of item rows |
| item row slot | 1 each | Loot slot index, not bag slot |
| item id | 4 each | Item entry |
| count | 4 each | Stack count in the loot slot |
| display id | 4 each | Item display info id from the server template |
| random suffix | 4 each | Random suffix id |
| random property id | 4 each | Random property id |
| slot type | 1 each | `0` allow loot, `1` roll ongoing, `2` master, `3` locked, `4` owner |

Observed Stage 17 quick loot-open result:

- Native `--loot-open-probe` against nearby creature entry `38` resolved live GUID `0xf130000026000db9`, sent `CMSG_LOOT`, and received `SMSG_LOOT_RELEASE_RESPONSE` (`0x161`) with success byte `1`.
- Godot `ACORE_LOOT_OPEN_SELF_TEST=1` passed through `scenes/stage17_loot_view.tscn` with release response opcode `0x161`.
- The release response is expected for this probe because the target is alive/not lootable.

Observed Stage 17 corpse-loot result:

- Native and Godot corpse-loot probes use nearby creature entry `299`, move into range with stepped movement packets, select the live target GUID, attack until update fields report death/lootable state, and then send `CMSG_LOOT`.
- Godot `ACORE_CORPSE_LOOT_SELF_TEST=1` passed through `scenes/stage17_loot_view.tscn` with `dead=true`, `lootable=true`, `loot_response_seen=true`, item removal confirmation, `release_response=true`, and response opcode `0x160`.
- The latest Godot corpse-loot run observed `gold=0`, so `CMSG_LOOT_MONEY` / `SMSG_LOOT_MONEY_NOTIFY` remain implemented but still need a nonzero-money loot case for live evidence.

Observed Stage 17 loot-to-inventory handoff result:

- Native `--loot-inventory-handoff` snapshots inventory, runs the corpse-loot probe, snapshots inventory again, and compares all 39 tracked slots plus coinage.
- A latest native run against entry `299` observed `item_count=1`, `loot_item_removed_count=1`, `inventory_before_seen=1`, `inventory_after_seen=1`, `changed_slots=1`, `stack_changed_slots=1`, and `handoff_confirmed=1`. The changed slot was backpack slot `30`, where `Ruined Pelt` stacked to count `3`.
- Godot `ACORE_LOOT_INVENTORY_SELF_TEST=1` passed through `scenes/stage17_loot_view.tscn` with `changed_slots=1`, `stack_changed=1`, `coinage_delta=0`, `handoff=true`, and response opcode `0x160`.
- This confirms item pickup reaches live inventory state for at least a stack-increase case. New empty-slot placement and full-bag failure handling remain future work.

Remaining loot packet work:

- Replace the bounded `Fight + Loot` probe with normal player-controlled interaction, target frames, corpse-click behavior, and loot-window UX.
- Confirm new empty-slot placement and full-bag failure handling after pickup.
- Parse and surface loot errors, bind prompts, quest item rules, group loot settings, rolls, master loot, and permission edge cases.
- Add long-session persistence checks for looted money/items.

## Quest Giver List And Details Slice

Stage 17 now has the first live quest-giver list and detail packet paths. This
is still not full quest parity: the current scene lists offered quest ids and
queries one detail packet, but it does not accept, complete, reward, abandon,
share, or track objectives yet.

Relevant opcodes:

| Opcode | Value | Stage 17 support |
| --- | ---: | --- |
| `CMSG_QUESTGIVER_HELLO` | `0x184` | Sends selected quest-giver GUID after moving within NPC interaction range |
| `SMSG_QUESTGIVER_QUEST_LIST` | `0x185` | Parses standalone offered-quest rows when the server uses this response |
| `CMSG_QUESTGIVER_QUERY_QUEST` | `0x186` | Sends selected quest-giver GUID and quest id for detail lookup |
| `SMSG_QUESTGIVER_QUEST_DETAILS` | `0x188` | Parses safe numeric detail fields and reward item ids/counts |
| `SMSG_GOSSIP_MESSAGE` | `0x17D` | Parses gossip-embedded quest rows used by live local quest givers |

Quest-giver hello request payload:

| Field | Size | Notes |
| --- | ---: | --- |
| quest-giver GUID | 8 | Raw little-endian object GUID |

Quest detail request payload:

| Field | Size | Notes |
| --- | ---: | --- |
| quest-giver GUID | 8 | Raw little-endian object GUID |
| quest id | 4 | Requested quest template id |

Quest accept request payload:

| Field | Size | Notes |
| --- | ---: | --- |
| quest-giver GUID | 8 | Raw little-endian object GUID |
| quest id | 4 | Quest template id to accept |
| unknown | 4 | Sent as `0`, matching AzerothCore's handler shape |

Quest-log proof fields:

The accept proof reads the player's private quest-log fields from
`SMSG_UPDATE_OBJECT` / `SMSG_COMPRESSED_UPDATE_OBJECT`.

| Field | Notes |
| --- | --- |
| first quest field | `PLAYER_QUEST_LOG_1_1 = UNIT_END + 0x000A` |
| slots | 25 |
| stride | 5 update fields per slot |
| slot fields | quest id, state, two packed objective-count fields, timer |
| counters | Four 16-bit objective counters unpacked from the two count fields |

Clean empty quest logs can be represented by omission: AzerothCore may send a
player update without any all-zero quest-log fields. For the Stage 17 accept
proof, a player update seen with no quest-log fields is treated as an observed
empty quest log before the accept packet.

Standalone live quest-log snapshot:

- Native helper command: `--quest-log-snapshot <host> <port> <account> <character-name>`.
- Godot extension method: `AcoreProtocolClient.quest_log_snapshot(...)`.
- Script bridge method: `ProtocolClientBridge.quest_log_snapshot(...)`.
- Output remains numeric-only: quest ids, slot ids, state flags, four objective
  counters, timers, slot count, populated count, and status booleans.
- Current live validation for `Codexstage` observed `slot_count=25` and
  `populated_count=0` after the disposable quest fixture cleanup.

Current detail response fields:

| Field | Notes |
| --- | --- |
| npc guid | Parsed from the server response |
| quest id | Must match the requested quest id for the self-test to pass |
| quest flags | Numeric flags only |
| suggested players | Numeric group-size hint |
| hidden rewards | Boolean flag |
| reward choice count | Number of selectable reward item rows |
| reward item count | Number of fixed reward item rows |
| money reward | Copper amount, before future level-cap conversion UI |
| xp reward | XP amount |
| honor reward | Honor amount |
| reward spell | Spell id, if present |
| reward item rows | Item id and count only |
| reward choice rows | Item id and count only |

Observed Stage 17 result:

- `ACORE_QUESTGIVER_LIST_SELF_TEST=1` passed through
  `scenes/stage17_questgiver_view.tscn` with one offered quest via
  `SMSG_GOSSIP_MESSAGE` opcode `0x17d`.
- `ACORE_QUESTGIVER_DETAILS_SELF_TEST=1` passed through the same scene with
  quest id `783`, `SMSG_QUESTGIVER_QUEST_DETAILS` opcode `0x188`, and zero
  fixed/choice reward item rows for the local starter fixture.
- The quest accept slice now sends `CMSG_QUESTGIVER_ACCEPT_QUEST` and checks
  quest-log state before/after the packet. `accepted_confirmed` means the quest
  was absent before and present after; `already_in_log` is reported separately.
- `ACORE_QUESTGIVER_ACCEPT_SELF_TEST=1` passed through
  `scenes/stage17_questgiver_view.tscn` with `accept_sent=true`,
  `accepted_confirmed=true`, `already_in_log=false`, response opcode `0x1f6`,
  and the accepted quest present in the after snapshot.
- `tools/quest_log_bridge_smoke.gd` passed through the Godot native extension,
  proving a standalone read-only quest-log snapshot reaches the script bridge
  with `slot_count=25`.
- The Godot surface and helper fallback intentionally keep committed output to
  ids, flags, counts, and money/xp values. Quest title/body/objective text and
  icons remain a future local-only data/asset pipeline concern.
- The local Antigravity phase-2 blindspots file highlights future quest risks:
  quest-log cap handling, objective/map overlays, shared and area-triggered
  credit, party range checks, item-started quests, turn-in bag capacity, daily
  resets, and phasing-aware gossip.

Remaining quest packet work:

- Add complete, reward choice, full quest-log UI, abandon, and share packet
  support.
- Track objective progress from server state instead of treating detail packets
  as quest-log state.
- Add in-world click targeting and persistent-session integration.
- Add local-only quest text, icons, map overlays, and difficulty coloring
  without committing client-derived text/assets.

## Trainer List And Buy Slice

Stage 17 now has the first trainer-list and trainer-buy response paths required by [WotLK Client Parity Engine Spec](../wotlk_client_parity_engine_spec.md).

Relevant opcodes:

| Opcode | Value | Stage 17 support |
| --- | ---: | --- |
| `CMSG_TRAINER_LIST` | `0x1B0` | Sends selected trainer GUID after moving within NPC interaction range |
| `SMSG_TRAINER_LIST` | `0x1B1` | Parses trainer GUID, trainer type, spell rows, requirements, and greeting |
| `CMSG_TRAINER_BUY_SPELL` | `0x1B2` | Sends selected trainer GUID and requested trainer spell id |
| `SMSG_TRAINER_BUY_SUCCEEDED` | `0x1B3` | Parses trainer GUID and learned spell id |
| `SMSG_TRAINER_BUY_FAILED` | `0x1B4` | Parses trainer GUID, attempted spell id, and failure reason |

Client request payload:

| Field | Size | Notes |
| --- | ---: | --- |
| trainer GUID | 8 | Raw little-endian object GUID, using AzerothCore's shared NPC hello packet reader |

Trainer-buy request payload:

| Field | Size | Notes |
| --- | ---: | --- |
| trainer GUID | 8 | Raw little-endian object GUID |
| spell id | 4 | Trainer row spell id to learn |

Server response payload from `WorldPackets::NPC::TrainerList::Write`:

| Field | Size | Notes |
| --- | ---: | --- |
| trainer GUID | 8 | Server object GUID |
| trainer type | 4 | Integer trainer category |
| spell count | 4 | Number of trainer rows |
| spell id | 4 per row | Spell learned by this row |
| usable | 1 per row | Server-side usability flag |
| money cost | 4 per row | Copper cost |
| point cost | 8 per row | Two integer point-cost fields |
| required level | 1 per row | Character level requirement |
| required skill line | 4 per row | Skill line requirement, or 0 |
| required skill rank | 4 per row | Skill rank requirement, or 0 |
| required abilities | 12 per row | Three prerequisite spell ids |
| greeting | C string | Null-terminated trainer greeting |

Observed Stage 17 result:

- Native helper command `--trainer-list` selected a visible local trainer entry, moved within AzerothCore's NPC interaction distance, sent `CMSG_TRAINER_LIST`, parsed `SMSG_TRAINER_LIST`, and returned to the login position.
- The live response had opcode `0x1B1` and 6 trainer spell rows for `Codexstage`.
- Godot scene `scenes/stage17_trainer_view.tscn` passed `ACORE_TRAINER_LIST_SELF_TEST=1` with `moved_close=true`, `returned=true`, `spell_count=6`, and response opcode `0x1B1`.
- Native helper command `--trainer-buy` then opened the same trainer list, sent `CMSG_TRAINER_BUY_SPELL` for spell `6673`, and parsed `SMSG_TRAINER_BUY_FAILED` with failure reason `1` because the current test character only had 2 copper.
- Godot scene `scenes/stage17_trainer_view.tscn` passed `ACORE_TRAINER_BUY_SELF_TEST=1` with `buy_spell_sent=true`, `buy_response_seen=true`, `failed=true`, `failure_reason=1`, and response opcode `0x1B4`.
- Local fixture tool `tools/prepare_trainer_buy_fixture.py` prepared the disposable character by ensuring enough copper and resetting only spell `6673` in the local character database.
- Godot scene `scenes/stage17_trainer_view.tscn` passed `ACORE_TRAINER_BUY_SUCCESS_SELF_TEST=1` with `SMSG_TRAINER_BUY_SUCCEEDED` opcode `0x1B3`, `before_known=false`, `after_known=true`, and coinage changing from `10000` to `9991`.
- Godot scene `scenes/stage17_trainer_view.tscn` now reuses `visible_targets_snapshot`, selected trainer entry `911` by exact runtime GUID from 143 visible unit targets, and kept the trainer-list path green after switching to selector-aware calls.

Remaining trainer packet work:

- Surface disabled-state explanations, spell ranks/names/icons, and failure reasons in the Godot trainer UI.
- Replace the target scan/list picker with normal in-world click targeting and persistent-session flow.
- Keep the local trainer-buy fixture documented and rerun it before repeat success-path validations.

## Vendor List And Buy/Sell Slice

Stage 17 now has the first vendor-list and bounded vendor buy/sell paths required by [WotLK Client Parity Engine Spec](../wotlk_client_parity_engine_spec.md). This still is not full vendor parity: the current scene lets the user select a server-returned vendor row and quantity, buys that item, immediately sells the exact bought item GUID back to the same vendor, and verifies inventory/coinage changes. Repair, stock refresh UI, item names, icons, and tooltips remain future work.

Relevant opcodes:

| Opcode | Value | Stage 17 support |
| --- | ---: | --- |
| `CMSG_LIST_INVENTORY` | `0x19E` | Sends selected vendor GUID after moving within NPC interaction range |
| `SMSG_LIST_INVENTORY` | `0x19F` | Parses vendor GUID, item count, optional empty-list error byte, and item rows |
| `CMSG_SELL_ITEM` | `0x1A0` | Sends selected vendor GUID, exact owned item GUID, and count |
| `SMSG_SELL_ITEM` | `0x1A1` | Parses sell-error responses; success is confirmed by inventory and coinage snapshots |
| `CMSG_BUY_ITEM` | `0x1A2` | Sends selected vendor GUID, item id, vendor slot, count, and trailing client byte |
| `SMSG_BUY_ITEM` | `0x1A4` | Parses successful buy response |
| `SMSG_BUY_FAILED` | `0x1A5` | Parses buy failure item id, optional param, and reason |

Client request payload:

| Field | Size | Notes |
| --- | ---: | --- |
| vendor GUID | 8 | Raw little-endian object GUID |

Buy request payload from `WorldPackets::Item::BuyItem::Read`:

| Field | Size | Notes |
| --- | ---: | --- |
| vendor GUID | 8 | Raw little-endian object GUID |
| item id | 4 | Vendor item template id |
| vendor slot | 4 | Server vendor slot from the list row |
| count | 4 | Requested buy count |
| unknown byte | 1 | AzerothCore reads and ignores this trailing byte |

Sell request payload from `WorldPackets::Item::SellItem::Read`:

| Field | Size | Notes |
| --- | ---: | --- |
| vendor GUID | 8 | Raw little-endian object GUID |
| item GUID | 8 | Exact player-owned item GUID from inventory after buy |
| count | 4 | Sell count |

Server response payload from `WorldSession::SendListInventory`:

| Field | Size | Notes |
| --- | ---: | --- |
| vendor GUID | 8 | Server object GUID |
| item count | 1 | Number of visible vendor item rows |
| empty-list error | 1 optional | Present when item count is `0`; AzerothCore writes `0` for no inventory |
| vendor slot | 4 per row | One-based vendor slot |
| item id | 4 per row | Item template id |
| display id | 4 per row | Item display id |
| left in stock | 4 per row | `0xFFFFFFFF` means unlimited stock |
| buy price | 4 per row | Copper price after reputation discount |
| max durability | 4 per row | Item template max durability |
| buy count | 4 per row | Stack/count bought per purchase |
| extended cost | 4 per row | Extended-cost id, or `0` |

Observed Stage 17 result:

- The native helper command `--vendor-list` selects a visible local vendor entry by exact runtime GUID or entry selector, moves within AzerothCore NPC interaction distance, sends `CMSG_LIST_INVENTORY`, parses `SMSG_LIST_INVENTORY`, and returns to the login position.
- Latest native validation against entry `1213` resolved GUID `0xf1300004bd000cf4`, returned opcode `0x19F`, and parsed 8 item rows.
- Godot scene `scenes/stage17_vendor_view.tscn` scans visible targets, prefers local vendor entry `1213`, sends the selected exact GUID through `ProtocolClientBridge.vendor_list_probe_selector(...)`, and renders numeric vendor item rows.
- `ACORE_VENDOR_TARGET_PICKER_SELF_TEST=1` selected entry `1213` by exact GUID from 146 visible unit targets.
- `ACORE_VENDOR_LIST_SELF_TEST=1` passed with `moved_close=true`, `returned=true`, 8 item rows, and response opcode `0x19F`.
- Native helper command `--vendor-buy-sell` bought local test item id `17184` from vendor slot `8`, observed `SMSG_BUY_ITEM` opcode `0x1A4`, found the new item GUID in backpack slot `34`, sent `CMSG_SELL_ITEM` for that exact GUID, saw no sell error, and confirmed the slot returned to its prior state.
- The latest live round trip changed coinage from `9965` to `9933` after buy, then `9939` after sell, for deltas `-32`, `+6`, and `-26`. This is expected because vendor buy and sell prices differ.
- Godot scene `scenes/stage17_vendor_view.tscn` now exposes a `Buy + Sell` control and passed `ACORE_VENDOR_BUY_SELL_SELF_TEST=1` with buy opcode `0x1A4`, bought slot `34`, and `roundtrip=true`.
- The vendor scene now stores metadata for each server-returned row, shows the selected row in the action area, exposes a quantity control, and routes `Buy + Sell` through the selected row instead of hardcoding the UI path. The self-test still selects the known local cheap item row so repeated validation stays bounded.
- The buy/sell result now renders transaction status plus before, after-buy, and after-sell slot snapshots when the native extension returns them, and the self-test requires all three inventory snapshots to be observed.
- `ACORE_VENDOR_UI_SELF_TEST=1` renders the selected-row and transaction feedback UI with synthetic local dictionaries only, so UI layout/formatting can be checked without entering the bridge or live-session lane.
- The scene uses generic labels and item ids only. Committed data does not include proprietary NPC names, item names, icons, or extracted client data.

Remaining vendor packet work:

- Turn the selected-row buy/sell proof into a normal player vendor window with persistent inventory panel refresh after purchase/sale, failure-code UI, and stock refresh.
- Add repair support and repair-cost/failure handling.
- Resolve item names/icons/tooltips through the local-only data/asset pipeline.
- Replace the target scan/list picker with normal in-world click targeting and persistent-session flow.

## Chat Say Slice

Stage 16 starts the long client feature parity march with a minimal chat path.

Client say-message request:

| Opcode | Value | Payload |
| --- | ---: | --- |
| `CMSG_MESSAGECHAT` | `0x095` | `uint32 chat_type`, `uint32 language`, null-terminated message |

Initial Stage 16 request values:

| Field | Value | Notes |
| --- | ---: | --- |
| `chat_type` | `1` | `CHAT_MSG_SAY` |
| `language` | `7` for the current human test character | `LANG_COMMON`; Horde races should use Orcish (`1`) for the same first-slice behavior |
| `message` | Local test string | Must be non-empty, 255 bytes or shorter, and must not contain control text rejected by AzerothCore |

Client self-whisper request:

| Opcode | Value | Payload |
| --- | ---: | --- |
| `CMSG_MESSAGECHAT` | `0x095` | `uint32 chat_type`, `uint32 language`, null-terminated target name, null-terminated message |

Initial self-whisper request values:

| Field | Value | Notes |
| --- | ---: | --- |
| `chat_type` | `7` | `CHAT_MSG_WHISPER` |
| `language` | `7` for the current human test character | The server converts normal whisper responses to universal language |
| `target name` | `Codexstage` | Self-targeted so one local account/session can prove the packet variant |
| `message` | Local test string | Same validation as say-message |

Server echo response:

| Opcode | Value | Stage 16 parser |
| --- | ---: | --- |
| `SMSG_MESSAGECHAT` | `0x096` | Parses chat type, language, sender GUID, receiver GUID, message text, and chat tag |
| `SMSG_GM_MESSAGECHAT` | `0x3B3` | Parser support exists for the extra sender-name field, but the Stage 16 validation used normal `SMSG_MESSAGECHAT` |

Observed Stage 16 result:

- Native helper command `--chat-say` sent `Codex Stage16 chat probe` as `Codexstage`.
- AzerothCore echoed the message with `response_opcode=0x96`, `chat_type=1`, `language=7`, and matching sender/receiver GUIDs.
- Native helper command `--chat-whisper-self` sent `Codex Stage16 whisper probe` to `Codexstage`.
- AzerothCore returned both `CHAT_MSG_WHISPER` and `CHAT_MSG_WHISPER_INFORM`; the final observed response had `chat_type=9` and `language=0`.
- Godot scene `scenes/stage16_chat_view.tscn` passed both paths with `CHAT_SELF_TEST_OK say_opcode=0x096 whisper_opcode=0x096 whisper_seen=true whisper_inform_seen=true`.

Remaining chat packet work:

- Add true receiver-side whisper tests using a second local account/session.
- Parse and build channel/party/guild/raid/emote/AFK/DND variants.
- Surface system messages and server notifications in the chat UI.

## Initial Spellbook Slice

Stage 16 also parses the first server-provided spellbook packet.

Relevant opcode:

| Opcode | Value | Stage 16 support |
| --- | ---: | --- |
| `SMSG_INITIAL_SPELLS` | `0x12A` | Parses the active spell list and cooldown count |

Payload from `Player::SendInitialSpells`:

| Field | Size | Notes |
| --- | ---: | --- |
| spellbook flags | 1 | Currently sent as `0` by AzerothCore |
| spell count | 2 | `uint16` |
| spell id | 4 per spell | Repeated for each active spell/talent/glyph spell sent by the server |
| spell slot | 2 per spell | AzerothCore comments that this is not a slot id; current values are `0` in the local test |
| cooldown count | 2 | `uint16` |
| cooldown rows | 16 per cooldown | `uint32 spell`, `uint16 item`, `uint16 category`, `uint32 cooldown`, `uint32 category cooldown` |

Parser note: AzerothCore currently writes `m_spellCooldowns.size()` as the cooldown count, then skips cooldown rows where `needSendToClient` is false or the spell is invalid. The Stage 16 parser therefore treats the count as an upper bound and reports the cooldown rows actually present in the payload.

Observed Stage 16 result:

- Native helper command `--spellbook` observed `SMSG_INITIAL_SPELLS` for `Codexstage`.
- The live packet contained `48` initial spells and either `0` or `1` serialized cooldown row depending on whether the test character had just cast spell `2457`.
- Godot scene `scenes/stage16_spellbook_view.tscn` passed with `SPELLBOOK_SELF_TEST_OK spells=48`; clean-login runs showed `cooldowns=0`, and immediate post-cast regression showed `cooldowns=1`.

Remaining spell packet work:

- Resolve spell IDs to names, ranks, descriptions, and icons through local-only data.
- Parse cooldown update packets after casts.
- Expand `CMSG_CAST_SPELL` beyond empty and unit-target masks.
- Parse cast success/failure, interrupt, aura, and combat-result packets.

## Spell Cast Slice

Stage 16 now sends a minimal client cast and parses the first accepted server response.

Client cast request:

| Opcode | Value | Payload |
| --- | ---: | --- |
| `CMSG_CAST_SPELL` | `0x12E` | `uint8 cast_count`, `uint32 spell_id`, `uint8 cast_flags`, `SpellCastTargets` |

First-slice request values:

| Field | Value | Notes |
| --- | ---: | --- |
| `cast_count` | `1` | Simple client cast counter for the probe |
| `spell_id` | `2457` | Local test warrior stance spell, selected because it is active and does not require an enemy target |
| `cast_flags` | `0` | No client movement/item extras in this slice |
| `target mask` | `0` | Empty `SpellCastTargets`; target defaults to caster context where the spell allows it |

Unit-target request values:

| Field | Value | Notes |
| --- | ---: | --- |
| `cast_count` | `1` | Simple client cast counter for the probe |
| `spell_id` | `78` | Local test warrior attack spell, selected because the test character already has it on the server-provided action buttons |
| `cast_flags` | `0` | No client movement/item extras in this request; the server response may include its own cast flags |
| `target mask` | `0x00000002` | `TARGET_FLAG_UNIT` |
| `target guid` | Live packed object GUID | Resolved from the Stage 15 visible-object parser, not from a database spawn id |

Server responses parsed by the Stage 16 summary parser:

| Opcode | Value | Stage 16 support |
| --- | ---: | --- |
| `SMSG_CAST_FAILED` | `0x130` | Parses cast count, spell id, and fail reason |
| `SMSG_SPELL_START` | `0x131` | Parses source/caster packed GUIDs, cast count, spell id, and cast flags |
| `SMSG_SPELL_GO` | `0x132` | Parses source/caster packed GUIDs, cast count, spell id, and cast flags |
| `SMSG_SPELL_FAILURE` | `0x133` | Parses caster packed GUID, cast count, spell id, and fail reason |
| `SMSG_SPELL_FAILED_OTHER` | `0x2A6` | Parses caster packed GUID, cast count, spell id, and fail reason |

Observed Stage 16 result:

- Native helper command `--cast-spell` sent spell `2457` as `Codexstage`.
- AzerothCore accepted the cast and returned `SMSG_SPELL_GO` (`0x132`) with `response_spell_id=2457` and `cast_count=1`.
- Godot scene `scenes/stage16_spell_cast_view.tscn` passed with `SPELL_CAST_SELF_TEST_OK spell_id=2457 opcode=0x132 accepted=true`.
- Native helper command `--cast-spell-target` selected a live nearby creature matching entry `721`, sent spell `78`, and observed `live_target_found=1`, `selection_sent=1`, `attack_sent=1`, `cast_sent=1`, `accepted=1`, `response_opcode=0x131`, `response_spell_id=78`, and `cast_flags=0x802`.
- Godot scene `scenes/stage16_spell_cast_view.tscn` passed with `TARGETED_SPELL_CAST_SELF_TEST_OK spell_id=78 target_entry=721 opcode=0x131 accepted=true`.

Remaining spell-cast work:

- Drive casts from action-bar slot clicks instead of a raw spell-id input.
- Add target masks for friendly target, item target, source location, destination location, and string targets.
- Parse and surface cast failures, global cooldown/cooldown updates, interrupt messages, aura application, damage/healing results, and combat log consequences.

## Initial Action Buttons Slice

Stage 16 now parses the first server-provided action-bar packet.

Relevant opcodes:

| Opcode | Value | Stage 16 support |
| --- | ---: | --- |
| `SMSG_ACTION_BUTTONS` | `0x129` | Parses all initial action slots from the login stream |
| `CMSG_SET_ACTION_BUTTON` | `0x128` | Sends controlled set/remove packets and verifies them by re-reading `SMSG_ACTION_BUTTONS` |

Payload from `Player::SendActionButtons`:

| Field | Size | Notes |
| --- | ---: | --- |
| state | 1 | AzerothCore sends `1` for normal initial action-button data. State `2` clears client-side bars. |
| packed action button | 4 per slot | Repeated for 144 slots when state is not `2` |

Packed action-button layout:

| Bits | Meaning |
| --- | --- |
| low 24 bits | action id, usually spell id, item id, macro id, or equipment-set id depending on type |
| high 8 bits | action button type |

Known action button types from AzerothCore:

| Type | Meaning |
| ---: | --- |
| `0` | spell |
| `1` | click/custom click action |
| `32` | equipment set |
| `64` | macro |
| `65` | character macro |
| `128` | item |

Client set-action-button request:

| Field | Size | Notes |
| --- | ---: | --- |
| button | 1 | Slot id, `0` through `143` |
| packed action button | 4 | Same `action | (type << 24)` layout used by `SMSG_ACTION_BUTTONS`; `0` removes the slot |

Observed Stage 16 result:

- Native helper command `--action-buttons` observed `SMSG_ACTION_BUTTONS` for `Codexstage`.
- The live packet contained `144` slots, state `1`, and `3` populated slots.
- Observed populated slots were button `72` action `6603` type `0`, button `73` action `78` type `0`, and button `83` action `117` type `128`.
- Godot scene `scenes/stage16_action_bar_view.tscn` passed with `ACTION_BAR_SELF_TEST_OK slots=144 populated=3 state=1`.
- Godot scene `scenes/stage16_action_bar_view.tscn` rendered all 144 slots and passed `ACORE_ACTION_BAR_CAST_SELF_TEST=1` by casting button `73` spell `78` through the unit-target spell-cast path, receiving `ACTION_BAR_CAST_SELF_TEST_OK button=73 spell_id=78 opcode=0x131 accepted=true`.
- Native helper command `--set-action-button` set empty slot `0` to spell `78` type `0`, confirmed `after_set_action=78`, restored the original empty slot with packed value `0`, and confirmed `after_restore_populated=0`.
- Godot scene `scenes/stage16_action_bar_view.tscn` passed `ACORE_ACTION_BAR_SET_SELF_TEST=1` with `ACTION_BAR_SET_SELF_TEST_OK button=0 action=78 type=0 set_confirmed=true restore_confirmed=true`; a follow-up action-button read still showed `populated=3`.

Remaining action-button packet work:

- Replace the reversible probe with final drag/drop, remove-slot, paging, and keybind UX.
- Add broader persistence checks for multiple slots and action types.
- Connect action buttons to item use, macros, equipment sets, paging, and keybinds.

## Stage 11 First World Target

Stage 11 should connect to worldserver, parse `SMSG_AUTH_CHALLENGE`, send `CMSG_AUTH_SESSION`, initialize header crypto, parse `SMSG_AUTH_RESPONSE`, send `CMSG_CHAR_ENUM`, and parse at least names/guid/race/class/level/map/position from `SMSG_CHAR_ENUM`.
