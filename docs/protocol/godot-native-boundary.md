# Godot Native Protocol Boundary

Status: Stage 11 checkpoint, GDExtension wrapper added

## Purpose

The validated auth, realm, world-auth, and character-enum flow now has four layers:

- `acore_protocol_core`: reusable C++ protocol implementation.
- `acore_protocol_client`: CLI smoke helper and fallback dashboard bridge target.
- `acore_protocol_bridge`: shared-library boundary for a future Godot-native wrapper.
- `AcoreProtocolClient`: Godot GDExtension wrapper class.

The dashboard bridge now prefers the GDExtension wrapper when Godot can load it, and keeps the helper process as the fallback.

## Shared Library

Built artifact:

```text
native/protocol_client/build/libacore_protocol_bridge.so
```

Public header:

```text
native/protocol_client/src/protocol_c_api.h
```

Exported functions:

- `acore_protocol_bridge_self_test_json(output, output_size)`
- `acore_protocol_bridge_character_flow_json(host, port, account, password, output, output_size)`

Return codes:

- `0`: success.
- `1`: protocol/runtime error; JSON output contains `ok:false` and an `error` string.
- `2`: output buffer too small.
- `3`: invalid arguments.

The character-flow function returns JSON with these stable top-level fields:

- `ok`
- `auth_flow_ok`
- `world_auth_ok`
- `char_enum_ok`
- `character_count`
- `realm`
- `skipped_auth_opcodes`
- `skipped_character_opcodes`
- `characters`

Passwords are input-only and must never appear in JSON, logs, docs, or commits.

## Godot Integration Plan

Current Godot wrapper:

- `acore_protocol.gdextension`
- `native/godot_protocol_extension/`
- `AcoreProtocolClient.self_test()`
- `AcoreProtocolClient.character_flow(host, port, account, password)`

The wrapper is called through `scripts/protocol_client_bridge.gd`, which returns the same dictionary shape the dashboard already expects.

The next Godot-native hardening step should:

- Call the native protocol boundary from a worker thread, because auth and world socket reads are blocking.
- Keep the current dashboard status label and log formatting.
- Avoid storing account passwords in scenes or tracked project settings.

Tooling note: this machine currently uses Snap Godot 4.7. A host-built GDExtension required GLIBC `2.43`, which Snap Godot could not load. The working build path uses `tools/build_godot_protocol_extension_compat.sh` to build the extension inside Ubuntu 24.04 through Docker.

## Validation

Run the no-secret smoke test:

```bash
python3 tools/protocol_bridge_ctypes_smoke.py
```

Run the ignored local-account smoke test:

```bash
set -a; . local_runtime/protocol-test-account.env; set +a
python3 tools/protocol_bridge_ctypes_smoke.py
```

Expected local-account milestones:

- self-test JSON includes `"ok":true`
- character-flow JSON includes `"auth_flow_ok":true`
- character-flow JSON includes `"world_auth_ok":true`
- character-flow JSON includes `"char_enum_ok":true`

Run the Godot-native wrapper smoke test:

```bash
godot-4 --headless --path . --script res://tools/godot_protocol_extension_smoke.gd
```

Run the dashboard bridge path:

```bash
godot-4 --headless --path . --script res://tools/protocol_bridge_smoke.gd
```

The bridge path should report `"source":"Godot native extension"`.
