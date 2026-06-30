# Stage 05 - Godot Gameplay Sandbox

Status: Complete

## Goal

Build a fresh original Godot gameplay sandbox under the AzerothCore companion direction.

This is not the retired prototype. It is a new sandbox used to prove Godot can act as a real game engine layer.

## Deliverables

- Third-person player controller.
- Camera and collision.
- Basic test zone.
- One original NPC.
- One original enemy.
- Targeting.
- Basic attack/action bar.
- Health/resource UI.
- Simple interaction loop.

## Entry Criteria

- Stage 04 bridge exists or Stage 02 command layer is stable enough to support tooling.
- Current project identity is `AzerothCore Godot Companion`.

## Stage Start Notes

- Stage 05 begins after the completed localhost bridge boundary.
- The sandbox must use original placeholder geometry/materials only.
- The scene should prove core Godot game-engine pieces: movement, camera, collision, targeting, a basic interaction/combat loop, UI, and a way back to the dashboard.
- This is Path A risk reduction. It should not copy WotLK assets, names, UI, maps, or client data.

## Done Criteria

- [x] A user can launch a playable original Godot scene.
- [x] No proprietary client assets are copied into the repo.
- [x] Gameplay code is modular enough to keep or replace later.

## Implementation Notes

- Added `scenes/gameplay_sandbox.tscn`.
- Added `scripts/gameplay_sandbox.gd`.
- Added an `Open Sandbox` dashboard action.
- The sandbox creates its own placeholder floor, obstacles, player, NPC, enemy, camera, target marker, and UI using Godot primitives and materials.
- The sandbox includes a dashboard return button.
- Preserved parse-checked modular scaffolding for later player, camera, targeting, stats, cooldown, state-machine, and floating-text refactors. These files are not the active dashboard-launched scene yet.

## Gameplay Added

- Third-person movement with `CharacterBody3D`.
- Camera yaw/follow.
- Floor and obstacle collision.
- Original NPC: `Bridge Mentor`.
- Original enemy: `Training Echo`.
- Target cycling and target marker.
- Strike action with range and focus cost.
- Player health, focus, target health, and task UI.
- Simple task loop: talk to the mentor and defeat the training echo.
- Headless self-test mode for the mentor/task/enemy/UI loop through `ACORE_SANDBOX_SELF_TEST=1`.

## Validation

Completed on 2026-06-30:

- `snap run godot-4 --headless --quit-after 5 --path ".../godot-azerothcore-companion" --scene res://scenes/gameplay_sandbox.tscn` exited `0`.
- `snap run godot-4 --headless --quit-after 5 --path ".../godot-azerothcore-companion" --scene res://main.tscn` exited `0`.
- `ACORE_SANDBOX_SELF_TEST=1 snap run godot-4 --headless --quit-after 5 --path ".../godot-azerothcore-companion" --scene res://scenes/gameplay_sandbox.tscn` printed `SANDBOX_SELF_TEST_OK`.
- Modular scaffold scripts parse successfully with Godot 4.7 `--check-only --script`.
- The sandbox script contains no proprietary asset references and uses only original placeholder names/content.
- The tracked-file guard found no proprietary client assets, local reports, local runtime files, or logs in Git.

## Documentation To Update During Work

- [x] Scene list.
- [x] Control scheme.
- [x] Gameplay systems added.
- [x] Placeholder asset policy.
- [x] Manual test notes.
