# Stage 04 - Local Bridge Service

Status: Complete

## Goal

Establish the host control bridge as the formal, isolated security boundary separating the Godot client/dashboard runtime from Docker commands, raw system shell scripts, and low-level MySQL transactions.

## Deliverables

- **Idempotent Python Service:** A robust, multi-threaded localhost service listening on port `8765`.
- **JSON API Endpoints:**
  - `GET /health`: Health status.
  - `GET /status`: Run Stack and Database audits. Returns ports, container statuses, missing files, and data checks.
  - `GET /data`: Executes sanitized SELECT queries against world/auth/characters DBs (Stage 3).
  - `POST /start`: Triggers host system start scripts (token required).
  - `POST /stop`: Triggers host system stop scripts (token required).
  - `POST /client/launch`: Launches `Wow.exe` via Wine in a host process (token required).
- **Security Logs:** Create `local_runtime/database-transactions.log` to track any server state changes.

## Security Constraints

- **Strict Sandbox Containment:** The bridge must bind exclusively to `127.0.0.1`.
- **Token Verification:** Every mutating endpoint (`POST /start`, `/stop`, `/client/launch`) validates the `X-Acore-Bridge-Token` header.
- **Durable File Tokens:** The token is read from `local_runtime/host-bridge-token.txt`, generated at bridge startup if missing, set with read-only host owner permissions (`0600`), and kept completely untracked in Git.
- **Zero Credentials in Godot:** The Godot scene/engine holds zero MySQL usernames, passwords, or shell path configurations. It interacts only with `http://127.0.0.1:8765/`.

## Entry Criteria

- Stage 03 read-only browser panels successfully retrieve and display data via HTTP.

## Stage Start Notes

- Stage 04 began after the completed Stage 03 read-only data browser.
- The bridge already has health, status, data, start, and stop routes.
- Remaining hardening work is to add the client launch route, structured mutation logging, bridge-side security metadata, and remove direct dashboard fallbacks to host shell/client execution.
- Godot should use the localhost bridge as the single boundary for dashboard actions. If the bridge is offline, the dashboard should explain that the bridge must be started rather than falling back to raw scripts.

## Implementation Notes

- `tools/host_control_bridge.py` now exposes `POST /client/launch` behind the same local token gate used by `POST /start` and `POST /stop`.
- Mutating bridge requests write JSONL audit entries to ignored `local_runtime/database-transactions.log` with owner-only `0600` permissions.
- `GET /health` now reports bridge security metadata, including localhost bind host, mutating endpoint names, and transaction log path. It does not expose the token.
- `tools/bridge_client.py` now supports `launch_client` for endpoint testing.
- `scripts/companion_dashboard.gd` now uses Godot `HTTPRequest` calls to `http://127.0.0.1:8765` for status, data, start, stop, restart, and client launch.
- The dashboard no longer has direct `OS.execute` or `OS.create_process` paths for stack scripts, Python helper execution, or Wine client launch.
- Godot reads the ignored local bridge token at runtime for mutating requests. The token is not hardcoded into the scene or committed.

## Done Criteria

- [x] Godot contains no direct scripting references to system shells (`OS.execute` for system commands) or direct MySQL adapters.
- [x] All stack/data/client-launch dashboard inputs communicate over HTTP localhost loopback.
- [x] The host control bridge intercepts, logs, and safely processes all mutative commands.

## Validation

Completed on 2026-06-30:

- Python compile check passed for `tools/host_control_bridge.py` and `tools/bridge_client.py`.
- New host bridge process started successfully after stopping the older Stage 03 process.
- `tools/bridge_client.py health --compact` returned success.
- `tools/bridge_client.py status --compact --timeout 35` returned live MySQL, authserver, worldserver, and Ollama status.
- `tools/bridge_client.py data --view summary --compact --timeout 35` returned real realm/count data.
- `POST /client/launch` without a token returned `401 Unauthorized`.
- `POST /start` with an invalid token returned `401 Unauthorized`.
- `tools/bridge_client.py start --compact --timeout 260` succeeded while the stack was already running and wrote a local mutation-log entry.
- `tools/bridge_client.py launch_client --compact --timeout 30` reached the authorized endpoint and failed safely because Wine is not installed or visible. This did not launch the client and wrote a local mutation-log entry.
- `local_runtime/database-transactions.log` is valid JSONL, has timestamps, and is `0600`.
- Godot 4.7 launched the dashboard headlessly through `scripts/run_game.sh` with exit code `0`.
- A local `qwen-agent:latest` advisory review found no serious issue and suggested the token/log validation checks above.

## Documentation To Update During Work

- [x] Bridge endpoint definitions and JSON schema specifications.
- [x] Error codes mapping (`401 Unauthorized`, `400 Bad Request`, `500 Server Error`).
- [x] Local security policy overview.
