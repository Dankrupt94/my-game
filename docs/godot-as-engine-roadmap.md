# Godot As The Game Engine Roadmap

## North Star

Turn Godot into the full player-facing WotLK client/engine layer for the local AzerothCore setup.

The final goal is not a companion app, not a reimagined AzerothCore-inspired game, and not a workflow that still depends on launching the original WotLK client. The final goal is a fully functional Godot-native WotLK client/port that can replace the original client for normal play against AzerothCore.

That does not mean replacing the WotLK client immediately. It means building Godot in layers until it can move from companion tool, to playable sandbox, to server-connected prototype, to a custom AzerothCore-compatible WotLK client.

Some features may need technical adaptation for Godot, Linux, or AzerothCore. Those adaptations are allowed only when documented as compatibility deviations; they are not permission to change the identity of the port.

## Ground Rules

- Do not copy client assets into this repo.
- Use original placeholder assets for Godot gameplay work.
- Keep AzerothCore source, build output, client files, and this Godot project separate.
- Treat the WotLK client as a reference, local input source, and validation target, not as the final runtime.
- Treat companion/dashboard work as scaffolding only.
- Treat Path A sandbox work as risk-reduction only; it cannot become the final product unless the user explicitly changes the mission.
- Commit and push before and after meaningful roadmap/code/document work.

## Stage 0 - Project Hygiene

Goal: keep the foundation easy to work with.

Deliverables:

- Clean project name: `AzerothCore Godot Companion`.
- Current local paths documented.
- Desktop shortcuts kept up to date.
- Godot launch verified after path changes.
- No retired prototype gameplay files in active project.

Done when:

- The project opens in Godot 4.7.
- The dashboard shell runs.
- The repo is clean and pushed.

## Stage 1 - Useful Companion Dashboard

Goal: make Godot useful before it becomes a game client.

Build:

- Server status panel.
- Start AzerothCore button.
- Stop AzerothCore button.
- Restart AzerothCore button.
- Open logs button.
- Launch WotLK client button.
- Show configured paths.
- Show MySQL, authserver, worldserver, Ollama, and bridge status.

Implementation approach:

- Godot calls local helper scripts through `OS.create_process`.
- Existing scripts in `/run/media/doodbro/New 1tb/AzerothCore/scripts` remain the source of truth.
- Godot reads logs but does not directly mutate configs yet.

Done when:

- A beginner can start, stop, inspect, and launch the local setup from Godot.

## Stage 2 - Safe Local Command Layer

Goal: stop putting shell behavior directly inside UI buttons.

Build:

- A small command wrapper API inside the Godot project.
- One place that knows where scripts live.
- One place that captures command output, exit codes, and logs.
- Friendly error messages for missing Docker, missing binaries, missing maps, or stopped MySQL.

Commands:

- `status`
- `start`
- `stop`
- `open_world_log`
- `open_auth_log`
- `launch_client`
- `open_project_folder`

Done when:

- Buttons call named actions instead of hand-built shell strings.
- Every action reports success/failure visibly.

## Stage 3 - Read-Only AzerothCore Database Browser

Goal: let Godot understand the server world without controlling it yet.

Build read-only views for:

- Realmlist
- Accounts
- Characters
- Online characters
- Character position
- Creature templates
- Game object templates
- Quest templates
- Item templates
- Spell names/basic metadata
- Module config summaries

Implementation approach:

- Prefer a small local bridge service over direct database access from Godot.
- Bridge reads MySQL and returns JSON.
- Godot displays JSON as simple tables/cards.

Done when:

- Godot can show actual AzerothCore data without editing it.

## Stage 4 - Local Bridge Service

Goal: create a clean boundary between Godot and AzerothCore.

Build a local bridge process with endpoints like:

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

Rules:

- Start with read-only endpoints.
- Add write endpoints slowly.
- Log every write action.
- Do not store secrets in Godot scenes.

Done when:

- Godot talks to the bridge over localhost.
- The bridge becomes the only thing touching scripts/database directly.

## Stage 5 - Original Godot Gameplay Sandbox

Goal: rebuild a small playable game scene, but aligned with the companion project.

Build:

- Third-person player movement.
- Camera.
- Collision.
- Targeting.
- One original test NPC.
- One original test enemy.
- Basic ability bar.
- Health/resource UI.
- Basic quest or task loop.

Rules:

- Use original placeholders only.
- Keep gameplay code modular.
- Do not bring back retired prototype branding/content.

Done when:

- Godot has a tiny playable RPG sandbox again, now under the AzerothCore companion direction.

## Stage 6 - Data-Driven Sandbox

Goal: make the sandbox consume AzerothCore-shaped data.

Build:

- Load character names/classes from bridge data.
- Load creature names/stats from template data.
- Load item names/icons as placeholder UI data.
- Load quest text/objectives.
- Spawn placeholder creatures based on selected database entries.

Important:

- This is not full AzerothCore simulation yet.
- Godot is learning to render and interact with server-shaped data.

Done when:

- Selecting a creature/quest/item in the dashboard can spawn or display it in the sandbox.

## Stage 7 - Godot-Native Multiplayer Prototype

Goal: prove Godot can be a game engine with live multiplayer behavior.

Build:

- Local Godot server mode.
- Two Godot clients on localhost.
- Player spawn.
- Position sync.
- Basic animation state sync.
- Target selection sync.
- Simple attack message.
- Basic NPC health sync.

Use:

- Godot ENet or WebSocket networking.
- Original protocol, not WotLK protocol.

Done when:

- Two Godot instances can see each other and fight one placeholder enemy.

## Stage 8 - Persistence Layer

Goal: save Godot gameplay state somewhere durable.

Options:

- Separate Godot companion database tables.
- Separate SQLite file.
- Bridge-managed MySQL tables.

Start with:

- Godot test accounts.
- Godot test characters.
- Position.
- Health.
- Inventory placeholders.

Avoid at first:

- Writing into core AzerothCore character tables as if Godot were the WotLK client.

Done when:

- Godot characters can log out and back in with saved state.

## Stage 9 - Path A Completion Gate

At this point decide whether Path A has reduced enough risk to begin the real port path.

Path A is complete only if:

- the companion dashboard works,
- the command layer and bridge boundaries are stable,
- Godot can inspect safe AzerothCore data,
- the sandbox proves movement/camera/UI/combat basics,
- Godot-native multiplayer and persistence have been proven locally,
- the missing runtime data and local-stack blockers are documented.

Path A completion does not end the project. It only opens Path B.

## Stage 10 - Protocol Research Spike

Goal: begin the full replacement-client path by understanding what Godot must implement to talk to AzerothCore as a WotLK-compatible client.

Research:

- Login handshake.
- Realm list flow.
- Session key handling.
- Client opcodes.
- Server opcodes.
- Object update packet structure.
- Movement packet structure.
- Existing open documentation/code references inside AzerothCore.

Deliverable:

- A document explaining the minimum packet subset needed for:
  - log in,
  - enter world,
  - see own character,
  - move,
  - see one creature.

Done when:

- We can estimate the first true Godot-to-AzerothCore protocol milestone.

## Stage 11 - Minimal Protocol Client Prototype

Goal: prove Godot can talk to AzerothCore at the protocol level.

Minimum target:

- Connect to authserver.
- Get realm list.
- Connect to worldserver.
- Authenticate session.
- Request character list.

No 3D world yet.

Done when:

- Godot can show the real character list through the AzerothCore protocol, not just through the database bridge.

## Stage 12 - Minimal Enter-World Prototype

Goal: enter the world as a real AzerothCore session.

Minimum target:

- Select character.
- Enter world.
- Receive initial object data.
- Parse own character position.
- Display a placeholder player marker in Godot.

Done when:

- A Godot scene can show "you are at this world position" from a live AzerothCore session.

## Stage 13 - Movement Prototype

Goal: move a Godot-controlled character in AzerothCore.

Build:

- Local Godot movement input.
- Convert Godot movement to server movement packets.
- Receive movement updates.
- Reconcile position.
- Keep the WotLK client offline during test, or use separate accounts.

Done when:

- Moving in Godot updates the AzerothCore session without desyncing immediately.

## Stage 14 - Object Visibility Prototype

Goal: show nearby server objects.

Build parsers for:

- Nearby players.
- Creatures.
- Game objects.
- Basic names/IDs.
- Positions.

Render:

- Placeholder capsules for players.
- Placeholder capsules for creatures.
- Placeholder cubes for game objects.

Done when:

- Godot can show a simple live world bubble around the player.

## Stage 15 - Combat And Interaction Prototype

Goal: perform one real server interaction.

Build:

- Target nearest creature.
- Send basic attack or spell command.
- Receive health/state updates.
- Show combat log text.

Done when:

- Godot can attack one creature through AzerothCore and show the result.

## Stage 16 - Client Feature March

Godot implements:

- Login/auth protocol.
- Realm connection.
- WotLK packet handling.
- Object updates.
- Movement.
- Spells.
- Inventory.
- Quests.
- Chat.
- Groups.
- Combat.

Add systems one at a time:

- Chat.
- Inventory.
- Equipment.
- Loot.
- Vendors.
- Quests.
- Trainers.
- Spells.
- Auras.
- Groups.
- Maps.
- Mail.
- Auction house.

Rule:

- Each system gets one small vertical slice before broadening.
- Each system must move toward faithful WotLK behavior unless a documented compatibility deviation is required.
- The original WotLK client may be used for local comparison, but it is not an acceptable runtime dependency.

## Stage 17 - Full Port Acceptance Gate

Goal: decide whether the Godot client is a functional WotLK port, not just a prototype.

Required:

- Godot can log in, select a character, enter world, move, interact, fight, chat, loot, manage inventory/equipment, quest, use vendors/trainers, use map/minimap, and perform major social/economy flows.
- Godot can run without launching the original WotLK client.
- Required local asset/data pipelines are documented and keep proprietary files local-only.
- Deviations from original WotLK behavior are documented, justified, and tracked.
- Manual or automated regression checks cover major systems.

Done when:

- The user can use Godot as the player-facing client for normal AzerothCore WotLK play.

## Suggested Immediate Build Order

1. Companion dashboard buttons.
2. Command output panel.
3. Server status parser.
4. WotLK client launch button.
5. Log viewer.
6. Local bridge skeleton.
7. Read-only character/account browser.
8. Simple Godot gameplay sandbox.
9. Data-driven creature/quest viewer.
10. Godot-native multiplayer test.
11. Complete the Path A gate and begin Path B protocol work.
12. Continue until Stage 17 full-port acceptance is met.

## Risks

- Snap/external-drive permissions can break Godot access.
- AzerothCore source has local modified files; accidental resets would be bad.
- Direct database writes can corrupt data if done casually.
- WotLK protocol work can consume a lot of time before it becomes visible, but it remains the required path.
- Asset/legal risk increases if client assets are copied into the repo.

## Best Next Task

Build Stage 1:

- Add working companion dashboard buttons for:
  - status,
  - start,
  - stop,
  - open logs,
  - launch WotLK client.

This gives immediate value and creates the command layer needed for every later stage. It is not the destination.
