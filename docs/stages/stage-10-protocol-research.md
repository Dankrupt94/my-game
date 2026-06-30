# Stage 10 - Protocol Research

Status: Planned

## Goal

Investigate, document, and define the mathematical algorithms, opcode packet payloads, and crypto structures required to implement a native Godot client connecting directly to the local AzerothCore server.

## Research Areas

- **SRP6 Authentication (Authserver):** Map the client/server handshake protocol (`CMD_AUTH_LOGON_CHALLENGE` and `CMD_AUTH_LOGON_PROOF`). Document large prime algebra, key derivation, and verifying hash equations.
- **Realm List Structure:** Detail how `CMD_REALM_LIST` payload encapsulates port redirection and game build flags.
- **World Server Header Encryption:** Document the RC4 cipher stream state machine used to encrypt client headers (2-byte size, 4-byte opcode) and decrypt server headers (2-byte size, 2-byte opcode).
- **Session Keys:** Map session key propagation from authserver to worldserver (`SMSG_AUTH_CHALLENGE`, `CMSG_AUTH_PROOF`, `SMSG_AUTH_RESPONSE`).
- **AzerothCore Packets Directory:** Inspect packet layouts inside `source/src/server/shared/Packets/` and opcode handlers inside `Opcodes.cpp`.

## Entry Criteria

- Stage 09 marks Path A complete.

## Done Criteria

- **Cryptographic Integration Strategy:** A decision is reached on whether to use C# assembly classes or compile a C++ GDExtension helper to perform SRP6 algebra and RC4 header encryption.
- **Packet Structure Spec:** A document defining the exact byte offsets, types, and values for the login handshake, realm enumeration, world session authentication, character list retrieval, and character select opcodes.
- **Opcode Boundaries Sheet:** A reference sheet mapping client/server opcodes to WotLK build `12340`.

## Documentation To Update During Work

- Git-tracked protocol analysis documents inside `docs/protocol/`.
- SRP6/RC4 library candidate evaluation logs.
- Packet byte specs and structural diagrams.
