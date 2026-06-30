# Crypto Integration Decision

Status: Decided for Stage 11

Decision: build a native C++ protocol/crypto helper first, then expose it to Godot through a GDExtension wrapper once the Godot C++ binding layer is added.

## Reason

Stage 11 needs SRP6, SHA-1, HMAC-SHA1, ARC4-drop1024, byte-order helpers, and packet header encryption/decryption. This should not live in GDScript.

The local machine currently has:

- Godot 4.7 Mono runtime available through `godot-4`.
- `g++` available.
- CMake available.
- No `dotnet` command available.
- No `scons` command available.

Because `dotnet` is absent, a C# assembly path would require extra tool installation before it can be validated. C++ is available now and aligns with a later Godot GDExtension boundary.

## Implementation Direction

Stage 11 should start with a small native C++ library and command-line smoke harness under Git-tracked source. The helper should expose narrow functions:

- build authserver logon challenge bytes,
- compute SRP6 client proof values,
- validate authserver proof response,
- build realm-list request bytes,
- build world `CMSG_AUTH_SESSION`,
- initialize world header ciphers from the 40-byte session key,
- encrypt outbound client headers,
- decrypt inbound server headers.

After the helper passes local tests, add the GDExtension wrapper so Godot can call the same implementation.

## Source Evidence

Local AzerothCore references:

- `source/src/common/Cryptography/Authentication/SRP6.h`
- `source/src/common/Cryptography/Authentication/SRP6.cpp`
- `source/src/common/Cryptography/Authentication/AuthCrypt.h`
- `source/src/common/Cryptography/Authentication/AuthCrypt.cpp`
- `source/src/common/Cryptography/Authentication/AuthDefines.h`

Important source facts:

- `SESSION_KEY_LENGTH` is 40 bytes.
- SRP6 salt, verifier, and ephemeral keys are 32 bytes.
- SRP6 generator `g` is one byte: `0x07`.
- SRP6 modulus `N` is 32 bytes: `894B645E89E1535BBDAD5B8B290650530801B18EBFBF5E8FAB3C82872A3E9BB7`, stored in little-endian byte-array form by the AzerothCore helper.
- AuthCrypt derives separate ARC4 streams with HMAC-SHA1 and drops the first 1024 bytes.

## World Header Crypto Direction

From the Godot/client point of view:

- Decrypt server-to-client headers with `HMAC_SHA1(ServerEncryptionKey, session_key)`, then ARC4-drop1024.
- Encrypt client-to-server headers with `HMAC_SHA1(ServerDecryptionKey, session_key)`, then ARC4-drop1024.

The server-side key labels are from `AuthCrypt.cpp`:

- `ServerEncryptionKey`: `CC 98 AE 04 E8 97 EA CA 12 DD C0 93 42 91 53 57`
- `ServerDecryptionKey`: `C2 B3 72 3C C6 AE D9 B5 34 3C 53 EE 2F 43 67 CE`

## Guardrails

- Do not commit account passwords, session keys, packet captures with secrets, or generated runtime dumps.
- Use generated local test accounts only.
- Keep protocol helpers original. Do not copy proprietary WotLK client code.
- If GPL AzerothCore code is reused directly, document the licensing implication before committing it.
