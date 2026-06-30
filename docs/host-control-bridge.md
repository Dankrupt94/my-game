# Host Control Bridge

## Purpose

Snap Godot cannot currently see Docker from child processes. That blocks direct dashboard start/stop control for the AzerothCore stack because the existing stack scripts use Docker MySQL.

The host control bridge solves that by running outside Snap Godot and listening only on localhost.

## Files

```text
tools/host_control_bridge.py
tools/bridge_client.py
scripts/start_host_bridge.sh
scripts/stop_host_bridge.sh
```

Ignored local runtime files:

```text
local_runtime/host-bridge-token.txt
local_runtime/host-bridge.pid
local_runtime/host-bridge.log
local_runtime/database-transactions.log
```

## Security Model

- Binds only to `127.0.0.1`.
- Read-only health/status endpoints do not require a token.
- Start, stop, and client-launch endpoints require `X-Acore-Bridge-Token`.
- The token is generated locally and stored in ignored `local_runtime/`.
- Mutating bridge actions append JSONL entries to `local_runtime/database-transactions.log`.
- No proprietary files are served by the bridge.
- Godot does not run stack scripts, helper Python commands, or Wine directly. It calls the bridge over localhost HTTP.

## Endpoints

- `GET /health`
- `GET /status`
- `GET /data?view=summary&search=&limit=25`
- `POST /start`
- `POST /stop`
- `POST /client/launch`

`POST /start` and `POST /stop` call the existing AzerothCore scripts:

```text
/run/media/doodbro/New 1tb/AzerothCore/scripts/start.sh
/run/media/doodbro/New 1tb/AzerothCore/scripts/stop.sh
```

`POST /client/launch` attempts to launch the bundled local `Wow.exe` through Wine from the host bridge process. If Wine is missing, the endpoint fails safely and records that local failure in the mutation log.

## Error Codes

- `200 OK`: Endpoint completed successfully.
- `400 Bad Request`: Read-only data request used an unsupported view, too-long search text, or invalid limit.
- `401 Unauthorized`: Mutating endpoint was missing `X-Acore-Bridge-Token` or received the wrong token.
- `404 Not Found`: Endpoint or configured host script was missing.
- `500 Server Error`: Bridge-side helper command failed, timed out, or client launch could not start.

## Run

The normal companion launcher starts the bridge automatically:

```bash
scripts/run_game.sh
```

Manual start:

```bash
scripts/start_host_bridge.sh
```

The start script launches the bridge in a detached session and verifies `GET /health` before reporting success. This matters for desktop/Godot launches, where plain background jobs can be cleaned up when the parent script exits.

Stop:

```bash
scripts/stop_host_bridge.sh
```

To run the companion without starting the bridge:

```bash
ACORE_COMPANION_START_BRIDGE=0 scripts/run_game.sh
```

Health check:

```bash
python3 tools/bridge_client.py health
```

Status check:

```bash
python3 tools/bridge_client.py status --compact
```

Read-only data check:

```bash
python3 tools/bridge_client.py data --view summary --compact
```

Client-launch endpoint check:

```bash
python3 tools/bridge_client.py launch_client --compact
```

## Dashboard Boundary

The Godot dashboard uses native `HTTPRequest` calls to the bridge for stack status, read-only data, start, stop, restart, and client launch. The dashboard reads the ignored local token file at runtime for mutating requests, but it does not hardcode credentials or execute host scripts directly.

## Validation

Initial validation completed:

- `GET /health` returned success.
- `GET /status` returned success and did not start/stop services.
- `POST /start` without the local token returned `401`.
- The bridge was stopped after validation.

Dashboard integration validation completed:

- `tools/bridge_client.py health --compact` fails cleanly when the bridge is offline.
- `tools/bridge_client.py health --compact` succeeds when the bridge is online.
- `tools/bridge_client.py status --compact` succeeds and sees host-side Docker.
- Godot 4.7 loaded headlessly with the bridge online and refreshed status without starting the stack.
- The bridge was stopped after validation.

Live-stack validation completed after runtime data extraction:

- `scripts/start_host_bridge.sh` starts a durable bridge process and verifies health.
- `tools/bridge_client.py status --compact` sees MySQL `3306`, authserver `3724`, worldserver `8085`, Ollama `11434`, Docker, and runtime data ready.
- `tools/bridge_client.py start --compact` succeeds while the stack is already running and reports the existing live ports.
- Godot 4.7 loads the dashboard scene headlessly through `scripts/run_game.sh` with the bridge online.

Read-only data validation completed:

- `GET /data` runs `tools/read_only_data_browser.py`.
- `tools/bridge_client.py data --view summary --compact` returns live realm and data counts.
- `tools/bridge_client.py data --view items --search sword --limit 5 --compact` returns successfully.

Stage 04 bridge-boundary validation completed:

- `POST /client/launch` without the local token returns `401`.
- `POST /start` with an invalid token returns `401`.
- `tools/bridge_client.py start --compact --timeout 260` succeeds idempotently while the stack is already running and writes a mutation-log entry.
- `tools/bridge_client.py launch_client --compact --timeout 30` reaches the authorized endpoint and fails safely because Wine is not installed or visible.
- `local_runtime/database-transactions.log` is valid JSONL and has `0600` permissions.
- Godot 4.7 loads the dashboard scene headlessly after the dashboard moved to native bridge HTTP calls.
