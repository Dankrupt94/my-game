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

## Current Blocker

Worldserver stops at local runtime data loading because `/run/media/doodbro/New 1tb/AzerothCore/data` does not contain the required map/DBC/VMap/MMap data.

Current audit result:

- `data/maps`: missing
- `data/maps/0000.map`: missing
- `data/dbc`: missing
- `data/vmaps`: missing
- `data/mmaps`: missing

Keep any runtime data population local-only and out of Git.
