# Opcode Boundaries For Build 12340

Status: Stage 10 draft

Primary sources:

- `source/src/server/game/Server/Protocol/Opcodes.h`
- `source/src/server/game/Server/Protocol/Opcodes.cpp`

These are the first opcodes needed for a Godot-native client that can authenticate, list characters, and begin entering world.

## Authserver Command Bytes

These are authserver command bytes, not world opcodes:

| Name | Value | Purpose |
| --- | ---: | --- |
| `AUTH_LOGON_CHALLENGE` | `0x00` | Authserver SRP6 challenge |
| `AUTH_LOGON_PROOF` | `0x01` | Authserver SRP6 proof |
| `AUTH_RECONNECT_CHALLENGE` | `0x02` | Reconnect challenge |
| `AUTH_RECONNECT_PROOF` | `0x03` | Reconnect proof |
| `REALM_LIST` | `0x10` | Authserver realm list |

## Stage 11 World Opcodes

| Name | Value | Direction | Required session status in AzerothCore | Handler or source |
| --- | ---: | --- | --- | --- |
| `CMSG_AUTH_SESSION` | `0x1ED` | client to server | `STATUS_NEVER` special world-socket processing | `WorldSocket::HandleAuthSession` |
| `SMSG_AUTH_CHALLENGE` | `0x1EC` | server to client | server packet | `WorldSocket::HandleSendAuthSession` |
| `SMSG_AUTH_RESPONSE` | `0x1EE` | server to client | server packet | `WorldSession::SendAuthResponse` / `WorldSocket::SendAuthResponseError` |
| `CMSG_CHAR_ENUM` | `0x037` | client to server | `STATUS_AUTHED` | `WorldSession::HandleCharEnumOpcode` |
| `SMSG_CHAR_ENUM` | `0x03B` | server to client | server packet | `WorldSession::HandleCharEnum` |
| `CMSG_PLAYER_LOGIN` | `0x03D` | client to server | `STATUS_AUTHED` | `WorldSession::HandlePlayerLoginOpcode` |
| `SMSG_LOGIN_VERIFY_WORLD` | `0x236` | server to client | server packet | `WorldSession::HandlePlayerLoginFromDB` |
| `SMSG_UPDATE_OBJECT` | `0x0A9` | server to client | server packet | `UpdateData::BuildPacket` / Stage 14 target |

## Movement Opcodes To Carry Into Stage 13

These are not Stage 11 requirements, but they are core to later movement work:

| Name | Value | Direction | Handler |
| --- | ---: | --- | --- |
| `MSG_MOVE_START_FORWARD` | `0x0B5` | bidirectional/client handled | `WorldSession::HandleMovementOpcodes` |
| `MSG_MOVE_START_BACKWARD` | `0x0B6` | bidirectional/client handled | `WorldSession::HandleMovementOpcodes` |
| `MSG_MOVE_STOP` | `0x0B7` | bidirectional/client handled | `WorldSession::HandleMovementOpcodes` |
| `MSG_MOVE_START_STRAFE_LEFT` | `0x0B8` | bidirectional/client handled | `WorldSession::HandleMovementOpcodes` |
| `MSG_MOVE_START_STRAFE_RIGHT` | `0x0B9` | bidirectional/client handled | `WorldSession::HandleMovementOpcodes` |
| `MSG_MOVE_STOP_STRAFE` | `0x0BA` | bidirectional/client handled | `WorldSession::HandleMovementOpcodes` |
| `MSG_MOVE_JUMP` | `0x0BB` | bidirectional/client handled | `WorldSession::HandleMovementOpcodes` |
| `MSG_MOVE_START_TURN_LEFT` | `0x0BC` | bidirectional/client handled | `WorldSession::HandleMovementOpcodes` |
| `MSG_MOVE_START_TURN_RIGHT` | `0x0BD` | bidirectional/client handled | `WorldSession::HandleMovementOpcodes` |
| `MSG_MOVE_STOP_TURN` | `0x0BE` | bidirectional/client handled | `WorldSession::HandleMovementOpcodes` |
| `MSG_MOVE_HEARTBEAT` | `0x0EE` | bidirectional/client handled | `WorldSession::HandleMovementOpcodes` |
| `MSG_MOVE_TELEPORT_ACK` | `0x0C7` | client to server | `WorldSession::HandleMoveWorldportAckOpcode` |

## Important Boundary Notes

- The authserver protocol on port `3724` is not the same framing as the worldserver protocol on port `8085`.
- World opcode ids are build-specific and this sheet targets WotLK build `12340`.
- World packet body encryption is not used here; only packet headers are encrypted after world auth.
- `SMSG_UPDATE_OBJECT` is the major Stage 14 parser milestone and should be treated as its own large body of work.
