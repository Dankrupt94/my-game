# Stage 06 - Data-Driven Sandbox

Status: Complete

## Goal

Make the Godot sandbox consume AzerothCore-shaped data through the bridge.

## Deliverables

- Load selected character records into Godot UI.
- Load creature template names/stats as placeholder enemies.
- Load quest text/objectives as UI data.
- Load item names/basic metadata as inventory placeholders.
- Spawn original placeholder objects based on database records.

## Entry Criteria

- Stage 05 gameplay sandbox exists.
- Stage 04 bridge can expose safe read-only data.

## Stage Start Notes

- Stage 06 begins after the playable original sandbox and hardened bridge boundary.
- Data access must remain read-only through `GET /data`.
- AzerothCore records can influence placeholder labels, UI rows, and spawned primitive placeholders, but no proprietary assets or copied client UI should be introduced.
- The first slice should stay small and testable: load a few characters, creatures, quests, and items, then prove the sandbox can spawn original placeholder objects from those records.

## Done Criteria

- [x] Godot can display and spawn placeholder gameplay objects based on real AzerothCore records.
- [x] All data access is read-only unless a later stage explicitly allows writes.

## Implementation Notes

- `scripts/gameplay_sandbox.gd` now calls the bridge `GET /data` endpoint directly through Godot `HTTPRequest`.
- The sandbox requests small read-only slices:
  - `characters` with limit `3`,
  - `creatures` with search `wolf` and limit `3`,
  - `quests` with search `wolf` and limit `3`,
  - `items` with search `sword` and limit `3`.
- Returned character, quest, and item records are rendered into sandbox UI text.
- Returned creature records spawn original capsule placeholders under `AzerothCoreDataPlaceholders`.
- Spawned placeholders store source entry/level metadata on the Godot node but do not write anything back to AzerothCore.
- The host bridge now parses the data browser's stdout report for each `/data` request instead of reading the shared local report file. This prevents concurrent data requests from racing against one another.
- Added `ACORE_SANDBOX_DATA_SELF_TEST=1` to prove records load and creature placeholders are spawned.

## Mapping Rules

- Character rows map to display-only UI summaries using `name`.
- Creature rows map to original capsule placeholders using `name`, `entry`, `minlevel`, and `maxlevel`.
- Quest rows map to display-only UI summaries using `title`.
- Item rows map to display-only inventory placeholder summaries using `name`.
- No icons, models, textures, maps, or proprietary client assets are consumed in this stage.

## Known Missing Fields

- Creature position is not from AzerothCore spawn tables yet; Stage 06 uses fixed local sandbox positions.
- Item icons are not loaded yet; item rows are text placeholders only.
- Quest objectives are not parsed beyond title/level metadata.
- Character race/class IDs are not converted into friendly labels yet.

## Validation

Completed on 2026-06-30:

- Parallel `GET /data` checks for characters, creatures, quests, and items each returned the correct per-request rows after the bridge race fix.
- `ACORE_SANDBOX_DATA_SELF_TEST=1 snap run godot-4 --headless --quit-after 600 --path ".../godot-azerothcore-companion" --scene res://scenes/gameplay_sandbox.tscn` printed `SANDBOX_DATA_SELF_TEST_OK`.
- `ACORE_SANDBOX_SELF_TEST=1 snap run godot-4 --headless --quit-after 5 --path ".../godot-azerothcore-companion" --scene res://scenes/gameplay_sandbox.tscn` still printed `SANDBOX_SELF_TEST_OK`.

## Documentation To Update During Work

- [x] Bridge endpoints used.
- [x] Data models consumed by Godot.
- [x] Mapping rules from AzerothCore data to Godot placeholders.
- [x] Known missing fields.
