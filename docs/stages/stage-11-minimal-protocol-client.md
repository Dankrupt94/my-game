# Stage 11 - Minimal Protocol Client

Status: Planned

## Goal

Build a minimal TCP-based network client module inside Godot that handles the SRP6 challenge/proof, queries the realm list, connects to the worldserver, authenticates the session key, and successfully queries the character list.

## Deliverables

- **Godot TCP Module:** Implement an asynchronous TCP socket wrapper class in Godot.
- **Logon Challenge and Proof Handler:** Execute challenge exchange (`CMD_AUTH_LOGON_CHALLENGE`) and logon proof generation (`CMD_AUTH_LOGON_PROOF`) using the cryptographic native wrapper determined in Stage 10.
- **Realm Redirection parser:** Parse `CMD_REALM_LIST` payload to redirect the socket connection to the target worldserver port.
- **Opcode Encryption Engine:** Initialize the RC4-based header cipher with the derived session key. Encrypt world client packet headers (6 bytes) and decrypt incoming server packet headers (4 bytes).
- **Session Authentication Exchange:** Connect to worldserver (`8085`), read `SMSG_AUTH_CHALLENGE`, generate the SHA1 proof, and send `CMSG_AUTH_PROOF`.
- **Character Enum display:** Parse `SMSG_AUTH_RESPONSE` on success, send `CMSG_CHAR_ENUM`, and print character names, levels, classes, and GUIDs returned.

## Entry Criteria

- Stage 10 protocol research and crypto library selection are complete.

## Done Criteria

- Godot establishes sockets to the authserver and worldserver natively.
- Godot executes the SRP6 handshake and initializes the RC4 header cipher state.
- Godot logs the account's character lists using WotLK network protocol messages, verified with the official client offline.

## Documentation To Update During Work

- Socket connection state diagram.
- Cryptography performance benchmarks inside Godot.
- Opcode encryption verification dumps.
