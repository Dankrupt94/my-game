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

Important Stage 15 correction: database spawn GUIDs are not live packet GUIDs. AzerothCore creates runtime object counters when the map instantiates creatures/gameobjects. Client actions must target the live `ObjectGuid` from the update stream.

## Movement Start/Stop Slice

Stage 13 uses the shared movement opcodes handled by `WorldSession::HandleMovementOpcodes`.

| Opcode | Value | Stage 13 use |
| --- | ---: | --- |
| `MSG_MOVE_START_FORWARD` | `0x0B5` | Sent at the current server login coordinate with `MOVEMENTFLAG_FORWARD` |
| `MSG_MOVE_STOP` | `0x0B7` | Sent at the target coordinate with no movement flags |
| `MSG_MOVE_HEARTBEAT` | `0x0EE` | Packet builder support exists, but bare heartbeat did not reliably persist a changed coordinate in the Stage 13 test |
| `SMSG_TIME_SYNC_REQ` | `0x390` | Used as the post-map-add signal before movement packets are sent |
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
| `SMSG_ATTACKERSTATEUPDATE` | `0x14A` | Damage/combat-state update, to be parsed more fully during Stage 16 |

Stage 15 native evidence:

- NPC interaction against entry `823` resolved live GUID `0xf130000337000cea` and received `SMSG_GOSSIP_MESSAGE` (`0x17D`).
- Combat probe against entry `721` resolved live GUID `0xf1300002d1000cef` and received `SMSG_ATTACKSTART` (`0x143`).

Stage 16 should parse gossip menu payloads, attack-state update fields, health updates, spell casts, threat/death state, and target frame deltas instead of treating response opcodes as the final state surface.

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

Observed Stage 16 result:

- Native helper command `--spellbook` observed `SMSG_INITIAL_SPELLS` for `Codexstage`.
- The live packet contained `48` initial spells and `0` cooldown rows.
- Godot scene `scenes/stage16_spellbook_view.tscn` passed with `SPELLBOOK_SELF_TEST_OK spells=48 cooldowns=0`.

Remaining spell packet work:

- Resolve spell IDs to names, ranks, descriptions, and icons through local-only data.
- Parse cooldown update packets after casts.
- Build and validate `CMSG_CAST_SPELL` with target flags.
- Parse cast success/failure, interrupt, aura, and combat-result packets.

## Stage 11 First World Target

Stage 11 should connect to worldserver, parse `SMSG_AUTH_CHALLENGE`, send `CMSG_AUTH_SESSION`, initialize header crypto, parse `SMSG_AUTH_RESPONSE`, send `CMSG_CHAR_ENUM`, and parse at least names/guid/race/class/level/map/position from `SMSG_CHAR_ENUM`.
