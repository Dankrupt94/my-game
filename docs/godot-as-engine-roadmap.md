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

- Early dashboard prototypes called local helper scripts directly.
- Stage 04 supersedes that approach: Godot dashboard actions now go through the localhost host bridge.
- Existing scripts in `/run/media/doodbro/New 1tb/AzerothCore/scripts` remain the source of truth.
- Godot reads safe reports/log folders, but stack control and client launch are bridge-mediated.

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

Goal: let Godot inspect and browse real server world templates and user tables safely without direct access.

Build read-only browser panels in Godot for:

- **Realmlist:** Retrieve ID, name, port, address, and builds.
- **Accounts:** Retrieve ID, username, online status, expansion, and locale.
- **Characters:** Retrieve GUID, account ID, name, level, online status, race, class, and zone.
- **Creature Templates:** Filter/search templates by entry, name, min/max level, and rank.
- **Item Templates:** Filter/search by name, quality, class, item level, and required level.
- **Quest Templates:** Filter/search by title, level, min level, and type.
- **Spell Metadata:** Filter/search `spell_dbc` rows by name and spell level.

Implementation approach:

- Godot initiates HTTP `GET /data` requests to the localhost control bridge (`127.0.0.1:8765`).
- Query parameters: `view` (e.g. `items`), `search` (string pattern), and `limit` (max 100 rows).
- Parse the returned JSON payload and render it using simple structured data tables, cards, and text search bars.

Done when:

- Godot UI can query and display real AzerothCore database records without error.
- The UI contains zero input fields or trigger buttons capable of executing write operations (GET only).

## Stage 4 - Local Bridge Service

Goal: formalize the localhost bridge as the absolute network/database security boundary for Godot companion tooling.

Build a local bridge process with endpoints:

- `GET /status`: Run server stack audits on the host system.
- `GET /health`: Verify the bridge is reachable.
- `GET /data`: Execute read-only SELECT queries on the local MySQL server.
- `POST /start`: Start the Docker/local stack (requires token).
- `POST /stop`: Stop the Docker/local stack (requires token).
- `POST /client/launch`: Start `Wow.exe` via Wine (requires token).

Hardened Rules:

- **No Direct MySQL Connections:** Godot must never bundle MySQL libraries or credentials. The bridge is the sole DB boundary.
- **Token Security:** All mutating endpoints (`POST`) require the `X-Acore-Bridge-Token` header. The token is generated using a secure cryptographically strong random generator, stored in local host-readable permissions (`0600`) at `local_runtime/host-bridge-token.txt`, and kept out of Git.
- **Transaction Logs:** Any mutative SQL write queries (introduced in Stage 8) or stack control commands executed by the bridge must log a structured, timestamps-audited entry to `local_runtime/database-transactions.log`.
- **Localhost Only:** The bridge must only bind to `127.0.0.1`.

Done when:

- Godot communicates exclusively with the host control bridge over HTTP.
- Low-level scripts, Docker commands, and MySQL clients are completely hidden from the Godot process.

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
- the runtime data and local-stack blockers have been cleared or documented with repeatable repair notes.

Path A completion does not end the project. It only opens Path B.

## Stage 10 - Protocol Research Spike

Goal: research and document the exact network protocol structures, handshake mathematics, and packet boundaries needed to connect Godot natively to the local AzerothCore server.

Research:

- **SRP6 Authentication (Authserver):** Understand the SRP6 client/server auth handshake (`CMD_AUTH_LOGON_CHALLENGE` & `CMD_AUTH_LOGON_PROOF`). Document the large-prime arithmetic and hashing sequence.
- **Realm List Request:** Document the `CMD_REALM_LIST` payload structure.
- **Header Encryption (RC4-like Cipher):** Analyze the customized RC4 encryption stream used to encipher client packet headers (6 bytes: 2 size, 4 opcode) and decipher server headers (4 bytes: 2 size, 2 opcode).
- **Opcode Structures:** Document opcode headers, boundaries, and session key handshakes (`SMSG_AUTH_CHALLENGE`, `CMSG_AUTH_PROOF`, `SMSG_AUTH_RESPONSE`).
- **AzerothCore Source Mapping:** Map packet headers to specific source handlers in AzerothCore (`source/src/server/shared/Packets/` and `Opcodes.cpp`).

Deliverables:

- **Integration Strategy:** Assess whether to implement SRP6/RC4 in pure GDScript (slow, risky) or write a compiled native wrapper (e.g. C# assembly or C++ GDExtension helper).
- **Minimal Packet Manifest:** A document detailing the raw byte structure for the logon challenge, logon proof, realm list query, auth session proof, character enumeration query, and character login.

Done when:

- A concrete protocol document and cryptography wrapper strategy are completed.

## Stage 11 - Minimal Protocol Client Prototype

Goal: establish the first live TCP connection from Godot to the auth and world servers using authentic protocol structures.

Build:

- **TCP Connect & Handshake:** Open a raw TCP socket in Godot to authserver (`3724`). Execute logon challenge/proof utilizing the SRP6 wrapper library.
- **Realm Redirection:** Parse `CMD_REALM_LIST` to retrieve the worldserver ports/IPs.
- **World Server Auth:** Connect to worldserver (`8085`). Receive `SMSG_AUTH_CHALLENGE` containing the seed. Use the shared session key to initialize the RC4 header cipher (separately for read and write channels).
- **Session Verification:** Send the encrypted `CMSG_AUTH_PROOF`. Parse `SMSG_AUTH_RESPONSE` to confirm successful auth.
- **Character Enum Query:** Send `CMSG_CHAR_ENUM` and print the returned character names, classes, levels, and GUIDs directly in the Godot log.

Done when:

- Godot retrieves the account character list natively via TCP/opcodes, verified with the official WotLK client offline.

## Stage 12 - Minimal Enter-World Prototype

Goal: select a character and enter the world, receiving the first server-authoritative coordinate map.

Build:

- **Select Character:** Send `CMSG_PLAYER_LOGIN` with the selected character's GUID.
- **Parse Login Verification:** Read the incoming `SMSG_LOGIN_VERIFY_WORLD` packet. Extract the target Map ID, coordinates `(X, Y, Z)`, and orientation.
- **World Object Spawning:** Parse initial object creation blocks (`UPDATETYPE_CREATE_OBJECT` or `UPDATETYPE_CREATE_OBJECT2`) inside `SMSG_UPDATE_OBJECT` to identify the player's own entity GUID and its corresponding values.
- **Camera Setup:** Instantiating a basic 3D grid environment in Godot. Position the player camera and a placeholder cube at the exact `(X, Y, Z)` coordinates returned by the server.

Done when:

- Godot enters the world session and places a placeholder player mesh at the server-reported start coordinates.

## Stage 13 - Movement Prototype

Goal: synchronize player movement between Godot and AzerothCore while managing latency and server validation limits.

Build (Two-phase Implementation):

- **Phase 13a: Passive Mimicry (Coord Tracking)**
  - Open two client sessions: official WotLK client and Godot.
  - Let Godot read the official client character's movement update packets sent by the server.
  - Verify that Godot parses these coordinates, orientations, and fall-states in real time, moving the Godot replica avatar without rubber-banding.
- **Phase 13b: Active Input & Synchronization**
  - Implement WASD keybind inputs in Godot.
  - Convert inputs to `CMSG_MOVE_START_FORWARD`, `CMSG_MOVE_START_BACKWARD`, `CMSG_MOVE_STOP` packets containing sequence counters, movement flags, orientation, current time, and local coordinate vectors.
  - Monitor `MSG_MOVE_TELEPORT_ACK` and server-forced repositioning updates to implement simple coordinate reconciliation/interpolation when local and server positions mismatch.

Done when:

- Godot can move the player character around the server map with standard WASD keys, verified as smooth by watching from an external spectator account.

## Stage 14 - Object Visibility Prototype

Goal: parse and manage nearby entity updates (players, creatures, items, game objects) as they enter and leave the client's visibility bubble.

Build:

- **Client Object Manager:** Implement a clean, local hash map tracking active GUIDs.
- **Update Object Parser:** Write a parser for `SMSG_UPDATE_OBJECT` that reads bitmasks and handles the 4 primary update types:
  - `UPDATETYPE_VALUES`: Modify properties of an existing entity.
  - `UPDATETYPE_CREATE_OBJECT` / `UPDATETYPE_CREATE_OBJECT2`: Add a new entity (extract type, GUID, coordinates, parent, and status).
  - `UPDATETYPE_OUT_OF_RANGE_OBJECTS`: Remove entities that are no longer visible.
- **3D Placeholder Spawner:**
  - Instantiate a capsule mesh for other players (marked with character name labels).
  - Instantiate a red capsule mesh for NPC/creatures.
  - Instantiate a cube mesh for interactive game objects.
  - Automatically free (`queue_free()`) nodes when their GUID leaves range.

Done when:

- Godot displays placeholder shapes for nearby NPCs, objects, and players, updating their positions in real-time as they move.
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
- **SRP6 / RC4 Cryptography (Stage 11):** The WotLK login flow utilizes SRP6, and world packet headers are encrypted via an RC4-like cipher. Pure GDScript implementation is computationally slow and complex; using compiled libraries (like C# or a C++ GDExtension) should be investigated early.
- **Proprietary Asset Pipeline (Stage 14 / Path B):** Faithfully porting the client requires parsing `.m2` models, `.blp` textures, `.adt` terrain, and `.wmo` world objects from local MPQ archives. A local-only, Git-ignored asset pipeline must convert these into standard formats (GLTF, PNG) without checking them into the repository.
- **Movement Synchronization & Desyncs (Stage 13):** WoW uses client-predicted movement verified by server heartbeats. Desyncs cause rubber-banding or disconnects. Stage 13 must focus on simple "read-only movement mimicry" (tracking a character moved by the official client) before introducing direct client-authoritative movement inputs from Godot.

## Nice-to-Have Future Enhancements

These visual upgrades and optimization targets can be added to the backlog to improve client speed, fidelity, and safety post-port:

- **Physically Based Rendering (PBR) Materials:** Convert local textures to support normal/roughness maps procedural generation, providing modern material properties.
- **Atmospherics & Global Illumination:** Leverage SDFGI for caves and dungeons, dynamically shadows aligned to the day/night cycle, Screen Space Reflections (SSR), and volumetric fog.
- **Draw Call & VRAM Optimization:** Use `MultiMeshInstance3D` to batch city props, configure auto-mesh LODs, compress converted texture assets to BPTC format, and implement a chunked VRAM texture streaming system based on active ADT grid locations.
- **Rust GDExtension Parser:** Leverage Rust (`godot-rust`) for binary packet reading, opcode decryption, and updating player managers to eliminate GDScript GC frame drops and guarantee memory safety.

## Best Next Task

Build Stage 5:

- Create the original Godot gameplay sandbox required by Path A.
- Add third-person movement, camera, collision, targeting, one original NPC, one original enemy, an ability bar, health/resource UI, and a tiny original task loop.
- Keep all content original/placeholder and use AzerothCore-shaped data only when Stage 06 begins.

This starts moving the project from dashboard scaffolding toward Godot as the actual game engine layer. It is still Path A risk reduction, not the final WotLK port destination.
