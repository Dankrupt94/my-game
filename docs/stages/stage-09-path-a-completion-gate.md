# Stage 09 - Path A Completion Gate

Status: In Progress

## Goal

Decide whether Path A is achieved and whether the project is ready to begin Path B.

Path A is a readiness gate, not a product fork. A companion dashboard, original sandbox, or Godot-native multiplayer proof does not satisfy the full WotLK port goal by itself.

## Path A Completion Requirements

- Companion dashboard works.
- Safe command layer works.
- Local bridge service works.
- Godot can inspect safe AzerothCore data.
- Godot has an original playable sandbox.
- Godot-native multiplayer works locally.
- Godot persistence works.
- Documentation is current.

## Decision

Only after this stage is complete should the project begin Path B protocol-client work. The expected decision is "begin Path B" once the checklist is complete, unless the user explicitly changes the mission.

## Done Criteria

- A written decision is added to this file.
- Missing Path A work is either complete or intentionally deferred.
- Risks for Path B are documented.

## Gate Review Start

Started on 2026-06-30.

This review checks whether Path A has achieved its intended purpose: a safe Godot-side engine layer, a local bridge boundary, read-only AzerothCore data inspection, an original playable sandbox, local multiplayer proof, and ignored local persistence.

The review must not mistake Path A for the final product. The final project goal remains a full Godot-native WotLK client/port that can replace the original WotLK client for normal play against AzerothCore as completely as possible.

## Documentation To Update During Work

- Completion checklist.
- Deferred work list.
- Path B go/no-go decision.
