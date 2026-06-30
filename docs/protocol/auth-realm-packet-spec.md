# Authserver And Realm Packet Spec

Status: Stage 10 draft

Primary source: `source/src/server/apps/authserver/Server/AuthSession.cpp`

This document covers the first authserver TCP flow on port `3724`.

## Authserver Commands

| Command | Value | Direction | Purpose |
| --- | ---: | --- | --- |
| `AUTH_LOGON_CHALLENGE` | `0x00` | client to server, server to client | Start SRP6 login |
| `AUTH_LOGON_PROOF` | `0x01` | client to server, server to client | Prove SRP6 session |
| `REALM_LIST` | `0x10` | client to server, server to client | Request available realms |

## Client Logon Challenge

Packed struct in AzerothCore: `AUTH_LOGON_CHALLENGE_C`.

All fixed-width numeric fields are little-endian because authserver reads the packed struct directly on this local Linux build.

| Offset | Size | Field | Notes |
| ---: | ---: | --- | --- |
| 0 | 1 | `cmd` | `0x00` |
| 1 | 1 | `error` | Client compatibility byte; server does not use it for the username-size check. |
| 2 | 2 | `size` | Should equal `30 + username_length`. |
| 4 | 4 | `gamename` | Usually `WoW` marker bytes in reversed four-byte client style. |
| 8 | 1 | `version1` | Major version. |
| 9 | 1 | `version2` | Minor version. |
| 10 | 1 | `version3` | Patch version. |
| 11 | 2 | `build` | WotLK 3.3.5a is build `12340`. |
| 13 | 4 | `platform` | Four-byte platform marker. |
| 17 | 4 | `os` | Four-byte OS marker; server reverses string order after reading. |
| 21 | 4 | `country` | Locale marker; server reverses byte order into `_localizationName`. |
| 25 | 4 | `timezone_bias` | Client timezone bias. |
| 29 | 4 | `ip` | Client-side IP field. |
| 33 | 1 | `I_len` | Username byte length. |
| 34 | N | `I` | Username/login bytes. |

Server validation checks that `size - 30 == I_len`.

## Server Logon Challenge Success

The server response is built manually after account lookup and accepted build validation:

| Field | Size | Notes |
| --- | ---: | --- |
| `cmd` | 1 | `0x00` |
| unknown/status byte | 1 | `0x00` in current source |
| result | 1 | `WOW_SUCCESS` on accepted challenge |
| `B` | 32 | SRP6 server ephemeral key |
| `g_len` | 1 | `1` |
| `g` | 1 | `0x07` |
| `N_len` | 1 | `32` |
| `N` | 32 | SRP6 modulus bytes |
| `s` | 32 | account salt |
| version challenge | 16 | Fixed `VersionChallenge` array from authserver |
| `securityFlags` | 1 | `0x00` for normal, `0x04` when TOTP token is required |
| optional security fields | variable | PIN, matrix, or token prompt fields when flags are set |

## Client Logon Proof

Packed struct in AzerothCore: `AUTH_LOGON_PROOF_C`.

| Offset | Size | Field | Notes |
| ---: | ---: | --- | --- |
| 0 | 1 | `cmd` | `0x01` |
| 1 | 32 | `A` | SRP6 client ephemeral key |
| 33 | 20 | `clientM` | SRP6 client proof |
| 53 | 20 | `crc_hash` | Version proof checked by `VerifyVersion` |
| 73 | 1 | `number_of_keys` | Kept for client compatibility |
| 74 | 1 | `securityFlags` | Must match any extra security-token payload |

When `securityFlags & 0x04`, AzerothCore reads an extra token length byte and token string after the fixed struct.

## Server Logon Proof Success

For WotLK/post-BC clients, AzerothCore returns `AUTH_LOGON_PROOF_S`:

| Offset | Size | Field | Notes |
| ---: | ---: | --- | --- |
| 0 | 1 | `cmd` | `0x01` |
| 1 | 1 | `error` | `0` on success |
| 2 | 20 | `M2` | Server proof: `SHA1(A, clientM, session_key)` |
| 22 | 4 | `AccountFlags` | From account flags |
| 26 | 4 | `SurveyId` | `0` in current source |
| 30 | 2 | `LoginFlags` | `0` in current source |

After this, authserver status becomes authenticated and the 40-byte session key has been saved in the login database.

## Realm List Request

Handler size is fixed at 5 bytes:

| Offset | Size | Field | Notes |
| ---: | ---: | --- | --- |
| 0 | 1 | `cmd` | `0x10` |
| 1 | 4 | reserved | Usually zero bytes |

## Realm List Response

The response starts with:

| Field | Size | Notes |
| --- | ---: | --- |
| `cmd` | 1 | `0x10` |
| payload size | 2 | Size of the remaining realm-list body |
| reserved | 4 | AzerothCore writes `uint32(0)` |
| realm count | 2 | For WotLK/post-BC clients |

Each realm entry contains:

| Field | Size | Notes |
| --- | ---: | --- |
| realm type | 1 | From `realmlist.icon` / realm type |
| lock | 1 | `1` when account security is too low |
| flags | 1 | Realm flags |
| name | variable | Null-terminated string |
| address | variable | Null-terminated endpoint string from `Realm::GetAddressForClient`, for example `127.0.0.1:8085` |
| population | 4 | Float |
| character count | 1 | Per-account characters on that realm |
| timezone | 1 | Realm category |
| realm id | 1 | Realm id from `realmlist.id` |
| optional build fields | variable | Present when `REALM_FLAG_SPECIFYBUILD` is set |

For WotLK/post-BC clients, AzerothCore appends trailer bytes `0x10 0x00`.

## Stage 11 First Auth Target

Stage 11 should authenticate a local test account, request the realm list, parse the first realm endpoint, and keep the 40-byte session key in memory only.

Minimum realm endpoint parsing:

- Read `realm count`.
- If count is `0`, fail with a clear "no compatible realms" error.
- Read the first realm entry.
- Extract the null-terminated endpoint string.
- For the current local setup, expect an IPv4-style endpoint such as `127.0.0.1:8085`.
- Split the local IPv4 endpoint on the final colon into host and port.
- Store the realm id byte from the same realm entry; Stage 11 must pass it back as `RealmID` in `CMSG_AUTH_SESSION`.
- Do not write realm data back to the database.
