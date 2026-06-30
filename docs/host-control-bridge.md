# Host Control Bridge

## Purpose

Snap Godot cannot currently see Docker from child processes. That blocks direct dashboard start/stop control for the AzerothCore stack because the existing stack scripts use Docker MySQL.

The host control bridge solves that by running outside Snap Godot and listening only on localhost.

## Files

```text
tools/host_control_bridge.py
scripts/start_host_bridge.sh
scripts/stop_host_bridge.sh
```

Ignored local runtime files:

```text
local_runtime/host-bridge-token.txt
local_runtime/host-bridge.pid
local_runtime/host-bridge.log
```

## Security Model

- Binds only to `127.0.0.1`.
- Read-only health/status endpoints do not require a token.
- Start/stop endpoints require `X-Acore-Bridge-Token`.
- The token is generated locally and stored in ignored `local_runtime/`.
- No proprietary files are served by the bridge.

## Endpoints

- `GET /health`
- `GET /status`
- `POST /start`
- `POST /stop`

`POST /start` and `POST /stop` call the existing AzerothCore scripts:

```text
/run/media/doodbro/New 1tb/AzerothCore/scripts/start.sh
/run/media/doodbro/New 1tb/AzerothCore/scripts/stop.sh
```

## Run

Start:

```bash
scripts/start_host_bridge.sh
```

Stop:

```bash
scripts/stop_host_bridge.sh
```

Health check:

```bash
curl http://127.0.0.1:8765/health
```

## Next Dashboard Work

The Godot dashboard should use this bridge for status/start/stop when it is reachable. Direct start/stop from Snap Godot should remain guarded.

## Validation

Initial validation completed:

- `GET /health` returned success.
- `GET /status` returned success and did not start/stop services.
- `POST /start` without the local token returned `401`.
- The bridge was stopped after validation.
