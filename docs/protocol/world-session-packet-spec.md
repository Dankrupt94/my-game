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

Item template query:

| Direction | Opcode | Payload | Stage 17 use |
| --- | ---: | --- | --- |
| Client to server | `CMSG_ITEM_QUERY_SINGLE` (`0x056`) | `uint32 item_entry` | Request display/template metadata for a discovered item entry |
| Server to client | `SMSG_ITEM_QUERY_SINGLE_RESPONSE` (`0x058`) | Starts with `uint32 item_entry`, class/subclass fields, four name strings, display id, quality, prices, inventory type, allowable masks, item level, and required level | Parses the early stable fields needed for read-only inventory names and future tooltips |

Stage 17 inventory snapshot behavior:

- `parse_update_object_summary` now reads value update masks into field/value pairs instead of only skipping them.
- When the update GUID matches the selected player GUID, the parser reconstructs 64-bit item GUIDs for 39 equipment, bag, and backpack slots.
- Item object create/update blocks are routed to inventory item detail parsing instead of the general nearby-object list.
- After item entries are known, the flow sends bounded item-template queries and applies resolved names back onto matching slots.
- The Godot scene `scenes/stage17_inventory_view.tscn` displays these slots as live read-only server state with item names, entries, stack counts, and durability where present.
- Local validation observed 39 slots, 7 populated item GUIDs, 7 item-detail rows, and 7 resolved item names for `Codexstage`; coinage was `0`, and the zero-valued coinage field was not included in that live update packet.

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
