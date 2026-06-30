# Stage 03 - Read-Only Data Browser

Status: Complete

## Goal

Provide a structured, search-enabled interface inside the Godot dashboard to inspect the local AzerothCore server database (accounts, characters, online statuses, and world database templates) safely using the localhost bridge's read-only data endpoints.

## Deliverables

- **Realmlist Panel:** Display ID, name, IP address, port, gamebuild, and population status.
- **Accounts Panel:** Grid display of ID, username, online status, expansion build, locale, OS, and accumulated play time.
- **Characters Grid:** List GUID, account ID, name, race, class, gender, level, online status, and zone, with a toggle to filter for **online players only**.
- **Template Search Panels:** Tabbed views equipped with text search inputs to filter:
  - **Creature Templates:** Search by entry, name, subname, levels, and rank.
  - **Item Templates:** Search by name, quality, class, item level, and required level.
  - **Quest Templates:** Search by title, quest level, minimum level, and quest type.
  - **Spell Metadata:** Search by name, subtext/rank, and levels.
- **UI Grid Controls:** Implement paginated limits (25, 50, 100 rows) and simple text filter queries.

## Entry Criteria

- Stage 02 command layer complete.
- MySQL access strategy chosen (delegating database queries to the host control bridge's `/data` endpoint).

## Done Criteria

- Godot requests read-only data through `tools/bridge_client.py`, which calls HTTP `GET` queries to `127.0.0.1:8765/data?view={view}&search={search}&limit={limit}`.
- JSON responses are correctly parsed and displayed in Godot.
- The UI restricts inputs to read-only fields (GET requests only; no DB write interfaces exist).

## Hardened Security Guidelines

- **Database Separation:** The Godot UI must never instantiate a direct connection to the SQL server or hold login credentials.
- **Query Containment:** All query string parameters must be sanitized on the host bridge to prevent SQL injection before passing them to the database.

## Documentation To Update During Work

- List of tables/views queried by the bridge.
- Network response structures and fields mapped in Godot.
- UI screenshot of the database browser panels, when visual capture is available.

## Completion Notes

- Added `tools/read_only_data_browser.py`.
- Added bridge endpoint `GET /data`.
- Added bridge client action `data`.
- Added dashboard `Read-Only Data Browser` controls for view, search, and row limit.
- Added dashboard result display for `summary`, `accounts`, `characters`, `online`, `creatures`, `items`, `quests`, and `spells`.
- Added dashboard `Data Snapshot` counts for realm, accounts, characters, online characters, creature templates, item templates, quest templates, and spell rows.
- Documented tables and fields in [../read-only-data-browser.md](../read-only-data-browser.md).
- Validated direct and bridge data views against the live local stack.
- Validated Godot 4.7 loads the dashboard scene headlessly with the read-only browser present.
- No visual screenshot was captured in this checkpoint; validation was headless.

## Final Stage 03 State

The stage is complete as a read-only browser, not an editor. No Godot code holds database credentials, and no write endpoint was added.
