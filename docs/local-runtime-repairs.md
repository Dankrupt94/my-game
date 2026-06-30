# Local Runtime Repairs

## Purpose

This document records local AzerothCore runtime repairs made while bringing the Godot companion toward a runnable local stack.

These changes were applied outside this Git repository under `/run/media/doodbro/New 1tb/AzerothCore`. They are documented here so future sessions do not rediscover the same blockers.

## 2026-06-30 Checkpoint

### Server Binaries

- Built `worldserver` in `/home/doodbro/azeroth-build`.
- Installed Linux server binaries into `/run/media/doodbro/New 1tb/AzerothCore/run/bin`.
- Verified both installed binaries exist:
  - `/run/media/doodbro/New 1tb/AzerothCore/run/bin/authserver`
  - `/run/media/doodbro/New 1tb/AzerothCore/run/bin/worldserver`

### MySQL Container Startup

The local MySQL data directory was already populated, but the Linux Docker startup needed compatibility fixes.

Applied to `/run/media/doodbro/New 1tb/AzerothCore/scripts/start.sh`:

- Run MySQL with host networking, bound to `127.0.0.1`, so AzerothCore can use the existing `127.0.0.1` config safely.
- Start MySQL with `--lower-case-table-names=1` because the data dictionary was created with that setting.
- Replace the removed MySQL 8.4 option `--default-authentication-plugin=mysql_native_password` with `--mysql-native-password=ON`.
- Wait for the container log to report `ready for connections` before starting authserver/worldserver.

### MySQL Data Metadata

The existing `binlog.index` used Windows-style paths that Linux MySQL treated as literal filenames.

Applied locally:

- Backed up `binlog.index` to `binlog.index.codex-backup-20260630T1859Z`.
- Normalized the active `binlog.index` entries from Windows-style separators to Linux-style relative paths.
- Started a temporary repair-mode MySQL container to add a Docker-friendly `acore` host grant using the already configured password, without printing the password.

### Config Path Repair

Authserver still referenced a Windows source path.

Updated these local config files to use `/run/media/doodbro/New 1tb/AzerothCore/source`:

- `/run/media/doodbro/New 1tb/AzerothCore/configs/authserver.conf`
- `/run/media/doodbro/New 1tb/AzerothCore/run/etc/authserver.conf`
- `/run/media/doodbro/New 1tb/AzerothCore/run/bin/authserver.conf`

## Verified Result

- MySQL listens on `127.0.0.1:3306`.
- The database audit can reach all configured databases:
  - `acore_auth`
  - `acore_world`
  - `acore_characters`
- Authserver can connect to the auth database and start its realm setup.
- Worldserver can connect to auth, characters, world, and playerbots databases and run database updates.

### Runtime Data Extraction

The missing runtime-data blocker has been cleared.

Generated local-only AzerothCore runtime data from the authorized bundle client and moved the required outputs into `/run/media/doodbro/New 1tb/AzerothCore/data`:

- `dbc`: 246 `.dbc` files.
- `maps`: 5744 `.map` files.
- `vmaps`: 101 `.vmtree` files and 2693 `.vmtile` files.
- `mmaps`: 98 `.mmap` files and 3682 `.mmtile` files.

Removed the temporary extractor scratch folder `/run/media/doodbro/New 1tb/AzerothCore/client/Buildings` after VMap/MMap verification.

### Startup Script Repair

Applied to `/run/media/doodbro/New 1tb/AzerothCore/scripts/start.sh`:

- Replaced the old hardcoded `maps/0000.map` readiness check with real file-count checks for maps, DBC, VMap, and MMap files.
- Started authserver, worldserver, and the LLM bridge through a detached session so they survive desktop/script launch cleanup.
- Redirected detached server stdin from `/dev/null`.
- Disabled `Console.Enable` in the copied runtime `worldserver.conf` files for background launches so worldserver does not shut down when console input closes.

## Verified Result After Runtime Data Repair

- MySQL listens on `127.0.0.1:3306`.
- Authserver listens on `0.0.0.0:3724`.
- Worldserver listens on `0.0.0.0:8085`.
- Ollama listens on `127.0.0.1:11434`.
- The LLM bridge process is running.
- Worldserver logged `WORLD: World Initialized In 1 Minutes 1 Seconds` and `worldserver-daemon ready`.

Keep any runtime data population local-only and out of Git.
