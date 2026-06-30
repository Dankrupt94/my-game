# AzerothCore Godot Companion

This is the Godot-side companion workspace for the local AzerothCore setup. The previous RPG prototype has been retired and removed from this repo.

## Current Purpose

- Keep a Godot 4.7 project beside the local AzerothCore bundle.
- Track local server, build, and client paths in one place.
- Grow into a desktop-style companion for status checks, safe start/stop helpers, account setup, client launching, and diagnostics.
- Use local proprietary client files only for the authorized on-machine prototype. Keep those files out of Git and GitHub.

## Local Project Location

```text
/run/media/doodbro/New 1tb/AzerothCore/godot-azerothcore-companion
```

Related paths are tracked in [docs/location-notes.md](docs/location-notes.md).

The long-term plan for building Godot toward the game-engine/client role is tracked in [docs/godot-as-engine-roadmap.md](docs/godot-as-engine-roadmap.md).

The master plan for the Godot-AzerothCore-WotLK direction is tracked in [docs/godot-azerothcore-wotlk-master-plan.md](docs/godot-azerothcore-wotlk-master-plan.md).

Local AI resources, including `qwen2.5-coder:7b`, are documented in [docs/local-ai-resources.md](docs/local-ai-resources.md).

Local proprietary client asset handling is documented in [docs/asset-handling-policy.md](docs/asset-handling-policy.md). Short version: this prototype may use local proprietary files on this machine under the project owner's authorization, but those files must stay untracked and must not be pushed to GitHub.

## How To Open

Use the desktop shortcut named `Open AzerothCore Companion in Godot`, or open this project folder in Godot 4.7.

To run the shell directly, use `Run AzerothCore Companion`.

## GitHub Push Shortcut

Use the desktop shortcut named `Push AzerothCore Companion to GitHub` to push saved local commits to:

https://github.com/Dankrupt94/my-game

The shortcut only pushes commits that already exist. It does not automatically save unfinished file changes, so ask Codex to commit your work before using it.
