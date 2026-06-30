# Task Log

## 2026-06-29 - GitHub Push Shortcut

Goal: create a beginner-friendly desktop shortcut that pushes any local commits that have not been sent to the private GitHub repository yet.

Plan:

- Add a reusable script inside the project.
- Make the script detect whether the GitHub remote is set.
- If no remote exists, add the provided private GitHub repo URL.
- Add a desktop launcher so pushing can be done by double-clicking.
- Commit the finished shortcut work locally.

Result:

- Set the GitHub remote to `https://github.com/Dankrupt94/my-game.git`.
- Added `scripts/push_unpushed_commits.sh`.
- Added a reusable `push-to-github.desktop` launcher file inside the repo.
- Installed an executable desktop shortcut at `/home/doodbro/Desktop/Push My Game to GitHub.desktop`.

## 2026-06-29 - First Godot Prototype

Goal: create the first playable Godot 4 prototype milestone using original placeholder content.

Result:

- Added `project.godot` with `main.tscn` as the main scene.
- Added a generated 3D snowy training yard called Frostbound Yard.
- Added third-person movement, mouse camera, jumping, target selection, and three hotbar actions.
- Added Scout Mira, a quest giver with a simple accept/complete quest loop.
- Added a Frostbound Training Dummy with health, damage, and defeated state.
- Added an MMO-style HUD with player bars, target frame, quest tracker, prompt text, and hotbar buttons.
- Added beginner controls in `docs/controls.md`.

Fix:

- Added a root-level `main.tscn` and pointed `project.godot` to it so Godot 4.7 has the simplest possible launch path.
- Simplified the generated scene files to avoid handmade UID/resource ID parsing issues.
- Added desktop shortcuts to run the game directly and open the editor directly.
- Added `docs/godot-troubleshooting.md` for the `main.tscm`/stale scene path issue.

## 2026-06-29 - Desktop Launcher Crash Fix

Goal: make the desktop launchers visible and diagnosable instead of closing instantly.

Plan:

- Save a before-fix checkpoint.
- Add launcher logging.
- Keep launcher windows open when Godot exits with an error.
- Avoid fragile desktop `Exec` paths that contain spaces.
- Push the finished fix to GitHub.

Result:

- Updated the run and editor scripts to write `logs/godot-launch.log`.
- Updated desktop shortcuts to open in a terminal.
- Added no-spaces wrapper scripts on the Desktop so launchers do not depend on escaping the project path.

## 2026-06-29 - Godot Snap External Drive Fix

Problem: Godot launched the project through `/run/user/1000/doc/...` and failed to create `res://.godot`, causing `res://main.tscn` to appear missing.

Cause: the Snap package for Godot did not have permission to access external/removable media paths.

Fix:

- Connected `godot-4:removable-media` to `:removable-media`.
- Verified the real non-headless launch command can open `res://main.tscn` from the external drive.

## 2026-06-30 - Relocate Godot Prototype Into AzerothCore Bundle

Goal: move the Godot prototype out of the SSD trash and into the local AzerothCore bundle where it is easier to find and manage.

Plan:

- Save this pre-move note as a before-task commit.
- Move the project to `/run/media/doodbro/New 1tb/AzerothCore/godot-frostbound-prototype`.
- Update desktop shortcuts and scripts that contain the old path.
- Verify Godot can still launch the scene.
- Commit and push the completed move.

Result:

- Moved the project from the SSD trash to `/run/media/doodbro/New 1tb/AzerothCore/godot-frostbound-prototype`.
- Updated project `.desktop` files and Desktop launchers to the new path.
- Preserved the existing Git repo and GitHub remote.
- Documented the local AzerothCore, build, and WotLK client paths in `docs/location-notes.md`.

## 2026-06-30 - Retire Frostbound Prototype

Goal: abandon the Frostbound prototype and rename this Godot repo for the local AzerothCore companion project.

Plan:

- Save this pre-change note as a before-task commit.
- Rename the folder to `/run/media/doodbro/New 1tb/AzerothCore/godot-azerothcore-companion`.
- Delete Frostbound-specific gameplay scenes/scripts/docs.
- Replace the Godot project shell with an AzerothCore companion placeholder.
- Update desktop shortcuts, launcher names, and documentation.
- Verify the new Godot shell opens.
- Commit and push the completed rename/reset.
