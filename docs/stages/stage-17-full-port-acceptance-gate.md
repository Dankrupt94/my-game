# Stage 17 - Full Port Acceptance Gate

Status: Planned

## Goal

Verify that the Godot client is a fully functional WotLK port for AzerothCore, not a companion tool, not a reimagined game, and not a partial prototype.

## Acceptance Requirements

- Godot can authenticate, list realms, list characters, enter world, and maintain a live world session through the AzerothCore protocol.
- Godot can run normal player-facing gameplay without launching the original WotLK client.
- Movement, object visibility, targeting, combat, spells, auras, loot, inventory, equipment, quests, vendors, trainers, chat, groups, guilds, mail, auction house, maps/minimap, settings, and major UI flows are implemented or have explicit parity notes.
- Required local asset/data pipelines are documented and keep proprietary inputs and derived files local-only.
- Any behavior difference caused by Godot, Linux, local tooling, or AzerothCore is documented as a compatibility deviation.
- Major feature areas have regression tests or manual test checklists.

## Not Accepted

- A dashboard-only companion.
- A Godot sandbox that merely resembles WotLK.
- A client that still requires the original WotLK executable for normal play.
- A client that implements only login, movement, or a small subset of gameplay.
- A reimagined MMO that uses AzerothCore data but does not aim for WotLK client parity.

## Done Criteria

- The user can use Godot as the player-facing client for normal AzerothCore WotLK play.
- Remaining deviations are documented, justified, and tracked.
- The original client is no longer needed for ordinary runtime play, only for comparison or validation.

## Documentation To Update During Work

- Full feature checklist.
- Parity matrix.
- Known deviations.
- Manual test scripts.
- Local asset/data pipeline notes.
- Performance and stability notes.
