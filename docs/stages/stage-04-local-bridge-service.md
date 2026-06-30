# Stage 04 - Local Bridge Service

Status: Planned

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

## Done Criteria

- Godot contains no direct scripting references to system shells (`OS.execute` for system commands) or direct MySQL adapters.
- All dashboard inputs communicate exclusively over HTTP localhost loopback.
- The host control bridge intercepts, logs, and safely processes all mutative commands.

## Documentation To Update During Work

- Bridge endpoint definitions and JSON schema specifications.
- Error codes mapping (`401 Unauthorized`, `400 Bad Request`, `500 Server Error`).
- Local security policy overview.
