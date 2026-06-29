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
