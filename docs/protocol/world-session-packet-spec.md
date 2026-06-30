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

## Character Select

Client request:

| Opcode | Payload |
| --- | --- |
| `CMSG_PLAYER_LOGIN` (`0x03D`) | Raw `ObjectGuid`, 8-byte little-endian value |

First expected world-position response:

| Opcode | Payload |
| --- | --- |
| `SMSG_LOGIN_VERIFY_WORLD` (`0x236`) | `uint32 map`, `float x`, `float y`, `float z`, `float orientation` |

After that, the server sends the broader login packet stream and eventually object updates. Stage 12 should not pretend the enter-world flow is complete until `SMSG_UPDATE_OBJECT` parsing is underway.

## Stage 11 First World Target

Stage 11 should connect to worldserver, parse `SMSG_AUTH_CHALLENGE`, send `CMSG_AUTH_SESSION`, initialize header crypto, parse `SMSG_AUTH_RESPONSE`, send `CMSG_CHAR_ENUM`, and parse at least names/guid/race/class/level/map/position from `SMSG_CHAR_ENUM`.
