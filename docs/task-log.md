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

- Added `project.godot` with `scenes/main.tscn` as the main scene.
- Added a generated 3D snowy training yard called Frostbound Yard.
- Added third-person movement, mouse camera, jumping, target selection, and three hotbar actions.
- Added Scout Mira, a quest giver with a simple accept/complete quest loop.
- Added a Frostbound Training Dummy with health, damage, and defeated state.
- Added an MMO-style HUD with player bars, target frame, quest tracker, prompt text, and hotbar buttons.
- Added beginner controls in `docs/controls.md`.
