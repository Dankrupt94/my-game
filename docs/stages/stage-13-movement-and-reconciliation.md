# Stage 13 - Movement And Reconciliation

Status: Planned

## Goal

Synchronize client-side player movements (coordinates, state flags, and orientation) with the AzerothCore world server using a two-phased implementation that eliminates movement-loop desyncs.

## Deliverables

- **Phase 13a: Passive Mimicry Module (De-risking)**
  - Establish a secondary connection or parse updates when another official WotLK client moves on the same map.
  - Parse server movement updates and reposition a passive Godot replica avatar in real-time, verifying coordinate scaling, orientation rotation, and packet structure correctness.
- **Phase 13b: Active WASD Input Synchronization**
  - Implement third-person WASD controls in Godot.
  - Package movement start/stop states into client packets: `CMSG_MOVE_START_FORWARD`, `CMSG_MOVE_START_BACKWARD`, `CMSG_MOVE_STOP`, `CMSG_MOVE_JUMP` containing ticks, status flags, coordinates, and orientation.
- **Reconciliation Engine:**
  - Read server position confirmations and repositioning packets (`MSG_MOVE_TELEPORT_ACK` / teleport packets).
  - Implement a basic threshold-based interpolation layer to snap or smoothly adjust the player avatar when local client prediction drifts from the server-authoritative state.

## Entry Criteria

- Stage 12 enter-world prototype successfully initializes in 3D coordinate space.

## Done Criteria

- Moving in Godot updates the character position in the live AzerothCore database.
- Watching from an external, official WotLK client shows the Godot character moving smoothly without stuttering, rapid rubber-banding, or server kicks.

## Documentation To Update During Work

- Client-side movement packet layout (types and header fields).
- Coordinate mapping rules (conversion between WoW scale and Godot units).
- Position reconciliation thresholds and desync logs.
