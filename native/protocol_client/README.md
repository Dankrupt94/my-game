# Native Protocol Client Helper

Stage 11 starts with this native helper before exposing the same logic to Godot.

Current safe commands:

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

Set `ACORE_PROTOCOL_TRACE=1` only when debugging world packet headers. It prints opcodes and sizes, not payloads.

The helper must not print passwords, session keys, packet captures with account secrets, or proprietary client data.
