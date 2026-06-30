# Stage 04 - Local Bridge Service

Status: Planned

## Goal

Create a local service that becomes the safe boundary between Godot, AzerothCore scripts, and the database.

## Deliverables

- Localhost bridge process.
- JSON API.
- Read-only endpoints first.
- Script-control endpoints for server/client actions.
- Logging for every write/control action.

## Initial Endpoints

- `GET /status`
- `GET /paths`
- `GET /accounts`
- `GET /characters`
- `GET /character/{guid}`
- `GET /creature-templates?search=`
- `GET /quest-templates?search=`
- `POST /server/start`
- `POST /server/stop`
- `POST /client/launch`

## Entry Criteria

- Stage 03 proves what data Godot needs.

## Done Criteria

- Godot talks to the bridge over localhost.
- Bridge handles command execution and database reads.
- Godot no longer needs to know low-level script/database details.

## Documentation To Update During Work

- Endpoint list.
- Request/response examples.
- Error responses.
- Security/secrets handling notes.

