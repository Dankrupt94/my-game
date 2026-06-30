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

The helper must not print passwords, session keys, packet captures with account secrets, or proprietary client data.
