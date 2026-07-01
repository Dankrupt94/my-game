# Godot Native Protocol Boundary

Status: Stage 11 checkpoint

## Purpose

The validated auth, realm, world-auth, and character-enum flow now has three layers:

- `acore_protocol_core`: reusable C++ protocol implementation.
- `acore_protocol_client`: CLI smoke helper and fallback dashboard bridge target.
- `acore_protocol_bridge`: shared-library boundary for a future Godot-native wrapper.

This checkpoint does not replace the dashboard helper-process bridge yet. It creates the native loading boundary needed to replace that bridge with a GDExtension or another Godot-supported native call path.

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

The next Godot-native wrapper should:

- Keep `scripts/protocol_client_bridge.gd` as a working fallback until native loading is proven.
- Call the native protocol boundary from a worker thread, because auth and world socket reads are blocking.
- Parse the returned JSON into the same dictionary shape currently used by the dashboard.
- Preserve the current dashboard status label and log formatting.
- Avoid storing account passwords in scenes or tracked project settings.

Tooling note: this machine currently has Godot 4.7 Mono, but `dotnet` and `scons` were not available during this checkpoint. That is why this step stops at a plain shared-library boundary instead of claiming a finished GDExtension.

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
