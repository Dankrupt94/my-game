# Frostbound Prototype

Frostbound Prototype is a Godot 4 third-person fantasy RPG prototype inspired by classic snowy-zone MMORPG gameplay. It uses original placeholder content and does not depend on any proprietary game client files.

## First Playtest Goal

Open the project in Godot 4, run the main scene, walk around the snowy test yard, talk to the quest NPC, and attack the training dummy from the hotbar.

## What Exists Now

- A Godot 4 project with `main.tscn` as the main scene.
- A small original snowy training yard called Frostbound Yard.
- A third-person player with mouse camera, movement, and jump.
- Scout Mira, an original quest NPC.
- A Frostbound Training Dummy with health and defeat logic.
- A simple MMO-style HUD with player bars, target frame, quest tracker, prompt text, and hotbar buttons.

## How To Play

The easiest way is to double-click the desktop shortcut named `Run Frostbound Prototype`.

You can also open this folder in Godot 4.7 and press Play.

Once the game starts:

1. Walk to Scout Mira and press `E`.
2. Press `Tab` to target the dummy.
3. Use `1` and `2` to attack.
4. Return to Scout Mira and press `E` to complete the quest.

If Godot asks to convert or update the project to Godot 4.7, allow it. This prototype uses simple Godot 4 features, so that update is expected.

Controls are also listed in [docs/controls.md](docs/controls.md).

If Godot opens to a plain brown/gray 3D view with axes, that is the editor viewport. Use the `Run Frostbound Prototype` desktop shortcut to launch the actual game view directly. More help is in [docs/godot-troubleshooting.md](docs/godot-troubleshooting.md).

If a desktop shortcut closes right away, open `logs/godot-launch.log` in this project folder. The launcher writes the exact Godot command and any error there.

Godot is installed as a Snap app on this machine. Because the project is on an external drive, Godot needs the Snap `removable-media` permission. That permission has been enabled.

## GitHub Push Shortcut

A desktop shortcut named `Push My Game to GitHub` has been created. Double-click it to push saved local commits to the private GitHub repository at:

https://github.com/Dankrupt94/my-game

The shortcut only pushes commits that already exist. It does not automatically save unfinished file changes, so ask Codex to commit your work before using it.
