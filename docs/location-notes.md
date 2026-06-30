# Project Location Notes

## Current Home

```text
/run/media/doodbro/New 1tb/AzerothCore/godot-azerothcore-companion
```

This Godot project belongs beside the local AzerothCore bundle as a companion workspace.

It should stay separate from:

- `source/`, which is the AzerothCore C++ source repo.
- `client/`, which is a local WotLK client copy.
- `run/`, which is the Linux server install/run output.
- `data/`, which is for server data files such as maps.
- `build/` and `/home/doodbro/azeroth-build`, which are generated build folders.

## Related Local Paths

```text
AzerothCore bundle: /run/media/doodbro/New 1tb/AzerothCore
AzerothCore source: /run/media/doodbro/New 1tb/AzerothCore/source
AzerothCore build:  /home/doodbro/azeroth-build
AzerothCore run:    /run/media/doodbro/New 1tb/AzerothCore/run
WotLK client:       /run/media/doodbro/5e07d7d7-039f-43a8-94da-999f100ab1fb/World of Warcraft - WoTLK
Bundle client copy: /run/media/doodbro/New 1tb/AzerothCore/client
```

## AzerothCore Notes

- The active source checkout is on branch `Playerbot`.
- The source repo has local modified files; do not revert them unless explicitly requested.
- `/home/doodbro/azeroth-build` is the Linux CMake build directory, not a separate source repo.
- `/run/media/doodbro/New 1tb/AzerothCore/run` is the intended Linux install/run directory.
- The WotLK client realmlist found at `Data/enGB/realmlist.wtf` points to `127.0.0.1`.

## Retired Work

The previous RPG prototype was retired on 2026-06-30. Its gameplay scripts, old controls doc, old scene copy, and old desktop shortcuts were removed from this repo.
