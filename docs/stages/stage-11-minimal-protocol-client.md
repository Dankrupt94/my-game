# Stage 11 - Minimal Protocol Client

Status: In Progress

## Goal

Build a minimal TCP-based network client path that handles the SRP6 challenge/proof, queries the realm list, connects to the worldserver, authenticates the session key, and successfully queries the character list.

## Deliverables

- **Native Protocol Helper:** Implement a small native C++ helper first for SRP6, realm parsing, world header crypto, and character enum parsing.
- **Godot TCP Module:** Add a Godot-facing asynchronous TCP socket wrapper after the helper can complete the flow from a local smoke harness.
- **Logon Challenge and Proof Handler:** Execute challenge exchange (`CMD_AUTH_LOGON_CHALLENGE`) and logon proof generation (`CMD_AUTH_LOGON_PROOF`) using the cryptographic native wrapper determined in Stage 10.
- **Realm Redirection parser:** Parse `CMD_REALM_LIST` payload to redirect the socket connection to the target worldserver port.
- **Opcode Encryption Engine:** Initialize the RC4-based header cipher with the derived session key. Encrypt world client packet headers (6 bytes) and decrypt incoming server packet headers (4 bytes).
- **Session Authentication Exchange:** Connect to worldserver (`8085`), read `SMSG_AUTH_CHALLENGE`, generate the SHA1 proof, and send `CMSG_AUTH_SESSION`.
- **Character Enum display:** Parse `SMSG_AUTH_RESPONSE` on success, send `CMSG_CHAR_ENUM`, and print character names, levels, classes, and GUIDs returned.

## Entry Criteria

- [x] Stage 10 protocol research and crypto library selection are complete.

## Stage Start Notes

Started on 2026-06-30.

Stage 11 begins from the Stage 10 decision to build a native C++ helper first because `g++` and CMake are available locally and `dotnet` is not installed.

The first implementation checkpoint should be a safe local smoke harness that can exercise the protocol without writing proprietary files or committing account secrets. Godot integration follows once the helper proves the auth, realm, world auth, and character-enum byte handling.

## Implementation Notes

- Added `native/protocol_client/` as the first native helper.
- Added CMake build support for `acore_protocol_client`.
- Added local ARC4 implementation for header crypto so the helper does not depend on deprecated OpenSSL RC4 APIs.
- Used OpenSSL only for HMAC-SHA1 support.
- Added protocol byte helpers for:
  - client world headers: 2-byte big-endian size plus 4-byte little-endian opcode,
  - server world headers: 2-byte or 3-byte big-endian size plus 2-byte little-endian opcode,
  - server header parsing.
- Added SRP6 registration/proof math with a synthetic client/server self-test.
- SRP6 intentionally uses SHA-1 and little-endian byte conversion because those are compatibility requirements of the WotLK/AzerothCore protocol being implemented.
- Added `--self-test` to validate first header encoding and header crypto initialization.
- Added `--auth-challenge <host> <port> <account>` to send `AUTH_LOGON_CHALLENGE` and parse the public SRP6 challenge response without a password.
- Added guarded `--auth-flow <host> <port> <account>`, which reads the password only from `ACORE_PROTOCOL_PASSWORD`, verifies SRP6 server proof, requests realm list, and prints the first realm endpoint.
- Added `--world-challenge <host> <port>` to connect to the live worldserver and parse the initial plaintext `SMSG_AUTH_CHALLENGE`.

## Validation

Completed on 2026-06-30:

- `cmake -S native/protocol_client -B native/protocol_client/build` succeeded.
- `cmake --build native/protocol_client/build` succeeded.
- `native/protocol_client/build/acore_protocol_client --self-test` printed `PROTOCOL_CLIENT_SELF_TEST_OK` and `SRP6_SELF_TEST_OK`.
- `native/protocol_client/build/acore_protocol_client --auth-challenge 127.0.0.1 3724 ADMIN` prints `AUTH_CHALLENGE_OK` when the local `ADMIN` account exists and the authserver accepts build `12340`.
- `native/protocol_client/build/acore_protocol_client --auth-flow 127.0.0.1 3724 ADMIN` fails safely with `ACORE_PROTOCOL_PASSWORD is not set` when no local password is supplied.
- `native/protocol_client/build/acore_protocol_client --world-challenge 127.0.0.1 8085` printed `WORLD_CHALLENGE_OK`.
- No account credentials, session keys, packet captures, proprietary client files, or local runtime files were committed.

## Done Criteria

- Godot establishes sockets to the authserver and worldserver natively.
- Godot executes the SRP6 handshake and initializes the RC4 header cipher state.
- Godot logs the account's character lists using WotLK network protocol messages, verified with the official client offline.

## Documentation To Update During Work

- Socket connection state diagram.
- Cryptography performance benchmarks inside Godot.
- Opcode encryption verification dumps.
