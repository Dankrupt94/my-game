# Native Protocol Client Helper

Stage 11 starts with this native helper before exposing the same logic to Godot.

Current safe CLI commands:

```bash
cmake -S native/protocol_client -B native/protocol_client/build
cmake --build native/protocol_client/build
native/protocol_client/build/acore_protocol_client --self-test
native/protocol_client/build/acore_protocol_client --auth-challenge 127.0.0.1 3724 ADMIN
ACORE_PROTOCOL_PASSWORD='local password only' native/protocol_client/build/acore_protocol_client --auth-flow 127.0.0.1 3724 ADMIN
ACORE_PROTOCOL_PASSWORD='local password only' native/protocol_client/build/acore_protocol_client --character-flow 127.0.0.1 3724 ADMIN
native/protocol_client/build/acore_protocol_client --world-challenge 127.0.0.1 8085
```

For the local disposable protocol account, load the ignored file first:

```bash
set -a; . local_runtime/protocol-test-account.env; set +a
native/protocol_client/build/acore_protocol_client --character-flow 127.0.0.1 3724 "$ACORE_PROTOCOL_ACCOUNT"
```

The same reusable protocol flow also builds into a shared library boundary:

```text
native/protocol_client/build/libacore_protocol_bridge.so
```

The shared library currently exposes C-compatible JSON functions for a future Godot-native wrapper. It is not a full GDExtension yet; it is the stable native boundary that the GDExtension or another Godot load path should call from a worker thread.

Safe shared-library smoke checks:

```bash
python3 tools/protocol_bridge_ctypes_smoke.py
set -a; . local_runtime/protocol-test-account.env; set +a
python3 tools/protocol_bridge_ctypes_smoke.py
```

Set `ACORE_PROTOCOL_TRACE=1` only when debugging world packet headers. It prints opcodes and sizes, not payloads.

The helper and bridge library must not print passwords, session keys, packet captures with account secrets, or proprietary client data.
