# Godot Protocol GDExtension

This is the first Godot-native wrapper around the Stage 11 protocol client.

It registers:

```text
AcoreProtocolClient
```

Current methods:

- `self_test()`
- `character_flow(host, port, account, password)`

The wrapper calls the native C++ protocol core directly. It does not launch the helper process.

## Local Build

The installed `godot-4` app is a Snap package. A host-built extension required GLIBC `2.43`, which Snap Godot could not load, so the working local build path uses Docker with Ubuntu 24.04:

```bash
tools/build_godot_protocol_extension_compat.sh
```

This keeps `godot-cpp`, generated API files, build folders, and the produced `.so` local-only and ignored by Git.

Generated local binary:

```text
bin/libacore_godot_protocol.linux.template_debug.x86_64.so
```

Tracked loader file:

```text
acore_protocol.gdextension
```

## Smoke Checks

No-secret extension check:

```bash
godot-4 --headless --path . --script res://tools/godot_protocol_extension_smoke.gd
```

Dashboard bridge path:

```bash
godot-4 --headless --path . --script res://tools/protocol_bridge_smoke.gd
```

The bridge smoke should report:

```json
{"ok":true,"source":"Godot native extension"}
```

The dashboard still keeps the helper-process path as a fallback if the native class is unavailable.
