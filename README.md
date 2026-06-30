# AzerothCore Godot Companion

This is the Godot-side companion workspace for the local AzerothCore setup. The previous RPG prototype has been retired and removed from this repo.

## Current Purpose

- Keep a Godot 4.7 project beside the local AzerothCore bundle.
- Track local server, build, and client paths in one place.
- Use the desktop-style companion dashboard as bootstrap tooling for status checks, safe start/stop helpers, account setup, client launching, and diagnostics.
- Build toward a fully functional Godot-native WotLK client/port that can replace the original WotLK client for normal AzerothCore play.
- Treat any original sandbox or companion-only work as scaffolding, not as the final product.
- Use local proprietary client files only for the authorized on-machine prototype. Keep those files out of Git and GitHub.

## Local Project Location

```text
/run/media/doodbro/New 1tb/AzerothCore/godot-azerothcore-companion
```

Related paths are tracked in [docs/location-notes.md](docs/location-notes.md).

The long-term plan for building Godot toward the game-engine/client role is tracked in [docs/godot-as-engine-roadmap.md](docs/godot-as-engine-roadmap.md).

The master plan for the Godot-AzerothCore-WotLK direction is tracked in [docs/godot-azerothcore-wotlk-master-plan.md](docs/godot-azerothcore-wotlk-master-plan.md).

Local AI resources, including `qwen2.5-coder:7b`, are documented in [docs/local-ai-resources.md](docs/local-ai-resources.md).

The local Blizzard/WotLK file authorization and autonomous-work directive is documented in [docs/local-blizzard-file-authorization.md](docs/local-blizzard-file-authorization.md).

Local proprietary client asset handling is documented in [docs/asset-handling-policy.md](docs/asset-handling-policy.md). Short version: this prototype may use local proprietary files on this machine under the project owner's authorization, but those files must stay untracked and must not be pushed to GitHub.

Local helper tools for audits and metadata-only client scanning live in [tools](tools/).

The latest safe summary of those local audits is tracked in [docs/toolchain-and-client-audit-summary.md](docs/toolchain-and-client-audit-summary.md).

Server stack discovery is tracked in [docs/server-stack-discovery-summary.md](docs/server-stack-discovery-summary.md).

The localhost bridge for host-side start/stop/status control is documented in [docs/host-control-bridge.md](docs/host-control-bridge.md).

The original Godot gameplay sandbox is documented in [docs/gameplay-sandbox.md](docs/gameplay-sandbox.md).

The Godot-native multiplayer sandbox is documented in [docs/multiplayer-sandbox.md](docs/multiplayer-sandbox.md).

## How To Open

Use the desktop shortcut named `Open AzerothCore Companion in Godot`, or open this project folder in Godot 4.7.

To run the shell directly, use `Run AzerothCore Companion`.

## GitHub Push Shortcut

Use the desktop shortcut named `Push AzerothCore Companion to GitHub` to push saved local commits to:

https://github.com/Dankrupt94/my-game

The shortcut only pushes commits that already exist. It does not automatically save unfinished file changes, so ask Codex to commit your work before using it.
