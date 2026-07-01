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

Additional parse-checked modular scaffolding is present for later refactors:

```text
scenes/floating_text.tscn
scripts/ability_cooldowns.gd
scripts/camera_controller.gd
scripts/entity_stats.gd
scripts/floating_text.gd
scripts/player_controller.gd
scripts/player_states/
scripts/sandbox.gd
scripts/state_machine.gd
scripts/targeting_system.gd
```

These modular files are not the active dashboard-launched scene yet. They are kept as safe scaffolding for breaking the sandbox into reusable player, camera, targeting, cooldown, state-machine, stats, and floating-text systems during later Stage 05/06 cleanup.

Direct scene launch:

```bash
snap run godot-4 --path "/run/media/doodbro/New 1tb/AzerothCore/godot-azerothcore-companion" --scene res://scenes/gameplay_sandbox.tscn
```

Headless self-test:

```bash
ACORE_SANDBOX_SELF_TEST=1 snap run godot-4 --headless --quit-after 5 --path "/run/media/doodbro/New 1tb/AzerothCore/godot-azerothcore-companion" --scene res://scenes/gameplay_sandbox.tscn
```

Headless data self-test:

```bash
ACORE_SANDBOX_DATA_SELF_TEST=1 snap run godot-4 --headless --quit-after 600 --path "/run/media/doodbro/New 1tb/AzerothCore/godot-azerothcore-companion" --scene res://scenes/gameplay_sandbox.tscn
```

## Controls

- `WASD`: move by default.
- `Q` / `E`: rotate the third-person camera by default.
- `Tab`: cycle target by default.
- `1`: strike the targeted enemy by default.
- `F`: talk to the targeted NPC by default.
- `R`: reset the sandbox by default.
- Dashboard button: return to the companion dashboard.

The sandbox applies saved keybindings from `user://settings.cfg` on startup through `scripts/settings_runtime.gd`, so these defaults can be changed from the settings scene.

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

## Data-Driven Slice

Stage 06 adds read-only bridge data to the sandbox:

- Character rows are displayed as UI text.
- Creature template rows spawn original capsule placeholders in the test zone.
- Quest template rows are displayed as task data text.
- Item template rows are displayed as inventory placeholder text.

The sandbox uses only `GET /data` and does not write to AzerothCore databases.

## Placeholder Asset Policy

The scene uses only Godot-created primitive meshes, colors, labels, and UI controls.

No proprietary WotLK client files, extracted assets, converted derivatives, names, maps, textures, models, or UI assets are copied into this sandbox.

## Validation

Validated on 2026-06-30:

- Dashboard scene loads in Godot 4.7 headless.
- Sandbox scene loads directly in Godot 4.7 headless.
- Sandbox self-test prints `SANDBOX_SELF_TEST_OK` after exercising mentor interaction, enemy defeat, task completion, and target health UI state.
- Sandbox keybinding settings self-test prints `SANDBOX_KEYBIND_SETTINGS_SELF_TEST_OK` after loading a temporary settings file and applying a saved movement binding.
- Sandbox data self-test prints `SANDBOX_DATA_SELF_TEST_OK` after loading bridge records and spawning creature placeholders.
- Modular scaffold scripts parse successfully with Godot 4.7 `--check-only --script`.
- Tracked-file guard found no proprietary client assets, local reports, local runtime files, or logs in Git.
