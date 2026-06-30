# Stage 13 - Movement And Reconciliation

Status: Planned

## Goal

Move a Godot-controlled character through AzerothCore protocol messages.

## Deliverables

- Godot movement input.
- Convert Godot movement to server movement messages.
- Receive movement responses/updates.
- Basic reconciliation between local and server position.
- Clear debug display for position mismatch.

## Entry Criteria

- Stage 12 enter-world prototype works.

## Done Criteria

- Moving in Godot updates the AzerothCore session without immediate desync.

## Documentation To Update During Work

- Movement packet notes.
- Coordinate mapping notes.
- Reconciliation strategy.
- Desync cases.

