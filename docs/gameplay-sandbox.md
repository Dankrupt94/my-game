# Gameplay Sandbox

## Purpose

Stage 05 adds a fresh original Godot gameplay sandbox for Path A.

This is a small playable scene used to prove core Godot game-engine pieces before later data-driven and multiplayer work. It is not a WotLK map, not copied client UI, and not a replacement-client milestone by itself.

## Files

```text
scenes/gameplay_sandbox.tscn
scripts/gameplay_sandbox.gd
```

The dashboard opens the sandbox through the `Open Sandbox` action.

Direct scene launch:

```bash
snap run godot-4 --path "/run/media/doodbro/New 1tb/AzerothCore/godot-azerothcore-companion" --scene res://scenes/gameplay_sandbox.tscn
```

Headless self-test:

```bash
ACORE_SANDBOX_SELF_TEST=1 snap run godot-4 --headless --quit-after 5 --path "/run/media/doodbro/New 1tb/AzerothCore/godot-azerothcore-companion" --scene res://scenes/gameplay_sandbox.tscn
```

## Controls

- `WASD`: move.
- `Q` / `E`: rotate the third-person camera.
- `Tab`: cycle target.
- `1`: strike the targeted enemy.
- `F`: talk to the targeted NPC.
- `R`: reset the sandbox.
- Dashboard button: return to the companion dashboard.

## Gameplay Systems

- Third-person player movement with collision.
- Camera follow and camera yaw.
- Basic floor and obstacle collision.
- One original NPC: `Bridge Mentor`.
- One original enemy: `Training Echo`.
- Target selection marker.
- Strike action with range and focus cost.
- Player health, focus, target health, task status, and action buttons.
- Simple task loop: talk to the mentor, defeat the training echo, and return to the dashboard.

## Placeholder Asset Policy

The scene uses only Godot-created primitive meshes, colors, labels, and UI controls.

No proprietary WotLK client files, extracted assets, converted derivatives, names, maps, textures, models, or UI assets are copied into this sandbox.

## Validation

Validated on 2026-06-30:

- Dashboard scene loads in Godot 4.7 headless.
- Sandbox scene loads directly in Godot 4.7 headless.
- Sandbox self-test prints `SANDBOX_SELF_TEST_OK` after exercising mentor interaction, enemy defeat, task completion, and target health UI state.
- Tracked-file guard found no proprietary client assets, local reports, local runtime files, or logs in Git.
