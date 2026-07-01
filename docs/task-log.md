# Task Log

## 2026-07-01 - Stage 14 Object Visibility Started

Goal: build the first object visibility slice after Stage 13 live movement.

Plan:

- Add a Godot client object manager keyed by GUID.
- Populate visible placeholders from real local AzerothCore data without copying proprietary client assets.
- Keep the full `SMSG_UPDATE_OBJECT` parser boundary explicit.
- Validate the query tool, bridge endpoint, object manager smoke, and Godot scene self-test.

Result:

- Added `tools/nearby_world_objects.py` for read-only nearby world spawn queries.
- Added `GET /nearby` to the localhost host bridge and a `nearby` bridge-client action.
- Restarted only the host bridge process so the new read-only endpoint was available.
- Added `scripts/client_object_manager.gd`.
- Added `scenes/object_visibility_view.tscn` and `scripts/object_visibility_view.gd`.
- Added a dashboard `Objects` action.
- Added `docs/object-visibility.md`.
- Verified the nearby bridge endpoint returns real local creatures and gameobjects around `Codexstage`.
- Verified `tools/object_visibility_smoke.gd`.
- Verified `ACORE_OBJECT_VISIBILITY_SELF_TEST=1 godot-4 --headless --path . res://scenes/object_visibility_view.tscn`, which spawned 15 creature placeholders and 15 gameobject placeholders.
- Used local `qwen-agent` as a narrow advisory reviewer; it raised no concrete blocker beyond preserving validation, localhost-only expectations, and the known packet-driven spawn/despawn gap.
- Left full packet-driven update-object create/update/out-of-range parsing as the next Stage 14 hardening task.

## 2026-07-01 - Stage 13 Movement And Reconciliation Started

Goal: continue from the Stage 12 live enter-world proof into a safe movement/reconciliation vertical slice without causing avoidable worldserver disconnect loops.

Plan:

- Preserve this before-task note.
- Start with packet/documentation research and movement telemetry scaffolding.
- Prefer passive/reconciliation-safe helpers before attempting active server-authoritative WASD movement.
- Add Godot-side visualization and test scaffolding that can prove coordinate transforms and drift handling without proprietary assets.
- Keep credentials, packet captures, runtime logs, and proprietary files out of Git.
- Validate native self-tests, Godot bridge checks, and asset boundaries before committing the stage result.

Result:

- Added movement packet construction for the WotLK/AzerothCore `MSG_MOVE_*` body format.
- Added live movement sequencing in the native protocol flow: enter world, wait for `SMSG_TIME_SYNC_REQ`, send `MSG_MOVE_START_FORWARD`, send `MSG_MOVE_STOP`, request logout/session cleanup, reconnect into the world, and compare the live position against the target.
- Confirmed that movement sent too early after `SMSG_LOGIN_VERIFY_WORLD` does not persist reliably.
- Confirmed that a bare heartbeat is insufficient for the Stage 13 persistence check.
- Split reconciliation into live world position and saved character-list position because fast logout/session cleanup can lag.
- Verified a successful live movement step for `Codexstage`: before `(-8946.9, -132.493, 83.5312)`, target `(-8946.7, -132.493, 83.5312)`, live `(-8946.7, -132.493, 83.5312)`, live drift `0`, saved drift `0.200195`.
- Verified Godot movement bridge smoke with `live_position_accepted=true` and `live_drift=0`.
- Verified the movement scene self-test with `MOVEMENT_RECONCILIATION_SELF_TEST_OK live_drift=0.000 saved_drift=0.200`.
- Added Godot native extension and bridge wrappers for the movement probe.
- Added a Movement Test dashboard action, `scenes/movement_reconciliation_view.tscn`, `scripts/movement_reconciliation_view.gd`, and `tools/movement_bridge_smoke.gd`.
- Used local `qwen-agent` as a narrow advisory reviewer; it flagged only known Stage 13 scope limits around continuous WASD, movement edge cases, and saved-position drift reliability.
- Left continuous WASD prediction, passive official-client mimicry, and spectator-client smoothness validation for later movement hardening.

## 2026-07-01 - Stage 12 Enter World Prototype Started

Goal: create a disposable local test character for the ignored protocol account and complete the Stage 12 enter-world prototype as far as the current local server and protocol parser allow.

Plan:

- Preserve this before-task note.
- Create a local-only test character for `CODEXPROTO` without committing credentials or database dumps.
- Add `CMSG_PLAYER_LOGIN` support and parse `SMSG_LOGIN_VERIFY_WORLD`.
- Capture initial `SMSG_UPDATE_OBJECT`/compressed update packet presence and implement the safest practical parser boundary.
- Add a Godot scene that renders a basic grid and marker at the server-reported login coordinates.
- Validate through native helper, Godot extension, and headless Godot scene checks.

Result:

- Created the local-only test character `Codexstage` for the ignored protocol smoke account.
- Added native protocol support for `CMSG_CHAR_CREATE`, `SMSG_CHAR_CREATE`, `CMSG_PLAYER_LOGIN`, `SMSG_LOGIN_VERIFY_WORLD`, `SMSG_UPDATE_OBJECT`, and `SMSG_COMPRESSED_UPDATE_OBJECT`.
- Added `--create-character` and `--enter-world` helper commands.
- Verified live enter-world against the local AzerothCore stack: `Codexstage` enters map `0` at `(-8949.95, -132.493, 83.5312)` with orientation `0`.
- Added Godot `AcoreProtocolClient` methods for `create_character` and `enter_world`.
- Added `ProtocolClientBridge.create_test_character(...)` and `ProtocolClientBridge.enter_world(...)` with native-extension preference and direct helper fallback.
- Removed shell-sourced credential loading from the helper fallback; Godot now reads the ignored local account file itself and passes credentials only to the local process.
- Added `scenes/enter_world_view.tscn` and `scripts/enter_world_view.gd`, which render the Stage 12 grid and marker from the server-reported login position.
- Added `tools/enter_world_bridge_smoke.gd` for headless enter-world checks.
- Validated native self-tests, live character enum, live enter-world, Godot protocol smoke, and the Stage 12 scene self-test.
- Used local `qwen-agent` as a narrow advisory reviewer for the Stage 12 diff; it raised no concrete blocker beyond future test and refactor suggestions.
- The local login stream did not emit `SMSG_UPDATE_OBJECT`/`SMSG_COMPRESSED_UPDATE_OBJECT` in the observed Stage 12 packet window. Full object replication parsing is documented as the next packet-layer task.

## 2026-06-30 - Stage 11 Godot GDExtension Wrapper Checkpoint Started

Goal: attempt the first actual Godot-native wrapper around the protocol bridge so Godot can eventually call the validated character-flow path without launching a helper process.

Plan:

- Keep downloaded Godot C++ binding sources and Python build tools local-only and ignored.
- Use the installed Godot 4.7 engine to generate any needed extension API files.
- Build the smallest loadable GDExtension wrapper first.
- Preserve the existing helper-process bridge as the fallback until Godot loading and threaded execution are proven.
- Validate Godot headless startup and native protocol smoke checks before committing.

Result:

- Built local `godot-cpp` bindings from the installed Godot 4.7 extension API dump.
- Added `native/godot_protocol_extension/` with a registered `AcoreProtocolClient` GDExtension class.
- Added `acore_protocol.gdextension` and a local ignored extension binary target under `bin/`.
- Found that a host-built extension required GLIBC `2.43`, which Snap Godot could not load.
- Added `tools/build_godot_protocol_extension_compat.sh`, which builds the extension inside Ubuntu 24.04 through Docker to avoid the Snap loader mismatch.
- Added Godot smoke scripts for direct extension validation and dashboard bridge validation.
- Updated the dashboard protocol bridge to prefer `AcoreProtocolClient` when available, while retaining the helper-process fallback.
- Validated Snap Godot import, direct extension self-test, direct extension live character flow, dashboard bridge live character flow, and main scene startup.
- Used local `qwen-agent` as a narrow advisory reviewer; final acceptance came from Godot load and live protocol checks.

## 2026-06-30 - Stage 11 Godot-Native Protocol Boundary Checkpoint Started

Goal: move the validated protocol flow toward a Godot-native loading boundary so the project can retire the blocking helper-process bridge.

Plan:

- Preserve the current helper bridge as the working fallback.
- Add a small native bridge/library boundary around the reusable C++ protocol flow.
- Document how Godot should prefer the native path once it is loadable.
- Validate the native build and Godot startup without committing local credentials, packet captures, or proprietary files.

Result:

- Split the native build into a reusable static core, CLI helper, and shared-library bridge target.
- Added a C-compatible JSON API in `protocol_c_api.h` and `protocol_c_api.cpp` around the validated protocol flow.
- Added `tools/protocol_bridge_ctypes_smoke.py` to load `libacore_protocol_bridge.so` locally and verify the exported functions.
- Documented the native boundary and Godot wrapper plan in `docs/protocol/godot-native-boundary.md`.
- Confirmed the no-secret smoke path loads the library and skips character flow safely without credentials.
- Confirmed the ignored local `CODEXPROTO` account path returns character-flow JSON with auth, world auth, and character enum marked true.
- Kept the dashboard helper-process bridge as the working fallback while this native loading boundary is prepared.
- Used local `qwen-agent` as a narrow advisory reviewer; final acceptance came from CMake, CLI, shared-library, and Godot startup checks.

## 2026-06-30 - Stage 11 Reusable Protocol Flow Checkpoint Started

Goal: refactor the validated native helper so the auth/realm/world-auth/character-enum flow is reusable by Godot-native integration instead of being trapped inside the CLI entrypoint.

Plan:

- Move reusable socket/auth/world-flow code out of `main.cpp`.
- Keep the existing `acore_protocol_client` commands and output stable.
- Validate self-tests, safe probes, guarded password behavior, and live `CODEXPROTO` character flow.
- Keep local credentials, packet captures, and proprietary files out of Git.

Result:

- Added `native/protocol_client/src/protocol_flow.h` and `native/protocol_client/src/protocol_flow.cpp` as the reusable protocol flow layer for auth challenge, SRP6 proof, realm parsing, world auth, and character enum.
- Replaced the large CLI-only implementation in `main.cpp` with a thin command wrapper around the reusable flow layer.
- Kept the existing CLI command names and milestone output stable so Godot's current helper bridge keeps working while the true native integration is prepared.
- Added the new flow implementation to the CMake target.
- Validated the CMake build, self-test, public auth challenge probe, public world challenge probe, missing-password guards, live ignored `CODEXPROTO` character flow, and Godot headless main scene startup.
- Used local `qwen-agent` as a narrow advisory reviewer for the refactor; final acceptance came from the local build and live protocol checks.
- Confirmed no credentials, packet captures, local runtime files, or proprietary client files were added to Git.

## 2026-06-30 - Stage 11 World Packet Parser Checkpoint Started

Goal: continue Stage 11 by adding world-auth packet construction and character-list parsing without requiring account credentials.

Plan:

- Build `CMSG_AUTH_SESSION` payload/header helpers.
- Build encrypted `CMSG_CHAR_ENUM` header support using the existing header crypto.
- Add a synthetic `SMSG_CHAR_ENUM` parser test with safe fake character data.
- Keep live credential-backed auth optional through ignored local environment variables.

Result:

- Added native world packet helpers for `CMSG_AUTH_SESSION`, `CMSG_CHAR_ENUM`, empty compressed addon info, and `SMSG_CHAR_ENUM` summary parsing.
- Added a synthetic character enum parser test using safe fake character data.
- Added guarded `--character-flow`, which performs authserver login, realm parsing, world auth, encrypted char enum request, and live char enum parsing when `ACORE_PROTOCOL_PASSWORD` is supplied.
- Hardened the character enum parser against truncated character records.
- Fixed auth logon-challenge OS byte order after live world auth exposed that AzerothCore was storing an empty client OS.
- Added socket timeouts, flushed progress markers, and optional header-only world packet tracing.
- Used local `qwen-agent` as an advisory reviewer for the narrow character-flow packet block; final checks remained the local build and live safe probes.
- Created a disposable local `CODEXPROTO` protocol account with its password kept only in ignored `local_runtime/protocol-test-account.env`.
- Documented the local server smoke profile in `docs/local-server-smoke-profile.md`.
- Temporarily disabled Warden and random bot autologin in the local AzerothCore config to validate the protocol path without anti-cheat module traffic or hundreds of startup bot logins.
- Added the first Godot-side protocol wrapper script and dashboard `Check Protocol` action.
- Validated a clean CMake build.
- `--self-test` now prints `WORLD_PACKET_SELF_TEST_OK`.
- Live no-secret auth challenge and world challenge probes still pass.
- Guarded auth flow still fails safely when `ACORE_PROTOCOL_PASSWORD` is not set.
- Guarded character flow fails safely when `ACORE_PROTOCOL_PASSWORD` is not set.
- Live credential-backed `--character-flow` now prints `AUTH_FLOW_OK`, `WORLD_AUTH_OK`, and `CHAR_ENUM_OK count=0` against the local smoke-profile server.
- Godot headless project and main-scene startup checks pass after wiring the dashboard protocol action.

## 2026-06-30 - Stage 11 Started

Goal: begin the minimal local protocol client helper for direct AzerothCore auth, realm, world auth, and character enumeration.

Plan:

- Correct the Stage 11 world-auth opcode target to `CMSG_AUTH_SESSION`.
- Start with a native C++ helper and smoke harness before Godot UI integration.
- Keep account secrets and generated packet dumps out of Git.
- Build only protocol code and safe local test output in this stage.

Result:

- Added the first native protocol helper under `native/protocol_client/`.
- Added ARC4 header crypto, HMAC-SHA1 integration, world header byte helpers, and a CMake build.
- Added a self-test for header encoding, header crypto initialization, and SRP6 client/server proof agreement.
- Added an authserver challenge probe that sends no password and prints only public SRP parameter lengths/flags.
- Added a guarded auth flow that reads `ACORE_PROTOCOL_PASSWORD` only from the local environment, verifies SRP6 proof, and parses realm list when a valid password is available.
- Added a safe live worldserver challenge probe that parses `SMSG_AUTH_CHALLENGE` without credentials.
- Validated the helper build, self-test, auth challenge probe, and live world challenge probe.

## 2026-06-30 - Stage 10 Started

Goal: begin Path B protocol research for a Godot-native AzerothCore-compatible WotLK client.

Plan:

- Identify local AzerothCore source files for authserver, realm list, world socket, packets, and opcodes.
- Create Git-safe protocol documentation under `docs/protocol/`.
- Decide the crypto integration direction for SRP6 and world header encryption.
- Document byte-level flows for login, realm list, world authentication, character enumeration, and character select.
- Produce an opcode reference for build `12340` boundaries needed by the first Godot protocol client.

Result:

- Completed protocol research docs under `docs/protocol/`.
- Chose a native C++ helper path first because `g++` and CMake are available locally while `dotnet` is not installed.
- Documented authserver challenge/proof and realm-list packet structures.
- Documented worldserver header framing, `SMSG_AUTH_CHALLENGE`, `CMSG_AUTH_SESSION`, `SMSG_AUTH_RESPONSE`, `CMSG_CHAR_ENUM`, `SMSG_CHAR_ENUM`, and `CMSG_PLAYER_LOGIN`.
- Created an opcode boundary sheet for build `12340`.
- Used local `qwen-agent:latest` as an advisory reviewer and added clearer realm endpoint parsing notes for Stage 11.

## 2026-06-30 - Stage 09 Started

Goal: review whether Path A is complete enough to begin Path B protocol-client work.

Plan:

- Check every Path A completion requirement against the current project state.
- Clean up any stale stage status that no longer matches the built dashboard.
- Record missing work as either completed or intentionally deferred.
- Document the specific risks Path B must carry forward.
- Make a written go/no-go decision for beginning Stage 10.

Result:

- Path A was approved as complete enough to begin Path B.
- Marked Stage 01 complete after dashboard launch and bridge stop/start validation.
- Validated bridge status and data summary against the live stack.
- Validated dashboard headless launch, sandbox data self-test, sandbox persistence self-test, and multiplayer smoke test.
- Found and repaired a local AzerothCore `scripts/start.sh` restart issue where an existing stopped `ac-mysql` container was not restarted before `docker run`.
- Confirmed the stack returned to live ports: MySQL `3306`, authserver `3724`, worldserver `8085`, and Ollama `11434`.
- Recorded deferred Path A polish and Path B risks in the Stage 09 file.

## 2026-06-30 - Stage 08 Started

Goal: persist Godot-native sandbox state safely without touching AzerothCore core tables.

Plan:

- Preserve this before-task note.
- Use ignored local storage under `local_runtime/`.
- Add save/load support for a Godot test identity, test character, position, health, focus, and placeholder inventory.
- Add a logout/login-style reload flow in the sandbox.
- Add a headless persistence self-test.

Result:

- Added sandbox `Save`, `Load`, and `Reload` buttons.
- Added ignored local persistence at `local_runtime/sandbox-state.json`.
- Saved local test identity, test character, position, health, focus, quest flags, and placeholder inventory.
- Added and passed `ACORE_SANDBOX_PERSISTENCE_SELF_TEST=1`.
- Documented storage choice, schema, migration notes, and backup/restore process in `docs/persistence-layer.md`.

## 2026-06-30 - Stage 07 Started

Goal: prove a small Godot-native multiplayer loop on localhost before any WotLK protocol work.

Plan:

- Preserve this before-task note.
- Add a minimal multiplayer scene and scripts using Godot-native networking.
- Support local server mode and local client mode.
- Synchronize player spawn/despawn, positions, target selection, attack messages, and shared placeholder NPC health.
- Add an automated local self-test where practical and document manual two-client test steps.

Result:

- Added `scenes/multiplayer_sandbox.tscn`, `scripts/multiplayer_sandbox.gd`, and `tools/run_multiplayer_smoke_test.py`.
- Added a dashboard `Open Multiplayer` action.
- Implemented ENet server mode and client mode on localhost.
- Implemented player registration, spawn/despawn snapshots, position/state updates, target sync, attack messages, and shared placeholder NPC health replication.
- Added and passed a headless smoke test with one server and two clients.

## 2026-06-30 - Stage 06 Started

Goal: make the playable Godot sandbox consume real AzerothCore-shaped data through the read-only bridge.

Plan:

- Preserve this before-task note.
- Add read-only sandbox HTTP calls to `GET /data` for small character, creature, quest, and item slices.
- Map returned records into placeholder UI labels and original primitive spawn objects.
- Add a headless data self-test that proves data reached the sandbox and created placeholders.
- Keep all database access read-only and all generated reports/runtime files out of Git.

Result:

- Fixed the host bridge `/data` endpoint to parse each data browser stdout report directly, preventing shared local report races during concurrent data requests.
- Added read-only Godot `HTTPRequest` calls from the sandbox to `GET /data` for characters, creatures, quests, and items.
- Mapped characters, quests, and items into sandbox UI text.
- Mapped creature records into original capsule placeholders in the sandbox scene.
- Added and passed `ACORE_SANDBOX_DATA_SELF_TEST=1` for bridge data loading and placeholder spawning.

## 2026-06-30 - Stage 05 Started

Goal: add a fresh original playable Godot gameplay sandbox under the AzerothCore companion direction.

Plan:

- Preserve this before-task note.
- Add a new sandbox scene and script using original placeholder geometry only.
- Add third-person movement, camera follow, collision, targeting, one original NPC, one original enemy, an action bar, health/resource UI, and a simple task loop.
- Link the dashboard to the sandbox and provide a return path.
- Validate the scene with Godot 4.7 headless launch and Git asset-boundary checks.

Result:

- Added `scenes/gameplay_sandbox.tscn` and `scripts/gameplay_sandbox.gd`.
- Added a dashboard `Open Sandbox` action and a sandbox `Dashboard` return button.
- Implemented original placeholder third-person movement, camera follow, collision, NPC, enemy, targeting, strike action, health/focus UI, target health UI, and a simple task loop.
- Preserved and parse-checked modular gameplay scaffolding for later refactors, including player state, camera, targeting, stats, cooldown, and floating-text helpers.
- Documented controls, files, gameplay systems, and placeholder asset policy in `docs/gameplay-sandbox.md`.
- Added and passed a headless sandbox self-test for mentor interaction, enemy defeat, task completion, and target health UI state.
- Validated the dashboard and sandbox scenes in Godot 4.7 headless mode.

## 2026-06-30 - Stage 04 Started

Goal: harden the localhost bridge into the formal security boundary between Godot and host-level AzerothCore operations.

Plan:

- Preserve this before-task note.
- Add the missing bridge endpoint for launching the local client process.
- Add structured local mutation logging for bridge-controlled start, stop, and launch actions.
- Remove direct Godot dashboard fallbacks to host scripts or Wine so dashboard actions go through the bridge.
- Validate the bridge, dashboard launch, local-stack status, and Git asset boundaries before committing the finished stage.

Result:

- Added token-protected `POST /client/launch` to the host bridge.
- Added ignored, owner-only `local_runtime/database-transactions.log` JSONL mutation logging for start, stop, and client launch.
- Updated the dashboard to use native Godot HTTP requests to the localhost bridge for status, data, stack control, restart, and client launch.
- Removed direct dashboard execution paths for host scripts, helper Python commands, and Wine.
- Validated bridge health/status/data, unauthorized and invalid-token rejection, idempotent start logging, safe launch failure without Wine, mutation-log permissions/JSON parsing, local Qwen review, and Godot headless launch.

## 2026-06-30 - Move Godot Project Into AzerothCore Bundle

Goal: move the Godot project out of the SSD trash and into the local AzerothCore bundle where it is easier to find and manage.

Result:

- Moved the project to `/run/media/doodbro/New 1tb/AzerothCore/godot-azerothcore-companion`.
- Preserved the existing Git repo and GitHub remote.
- Documented the local AzerothCore, build, and WotLK client paths in `docs/location-notes.md`.

## 2026-06-30 - Rename And Reset For AzerothCore Companion

Goal: abandon the previous RPG prototype and reset this Godot repo for the local AzerothCore companion project.

Result:

- Renamed the folder to `/run/media/doodbro/New 1tb/AzerothCore/godot-azerothcore-companion`.
- Removed retired gameplay scripts, the old controls doc, the old scene copy, and old desktop launchers.
- Replaced the main Godot scene with an AzerothCore companion dashboard shell.
- Renamed project launchers and Desktop shortcuts for the AzerothCore companion project.
- Verified the renamed Godot shell launches with Godot 4.7.

## 2026-06-30 - Refine Godot As Engine Roadmap

Goal: think through a more detailed step-by-step path for turning Godot from a companion shell into a real game engine/client layer for the local AzerothCore setup.

Plan:

- Preserve a before-task note.
- Create a roadmap document with phases, deliverables, decisions, risks, and stopping points.
- Commit and push the roadmap.

Result:

- Added `docs/godot-as-engine-roadmap.md`.
- Broke the path into companion tooling, bridge/data work, original Godot gameplay, Godot-native multiplayer, and optional protocol-client milestones.
- Marked Stage 1 companion dashboard controls as the best next task.

## 2026-06-30 - Create Master Port Plan And Stage Docs

Goal: create an explicit reference plan for building toward a Godot-AzerothCore-WotLK game, beginning with Path A and moving to Path B after Path A is achieved.

Plan:

- Save this before-task note.
- Add a master plan file for the whole project direction.
- Add one documentation file per stage so progress can be tracked as changes occur.
- Link the master plan from the README.
- Commit and push the completed documentation.

Result:

- Added `docs/godot-azerothcore-wotlk-master-plan.md`.
- Added stage documentation scaffolding under `docs/stages/`.
- Documented that Path A is first and Path B follows after Path A is achieved.
- Documented the long-term goal of a faithful Godot-AzerothCore-WotLK client/game.
- Added `docs/local-ai-resources.md` for local Ollama models, including `qwen2.5-coder:7b`.

## 2026-06-30 - Clarify Proprietary Asset Handling

Goal: document that proprietary client assets stay local and are not committed to GitHub, while the project may reference local asset/client paths for private experimentation.

Plan:

- Save this policy checkpoint.
- Add ignore rules for common proprietary client/extracted asset file types and local asset folders.
- Add a local asset handling document.
- Link it from the master plan and README.
- Commit and push the completed documentation.

Result:

- Added `docs/asset-handling-policy.md`.
- Added `.gitignore` rules for local-only asset folders and common WotLK client/extracted asset extensions.
- Linked the policy from the README and master plan.
- Recorded that the project owner authorizes local-only proprietary client file use for this prototype, while Git/GitHub must stay code, documentation, tooling, manifests, and references only.

## 2026-06-30 - Record Local Blizzard File Authorization

Goal: make the project owner's clarified instruction explicit: all Blizzard/WotLK files available on this machine are authorized inputs for the local Godot porting prototype, but proprietary files must not be pushed to GitHub.

Plan:

- Save this before-task note.
- Add a dedicated local authorization and autonomous-work directive.
- Link the directive from the README and master plan.
- Tighten `AGENTS.md` so future agents know the local files are expected inputs.
- Verify Git still tracks no proprietary client asset files.
- Commit and push the completed documentation.

Result:

- Added `docs/local-blizzard-file-authorization.md`.
- Documented that all Blizzard/WotLK files available on this machine are authorized local inputs for the porting prototype.
- Documented that GitHub must receive only non-proprietary code, docs, tooling, manifests, references, and original/placeholder assets.
- Linked the directive from `README.md`, the master plan, `AGENTS.md`, and the asset policy.

## 2026-06-30 - Begin Autonomous Toolchain And Client Manifest Work

Goal: begin the porting process without further user input by creating repeatable local audits for development tools and WotLK client file metadata.

Plan:

- Save this before-task note.
- Add a tools folder for local audit/scanner scripts.
- Add a toolchain audit that reports installed/missing development tools.
- Add a client manifest scanner that reads local file metadata only and writes ignored local reports.
- Document how future agents should run the tools.
- Run the tools against this machine and record a safe summary.
- Verify no proprietary files or local report payloads are tracked.
- Commit and push the completed non-proprietary code and docs.

Result:

- Added `tools/audit_toolchain.py`.
- Added `tools/client_manifest_scan.py`.
- Added `tools/README.md`.
- Added ignored `local_reports/` output handling.
- Ran both tools successfully.
- Recorded safe counts and missing/deferred tools in `docs/toolchain-and-client-audit-summary.md`.
- Used `qwen-agent:latest` as a safe advisory reviewer and applied its large-directory scanner feedback.

## 2026-06-30 - Begin Read-Only AzerothCore Database Audit

Goal: continue autonomously by installing/enabling local MySQL client tools and adding a safe read-only database audit for the local AzerothCore configuration.

Plan:

- Save this before-task note.
- Install or enable `mysql` and `mysqldump` locally.
- Add a script that parses AzerothCore config database connection strings without committing secrets.
- Run read-only connectivity and table-count checks if the local database server is reachable.
- Write detailed output only to ignored `local_reports/`.
- Track a safe summary in documentation.
- Verify no secrets, local reports, or proprietary files are tracked.
- Commit and push the completed non-proprietary code and docs.

Result:

- Installed `default-mysql-client`, providing `mysql` and `mysqldump`.
- Added `tools/audit_azerothcore_db.py`.
- The audit script redacts config credentials and writes detailed reports to ignored `local_reports/`.
- Documented the database audit in `tools/README.md`.
- Ran the database audit: 3 configured databases were found, and 0 were reachable because `127.0.0.1:3306` refused connections.

## 2026-06-30 - Begin Server Stack Discovery

Goal: continue Stage 01 by adding a safe status/discovery tool for the local AzerothCore scripts, ports, processes, Docker MySQL container, binaries, logs, and client path.

Plan:

- Save this before-task note.
- Add a local server-stack audit script that does not start or stop services by default.
- Record script paths for `start.sh`, `stop.sh`, and `status.sh`.
- Record port/process/container/binary/log/client status in ignored local reports.
- Track a safe summary in documentation and update Stage 01 notes.
- Verify no local reports, secrets, or proprietary files are tracked.
- Commit and push the completed non-proprietary code and docs.

Result:

- Added `tools/audit_server_stack.py`.
- Documented known AzerothCore start, stop, status, and common script paths.
- Added `docs/server-stack-discovery-summary.md`.
- Updated Stage 01 status to `In Progress`.
- Ran the server-stack audit: only Ollama was listening, Docker `ac-mysql` was not found, Linux auth/world binaries under `run/bin` were not found, and bundle `Wow.exe` was found.

## 2026-06-30 - Begin Stage 01 Dashboard Controls

Goal: make the Godot companion dashboard useful by wiring visible controls to the local status/audit tooling and existing AzerothCore stack scripts.

Plan:

- Save this before-task note.
- Add dashboard status rows for MySQL, authserver, worldserver, Ollama, Docker MySQL, binaries, and client executable.
- Add buttons for refresh/status, start stack, stop stack, open logs, open local reports, and launch client.
- Route start/stop through `/run/media/doodbro/New 1tb/AzerothCore/scripts/start.sh` and `stop.sh`.
- Route refresh through `tools/audit_server_stack.py`.
- Keep proprietary files and local reports out of Git.
- Validate the Godot scene loads with Godot 4.7.
- Commit and push the completed dashboard changes.

Result:

- Replaced the static dashboard with status rows and action buttons.
- Added status refresh through `tools/audit_server_stack.py`.
- Added buttons for start stack, stop stack, opening logs, opening local reports, and launching the bundle client.
- Validated that Godot 4.7 loads the scene headlessly.
- Found that Snap Godot cannot see Docker from child processes; guarded direct start/stop and documented the need for a localhost bridge or native runner.

## 2026-06-30 - Begin Host Control Bridge

Goal: continue autonomously by adding a localhost-only host bridge that runs outside Snap Godot and can execute safe AzerothCore status/start/stop actions for the dashboard.

Plan:

- Save this before-task note.
- Add a Python localhost bridge with health/status endpoints.
- Require a local token for state-changing start/stop requests.
- Keep bridge token, logs, and runtime files in ignored local folders.
- Add host-side start/stop scripts for the bridge.
- Document how the dashboard should use the bridge.
- Validate the bridge without starting the AzerothCore stack.
- Commit and push the completed non-proprietary code and docs.

Result:

- Added `tools/host_control_bridge.py`.
- Added host-side bridge start/stop scripts.
- Added token and runtime ignore handling under `local_runtime/`.
- Documented the bridge in `docs/host-control-bridge.md`.
- Validated `GET /health`, `GET /status`, and unauthorized `POST /start` rejection without starting the AzerothCore stack.

## 2026-06-30 - Begin Dashboard Bridge Integration

Goal: let the Godot dashboard use the localhost host bridge for status/start/stop when it is running, while keeping direct Snap-limited behavior as a fallback.

Plan:

- Save this before-task note.
- Add a small bridge client tool for health/status/start/stop requests.
- Update the dashboard refresh button to prefer bridge status.
- Update start/stop buttons to use the bridge token when the bridge is reachable.
- Keep direct script execution guarded when the bridge is unavailable inside Snap.
- Validate Godot 4.7 scene loading and bridge client behavior without starting the AzerothCore stack.
- Commit and push the completed non-proprietary code and docs.

Result:

- Added `tools/bridge_client.py`.
- Dashboard refresh now prefers bridge status when the bridge is online.
- Dashboard start/stop now use bridge token requests when the bridge is online.
- Direct Snap start/stop remains guarded when the bridge is offline.
- Validated offline bridge failure, online bridge health/status, and Godot 4.7 headless status refresh through the bridge without starting the stack.

## 2026-06-30 - Begin Bridge-Aware Companion Launcher

Goal: make the normal companion launcher start the localhost host bridge before opening Godot so the dashboard works through one desktop button.

Plan:

- Save this before-task note.
- Update `scripts/run_game.sh` to start the host bridge before launching Godot.
- Keep the bridge startup idempotent.
- Keep logs in ignored local/runtime folders.
- Validate the launcher headlessly.
- Commit and push the completed launcher update.

Result:

- Updated `scripts/run_game.sh` to start the host bridge before launching Godot.
- Kept bridge startup optional with `ACORE_COMPANION_START_BRIDGE=0`.
- Documented automatic bridge startup in `docs/host-control-bridge.md`.
- Validated the launcher in headless mode: it started the bridge, launched Godot 4.7, exited successfully, and the bridge was stopped after the test.

## 2026-06-30 - Begin Linux Server Binary Completion

Goal: continue toward a runnable local stack by completing the missing Linux `worldserver` build and installing available Linux server binaries into the configured AzerothCore run folder.

Plan:

- Save this before-task note.
- Build the `worldserver` target in `/home/doodbro/azeroth-build`.
- Run the CMake install step if the build succeeds.
- Re-run server-stack and database audits.
- Record safe build/install results in documentation.
- Commit and push non-proprietary documentation/tool updates.

Result:

- Built the `worldserver` target successfully in `/home/doodbro/azeroth-build`.
- Installed `authserver` and `worldserver` into `/run/media/doodbro/New 1tb/AzerothCore/run/bin`.
- Patched local AzerothCore runtime startup outside this repo so MySQL 8.4 can open the existing local database data on Linux.
- Repaired local authserver config so `SourceDirectory` points to `/run/media/doodbro/New 1tb/AzerothCore/source`.
- Verified the configured database login from the host.
- Re-ran database audit: auth, world, and characters databases are reachable.
- Re-ran server-stack audit: MySQL and Ollama are listening; auth/world binaries exist; worldserver now reaches local runtime data loading.
- Blocker at that checkpoint: required local runtime data under `/run/media/doodbro/New 1tb/AzerothCore/data` was missing, so worldserver stopped with missing map-file errors.

## 2026-06-30 - Add Runtime Data Readiness To Dashboard

Goal: make the current worldserver blocker visible in the Godot companion dashboard and the safe server-stack audit.

Plan:

- Add runtime data checks to the server-stack audit.
- Show the combined runtime data readiness state in the dashboard.
- Update documentation with the local runtime repair checkpoint.
- Validate the Godot project still loads.

Result:

- Added audit checks for `data/maps`, `data/dbc`, `data/vmaps`, and `data/mmaps`.
- Added a `Runtime data` row to the dashboard.
- Documented local runtime repairs in `docs/local-runtime-repairs.md`.

## 2026-06-30 - Clarify Full Godot WotLK Port Goal

Goal: make the plan explicit that the project target is a fully functional Godot-native WotLK client/port, not a companion-only app, half-port, reimagining, or continued reliance on the original WotLK client.

Plan:

- Update the master plan with a full-port acceptance standard.
- Update the engine roadmap so Path A is scaffolding only and Path B/full parity is the destination.
- Add a final full-port acceptance stage.
- Update README and agent instructions with the same mission boundary.
- Take the Stash server stack offline if it is still running.
- Commit and push the documentation changes.

Result:

- Stopped the running Stash-related containers: `nsfw-ai-server`, `stash-dockge`, `stash-uptime-kuma`, and `stash-dozzle`.
- Left the AzerothCore MySQL container `ac-mysql` running.
- Added Stage 17, the full-port acceptance gate.
- Updated the master plan, roadmap, stage docs, README, local authorization, and agent instructions to clarify that companion/dashboard and Path A sandbox work are scaffolding only.

## 2026-06-30 - Begin Runtime Data Extraction

Goal: continue the port process by clearing the current worldserver blocker: missing local AzerothCore runtime data.

Plan:

- Document the extraction plan before generating local data.
- Build the AzerothCore extractor tools because the current build has `TOOLS_BUILD=none`.
- Use the authorized local bundle client as input.
- Generate data under `/run/media/doodbro/New 1tb/AzerothCore/data`.
- Keep generated maps, DBC, VMaps, MMaps, MPQs, and converted outputs out of Git.
- Re-run audits and document the result.

Current evidence:

- Bundle client MPQs are present under `/run/media/doodbro/New 1tb/AzerothCore/client/Data`.
- `Wow.exe` is present under `/run/media/doodbro/New 1tb/AzerothCore/client`.
- No Linux extractor binaries were found yet.
- CMake cache currently reports `TOOLS_BUILD=none`.

Checkpoint:

- Reconfigured `/home/doodbro/azeroth-build` with `TOOLS_BUILD=maps-only`.
- Built `map_extractor`, `vmap4_extractor`, `vmap4_assembler`, and `mmaps_generator`.
- Located the binaries under `/home/doodbro/azeroth-build/src/tools/`.
- Generated maps, DBC, VMaps, and MMaps from `/run/media/doodbro/New 1tb/AzerothCore/client`.
- Moved required runtime data into `/run/media/doodbro/New 1tb/AzerothCore/data`.
- Verified local runtime data counts: 5744 map files, 246 DBC files, 2794 VMap files, and 3780 MMap files.
- Removed the temporary `/run/media/doodbro/New 1tb/AzerothCore/client/Buildings` extractor scratch folder.
- Repaired `/run/media/doodbro/New 1tb/AzerothCore/scripts/start.sh` so desktop/background launches detach server processes, disable worldserver console mode for background runtime configs, and check real runtime-data file counts.
- Verified the local stack reaches live ports: MySQL `3306`, authserver `3724`, worldserver `8085`, Ollama `11434`, with the LLM bridge running.
- Worldserver logged `WORLD: World Initialized In 1 Minutes 1 Seconds` and `worldserver-daemon ready`.

## 2026-06-30 - Verify Dashboard Bridge Against Live Stack

Goal: prove the Godot dashboard path can see and control the now-running local AzerothCore stack through the localhost bridge.

Plan:

- Start the host control bridge.
- Verify bridge health and status against the live stack.
- Repair bridge startup if it does not survive background launch cleanup.
- Validate an idempotent bridge `start` request while the stack is already running.
- Validate the Godot dashboard scene loads headlessly with the bridge online.
- Record results in documentation.

Result:

- Found that the host bridge code worked in foreground, but the launcher needed the same detached-session repair as the server launcher.
- Updated `scripts/start_host_bridge.sh` to use a detached launch, clean stale PID files, and verify bridge health before success.
- Verified `tools/bridge_client.py health --compact` returns success.
- Verified `tools/bridge_client.py status --compact` sees MySQL `3306`, authserver `3724`, worldserver `8085`, Ollama `11434`, Docker, and runtime data ready.
- Verified `tools/bridge_client.py start --compact` succeeds while the stack is already running and reports the existing live ports.
- Verified `scripts/run_game.sh` loads the Godot 4.7 scene headlessly with the bridge online.

## 2026-06-30 - Begin Stage 02 Command Layer

Goal: route dashboard controls through named actions so future AzerothCore/Godot commands have one predictable command layer.

Plan:

- Add an action registry in the dashboard script.
- Route visible buttons through action IDs.
- Keep current status/start/stop/log/report/client behavior working.
- Add a restart action to the registry and UI.
- Document the action list and expected output behavior.
- Validate the Godot scene still loads.

Result:

- Added a `command_actions` registry in `scripts/companion_dashboard.gd`.
- Routed dashboard buttons through `_run_action`.
- Added the `restart_stack` action.
- Added `docs/command-layer.md`.
- Marked Stage 02 as in progress.
- Used local `qwen-agent:latest` as a bounded advisory reviewer on the GDScript diff; no code changes were needed from its review.
- Verified Godot 4.7 loads the scene headlessly after the refactor.

## 2026-06-30 - Complete Stage 03 Read-Only Data Browser

Goal: finish the read-only data browser stage, then pause before moving into the next stage.

Plan:

- Preserve Antigravity's plan-hardening updates and risk flags.
- Add a read-only data browser tool that runs `SELECT` queries only.
- Add a bridge endpoint and bridge client action for read-only data.
- Add Godot dashboard controls for view selection, search, limits, and result display.
- Document the tables, fields, endpoint, safety boundary, and validation.
- Validate against the live local stack.

Result:

- Added `tools/read_only_data_browser.py`.
- Added `GET /data` to `tools/host_control_bridge.py`.
- Added `data` to `tools/bridge_client.py`.
- Added a `Read-Only Data Browser` panel to the Godot dashboard.
- Added `docs/read-only-data-browser.md`.
- Marked Stage 02 complete and Stage 03 complete.
- Restored the Stage 17 master-plan link while preserving Antigravity's SRP6/RC4, asset-pipeline, and movement-desync risk notes.
- Used local `qwen-agent:latest` as a bounded advisory reviewer on the read-only data path and added bridge-side validation for data view, limit, and search length.
- Validated summary, account, character, online, creature, item, quest, and spell views.
- Validated bridge `data` calls against the live local stack.
- Validated Godot 4.7 loads the dashboard scene headlessly.
- Pausing here before Stage 04 per user instruction.

## 2026-07-01 - Complete Stage 15 Combat And Interaction Slice

Goal: prove Godot can target live AzerothCore world objects and send real interaction/combat packets without using the original client.

Plan:

- Parse live object GUIDs from `SMSG_UPDATE_OBJECT` and `SMSG_COMPRESSED_UPDATE_OBJECT`.
- Use live object GUIDs, not database spawn GUIDs, for targeting.
- Add an NPC interaction probe.
- Add a combat probe.
- Expose both probes to Godot and add a Stage 15 scene.
- Validate native and Godot paths against the live local stack.

Result:

- Added a minimal update-object create-block parser that recovers live object GUID, entry, type, position, orientation, and movement flags.
- Added spline-create skipping so the parser continues through larger live update packets.
- Added native `--npc-interaction` and `--combat-probe` commands.
- Added Godot native extension and script bridge methods for NPC interaction and combat probing.
- Added `scenes/interaction_combat_view.tscn` and the dashboard `Interact` action.
- Documented the live-GUID targeting correction in the Stage 15 and packet-spec docs.

Validation:

- `native/protocol_client/build/acore_protocol_client --self-test` passed.
- Native NPC interaction passed with `response_opcode=0x17d`.
- Native combat probe passed with `response_opcode=0x143`.
- `ACORE_ENTER_WORLD_SELF_TEST=1 godot-4 --headless --path . res://scenes/enter_world_view.tscn` passed.
- `ACORE_MOVEMENT_SELF_TEST=1 godot-4 --headless --path . res://scenes/movement_reconciliation_view.tscn` passed.
- `ACORE_OBJECT_VISIBILITY_SELF_TEST=1 godot-4 --headless --path . res://scenes/object_visibility_view.tscn` passed.
- `ACORE_INTERACTION_COMBAT_SELF_TEST=1 godot-4 --headless --path . res://scenes/interaction_combat_view.tscn` passed with `gossip_opcode=0x17d` and `combat_opcode=0x143`.

## 2026-07-01 - Start Stage 16 Client Feature March

Goal: make the full client feature parity target explicit before expanding the Godot client beyond movement, visibility, interaction, and combat probes.

Plan:

- Open Stage 16 as the active project stage.
- Add a dedicated parity matrix for the full client feature surface.
- Pick the first narrow feature slice.
- Keep the Stage 17 standard tied to a full Godot-native client, not a companion or partial runtime.

Result:

- Added `docs/client-feature-parity-matrix.md`.
- Marked Stage 16 as in progress.
- Updated the master plan's current status from the stale Stage 11 checkpoint to Stage 16.
- Selected chat as the first Stage 16 feature slice.

## 2026-07-01 - Complete Stage 16 First Chat Slice

Goal: prove Godot can send and receive an AzerothCore chat message through the WotLK world protocol without launching the original client.

Plan:

- Add `CMSG_MESSAGECHAT` packet building for a basic say message.
- Parse `SMSG_MESSAGECHAT` enough to recover sender, receiver, language, chat type, and message text.
- Add a native `--chat-say` probe.
- Expose chat through the Godot native extension and script bridge.
- Add a Godot chat scene with a headless self-test.
- Keep the slice generic and local-only with no proprietary assets or client data.

Result:

- Added `build_chat_say_payload` and `parse_chat_message_summary` in the native protocol packet layer.
- Added `acore_protocol::chat_say` and the `--chat-say` helper command.
- Added `AcoreProtocolClient.chat_say(...)` to the Godot extension.
- Added `ProtocolClientBridge.chat_say(...)`.
- Added `scenes/stage16_chat_view.tscn` and `scripts/stage16_chat_view.gd`.
- Added the dashboard `Chat` action.
- Updated the Stage 16 matrix and world-session packet spec.

Validation:

- `native/protocol_client/build/acore_protocol_client --self-test` passed.
- Native `--chat-say` passed with `response_opcode=0x96`, `chat_type=1`, `language=7`, and `echoed_message_seen=1`.
- `./tools/build_godot_protocol_extension_compat.sh` passed.
- `ACORE_CHAT_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage16_chat_view.tscn` passed with `CHAT_SELF_TEST_OK response_opcode=0x096 chat_type=1 language=7`.
- Regression self-tests passed for enter-world, movement, object visibility, and interaction/combat when run sequentially.

## 2026-07-01 - Expand Stage 16 Chat With Self-Whisper

Goal: extend the chat slice beyond say-message by proving another `CMSG_MESSAGECHAT` variant and response path.

Plan:

- Add a whisper payload builder.
- Add a native self-whisper probe that targets the current local test character.
- Detect both `CHAT_MSG_WHISPER` and `CHAT_MSG_WHISPER_INFORM` responses.
- Expose self-whisper through the Godot extension and script bridge.
- Add a chat-scene mode selector and update the headless self-test to exercise both modes.

Result:

- Added `build_chat_whisper_payload`.
- Added `acore_protocol::chat_whisper_self` and the `--chat-whisper-self` helper command.
- Added `AcoreProtocolClient.chat_whisper_self(...)`.
- Added `ProtocolClientBridge.chat_whisper_self(...)`.
- Updated `scripts/stage16_chat_view.gd` with Say and Whisper Self modes.
- Updated the Stage 16 matrix and packet spec.

Validation:

- `native/protocol_client/build/acore_protocol_client --self-test` passed.
- Native `--chat-whisper-self` passed with `whisper_seen=1`, `whisper_inform_seen=1`, `chat_type=9`, and `language=0`.
- `./tools/build_godot_protocol_extension_compat.sh` passed.
- `ACORE_CHAT_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage16_chat_view.tscn` passed with `say_opcode=0x096`, `whisper_opcode=0x096`, `whisper_seen=true`, and `whisper_inform_seen=true`.

## 2026-07-01 - Add Stage 16 Initial Spellbook Slice

Goal: prove Godot can receive the server-provided initial spellbook from AzerothCore during login.

Plan:

- Parse `SMSG_INITIAL_SPELLS`.
- Add a native spellbook probe.
- Expose spellbook data through the Godot extension and script bridge.
- Add a Godot spellbook scene with a headless self-test.
- Keep the slice read-only; do not cast spells yet.

Result:

- Added `InitialSpellsSummary` and `parse_initial_spells_summary`.
- Added `acore_protocol::read_initial_spellbook` and the `--spellbook` helper command.
- Added `AcoreProtocolClient.spellbook(...)`.
- Added `ProtocolClientBridge.spellbook(...)`.
- Added `scenes/stage16_spellbook_view.tscn` and `scripts/stage16_spellbook_view.gd`.
- Added the dashboard `Spellbook` action.
- Updated the Stage 16 matrix and packet spec.

Validation:

- `native/protocol_client/build/acore_protocol_client --self-test` passed.
- Native `--spellbook` passed with `initial_spells_seen=1`, `logged_in_world=1`, `spell_count=48`, and `cooldown_count=0`.
- `./tools/build_godot_protocol_extension_compat.sh` passed.
- `ACORE_SPELLBOOK_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage16_spellbook_view.tscn` passed with `spells=48`.
- `ACORE_CHAT_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage16_chat_view.tscn` still passed.

## 2026-07-01 - Add Stage 16 Initial Action-Bar Slice

Goal: prove Godot can receive and display AzerothCore's server-provided initial action buttons during login.

Plan:

- Parse `SMSG_ACTION_BUTTONS`.
- Add a native action-button probe.
- Expose action-button data through the Godot extension and script bridge.
- Add a Godot action-bar scene with a headless self-test.
- Keep the slice read-only; do not edit action buttons or cast from them yet.

Result:

- Added `ActionButtonsSummary` and `parse_action_buttons_summary`.
- Added `acore_protocol::read_action_buttons` and the `--action-buttons` helper command.
- Added `AcoreProtocolClient.action_buttons(...)`.
- Added `ProtocolClientBridge.action_buttons(...)`.
- Added `scenes/stage16_action_bar_view.tscn` and `scripts/stage16_action_bar_view.gd`.
- Added the dashboard `Action Bar` action.
- Updated the Stage 16 matrix and packet spec.

Validation:

- `cmake --build native/protocol_client/build` passed.
- `native/protocol_client/build/acore_protocol_client --self-test` passed.
- Native `--action-buttons` passed with `action_buttons_seen=1`, `logged_in_world=1`, `state=1`, `slot_count=144`, and `populated_count=3`.
- `./tools/build_godot_protocol_extension_compat.sh` passed.
- `ACORE_ACTION_BAR_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage16_action_bar_view.tscn` passed with `slots=144`, `populated=3`, and `state=1`.
- `ACORE_SPELLBOOK_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage16_spellbook_view.tscn` still passed with `spells=48`.
- `ACORE_CHAT_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage16_chat_view.tscn` still passed with say and self-whisper responses.
- Local `qwen-agent` advisory review found no concrete blockers for the bounded action-bar slice.

## 2026-07-01 - Add Stage 16 Spell-Cast Slice

Goal: prove Godot can send a real client spell-cast opcode to AzerothCore and parse the accepted server response.

Plan:

- Add a minimal `CMSG_CAST_SPELL` payload builder.
- Parse the first cast response opcodes: `SMSG_CAST_FAILED`, `SMSG_SPELL_START`, `SMSG_SPELL_GO`, `SMSG_SPELL_FAILURE`, and `SMSG_SPELL_FAILED_OTHER`.
- Add a native spell-cast probe.
- Expose spell casting through the Godot extension and script bridge.
- Add a Godot spell-cast scene with a headless self-test.
- Use a safe no-target local spell first; do not implement targeted combat casting yet.

Result:

- Added `build_cast_spell_payload` and `parse_spell_cast_response`.
- Added `acore_protocol::cast_spell_probe` and the `--cast-spell` helper command.
- Added `AcoreProtocolClient.cast_spell(...)`.
- Added `ProtocolClientBridge.cast_spell(...)`.
- Added `scenes/stage16_spell_cast_view.tscn` and `scripts/stage16_spell_cast_view.gd`.
- Added the dashboard `Cast Spell` action.
- Fixed the initial spellbook parser to tolerate AzerothCore cooldown counts that are larger than the serialized cooldown rows.
- Updated the Stage 16 matrix and packet spec.

Validation:

- `cmake --build native/protocol_client/build` passed.
- `native/protocol_client/build/acore_protocol_client --self-test` passed.
- Native `--cast-spell` passed for spell `2457` with `accepted=1`, `response_opcode=0x132`, and `response_spell_id=2457`.
- Native cast-then-spellbook regression passed; the spellbook reported `cooldown_count=1` immediately after casting.
- `./tools/build_godot_protocol_extension_compat.sh` passed.
- `ACORE_SPELL_CAST_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage16_spell_cast_view.tscn` passed with `spell_id=2457`, `opcode=0x132`, and `accepted=true`.
- `ACORE_ACTION_BAR_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage16_action_bar_view.tscn` still passed with `slots=144` and `populated=3`.
- `ACORE_SPELLBOOK_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage16_spellbook_view.tscn` still passed with `spells=48` and `cooldowns=1` immediately after casting.
- `ACORE_CHAT_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage16_chat_view.tscn` still passed with say and self-whisper responses.
- Local `qwen-agent` advisory review found no concrete blockers for the bounded spell-cast slice.

## 2026-07-01 - Add Stage 16 Targeted Spell-Cast Slice

Goal: prove Godot can select a live AzerothCore unit and send a real unit-target spell-cast packet.

Plan:

- Add a `CMSG_CAST_SPELL` builder for `TARGET_FLAG_UNIT`.
- Add a native targeted spell-cast probe that reuses the live object parser from Stage 15.
- Select and attack a nearby creature before casting so the server has the same basic context a normal client would create.
- Expose targeted casting through the Godot extension and script bridge.
- Extend the spell-cast scene with a target mode and a headless targeted self-test.

Result:

- Added `build_cast_spell_unit_payload`.
- Added `acore_protocol::cast_spell_at_target_probe` and the `--cast-spell-target` helper command.
- Added `AcoreProtocolClient.cast_spell_at_target(...)`.
- Added `ProtocolClientBridge.cast_spell_at_target(...)`.
- Extended `scripts/stage16_spell_cast_view.gd` with no-target and unit-target modes.
- Updated the Stage 16 matrix and packet spec.

Validation:

- `cmake --build native/protocol_client/build` passed.
- `native/protocol_client/build/acore_protocol_client --self-test` passed.
- Native `--cast-spell-target` passed for spell `78` against nearby creature entry `721` with `live_target_found=1`, `selection_sent=1`, `attack_sent=1`, `cast_sent=1`, `accepted=1`, `response_opcode=0x131`, and `response_spell_id=78`.
- `./tools/build_godot_protocol_extension_compat.sh` passed.
- `ACORE_TARGETED_SPELL_CAST_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage16_spell_cast_view.tscn` passed with `spell_id=78`, `target_entry=721`, `opcode=0x131`, and `accepted=true`.
- `ACORE_SPELL_CAST_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage16_spell_cast_view.tscn` still passed with `spell_id=2457`, `opcode=0x132`, and `accepted=true`.
- `ACORE_ACTION_BAR_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage16_action_bar_view.tscn` still passed with `slots=144` and `populated=3`.
- `ACORE_SPELLBOOK_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage16_spellbook_view.tscn` still passed with `spells=48` and `cooldowns=1`.
- `ACORE_CHAT_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage16_chat_view.tscn` still passed with say and self-whisper responses.
- Local `qwen-agent` advisory review found no concrete blockers for the bounded targeted spell-cast slice.

## 2026-07-01 - Add Stage 16 Action-Button Cast Slice

Goal: prove Godot can use a server-provided action-bar spell slot as a playable cast command.

Plan:

- Render all 144 server-provided action slots instead of only the first visible page.
- Make populated spell slots clickable in the Godot action-bar scene.
- Route spell action `78` through the targeted spell-cast path so button `73` can cast against a live nearby creature.
- Add a headless Godot self-test for action-button casting.

Result:

- Updated `scripts/stage16_action_bar_view.gd` to render all 144 slots.
- Replaced static populated-slot panels with clickable buttons for spell actions.
- Added target controls for the current unit-target cast probe.
- Added `ACORE_ACTION_BAR_CAST_SELF_TEST=1` support.

Validation:

- `ACORE_ACTION_BAR_CAST_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage16_action_bar_view.tscn` passed with `button=73`, `spell_id=78`, `opcode=0x131`, and `accepted=true`.
- Local `qwen-agent` advisory review found no concrete blockers for the bounded action-button cast slice.

## 2026-07-01 - Add Stage 16 Set-Action-Button Slice

Goal: prove Godot can send `CMSG_SET_ACTION_BUTTON` and verify the server persisted the action-bar edit, while restoring the test character afterward.

Plan:

- Confirm the AzerothCore handler payload order from source.
- Add a packet builder for `button + packed action/type`.
- Add a native reversible set-action-button probe.
- Expose the probe through the Godot extension and script bridge.
- Extend the action-bar scene with a set-slot control and headless set/restore self-test.

Result:

- Added `build_set_action_button_payload`.
- Added `acore_protocol::set_action_button_probe` and the `--set-action-button` helper command.
- Added `AcoreProtocolClient.set_action_button(...)`.
- Added `ProtocolClientBridge.set_action_button(...)`.
- Extended `scripts/stage16_action_bar_view.gd` with reversible set-slot controls and `ACORE_ACTION_BAR_SET_SELF_TEST=1`.

Validation:

- `cmake --build native/protocol_client/build` passed.
- `native/protocol_client/build/acore_protocol_client --self-test` passed.
- Native `--set-action-button` passed by setting slot `0` to spell `78`, confirming `set_confirmed=1`, restoring the original empty slot, and confirming `restore_confirmed=1`.
- `./tools/build_godot_protocol_extension_compat.sh` passed.
- `ACORE_ACTION_BAR_SET_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage16_action_bar_view.tscn` passed with `button=0`, `action=78`, `type=0`, `set_confirmed=true`, and `restore_confirmed=true`.
- `ACORE_ACTION_BAR_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage16_action_bar_view.tscn` passed afterward with `slots=144` and `populated=3`, confirming the test character was restored.
- Local `qwen-agent` advisory review found no concrete blockers for the bounded set-action-button slice.

## 2026-07-01 - Add Stage 16 Combat Damage Parser Slice

Goal: move combat beyond attack-start acknowledgement by parsing live AzerothCore melee damage state in Godot.

Plan:

- Add `SMSG_ATTACKERSTATEUPDATE` parsing for hit info, attacker/target GUIDs, total damage, overkill, sub-damage rows, target state, attacker state, melee spell id, blocked amount, and conditional absorb/resist/rage/debug fields.
- Answer `SMSG_TIME_SYNC_REQ` with `CMSG_TIME_SYNC_RESP` before movement-sensitive probes.
- Improve the combat probe so it approaches and faces the target before attacking.
- Keep listening through `SMSG_ATTACKSTART` and `SMSG_ATTACKSTOP` markers until a damage update arrives or the bounded combat wait expires.
- Expose parsed combat damage through the Godot extension and script bridge.
- Use a stable hostile target in the Godot interaction/combat scene self-test.

Result:

- Added `parse_attacker_state_update`.
- Added time-sync response packet support.
- Expanded `CombatProbeResult` with target position, approach/return movement flags, and parsed attacker-state data.
- Updated the CLI `--combat-probe` output with parsed damage fields.
- Updated `AcoreProtocolClient.combat_probe(...)` and `ProtocolClientBridge.combat_probe(...)`.
- Updated `scripts/interaction_combat_view.gd` to show parsed damage and to use entry `38` for the combat self-test instead of the fragile one-hit rabbit entry.
- Updated the Stage 16 matrix, Stage 16 stage notes, and world-session packet spec.

Validation:

- `cmake --build native/protocol_client/build` passed.
- `native/protocol_client/build/acore_protocol_client --self-test` passed.
- Native `--combat-probe` against hostile entry `69` passed with `attacker_state_update_seen=1`, `response_opcode=0x14a`, `hit_info=0x10002`, `total_damage=3`, `overkill=0`, and `target_state=1`.
- Native `--combat-probe` against stationary hostile entry `38` passed with `attacker_state_update_seen=1`, `response_opcode=0x14a`, and parsed block/damage fields.
- `./tools/build_godot_protocol_extension_compat.sh` passed.
- `ACORE_INTERACTION_COMBAT_SELF_TEST=1 godot-4 --headless --path . res://scenes/interaction_combat_view.tscn` passed with `gossip_opcode=0x17d`, `combat_opcode=0x14a`, `damage=2`, and `attacker_state=true`.
- Final rebuilt-extension pass for the same Godot scene passed with `damage=3` and `attacker_state=true`.
- `ACORE_CHAT_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage16_chat_view.tscn` passed.
- `ACORE_SPELLBOOK_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage16_spellbook_view.tscn` passed with `spells=48`.
- `ACORE_ACTION_BAR_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage16_action_bar_view.tscn` passed with `slots=144` and `populated=3`.
- `ACORE_ACTION_BAR_SET_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage16_action_bar_view.tscn` passed with set/restore confirmation.
- `godot-4 --headless --path . --quit` passed.
- Local `qwen-agent` advisory review was checked; no actionable blocker was confirmed for this bounded combat-damage slice.

## 2026-07-01 - Add Stage 17 Read-Only Inventory Snapshot Slice

Goal: begin Stage 17 full-port gate work by exposing real server-owned inventory slot state in Godot.

Plan:

- Extend the update-object parser so it reads value update masks into field/value pairs.
- Map AzerothCore player private fields for equipment slots, bag slots, backpack slots, and coinage.
- Add a native inventory snapshot flow and helper command.
- Expose the snapshot through the Godot extension and script bridge.
- Add a Godot inventory scene with a 39-slot equipment/bag/backpack grid and a headless self-test.
- Document the slice honestly as read-only item GUID visibility, not full inventory parity.

Result:

- Added `PlayerInventorySummary` and per-slot inventory summaries.
- Added `read_inventory_snapshot` and `--inventory-snapshot`.
- Added `AcoreProtocolClient.inventory_snapshot(...)` and `ProtocolClientBridge.inventory_snapshot(...)`.
- Added `scenes/stage17_inventory_view.tscn` and `scripts/stage17_inventory_view.gd`.
- Updated the parity matrix, Stage 17 gate document, and world-session packet spec.

Validation:

- `cmake --build native/protocol_client/build` passed.
- `native/protocol_client/build/acore_protocol_client --self-test` passed, including synthetic inventory field parsing.
- Native `--inventory-snapshot` passed for `Codexstage` with `inventory_seen=1`, `logged_in_world=1`, `slot_count=39`, and `populated_count=7`.
- `./tools/build_godot_protocol_extension_compat.sh` passed.
- `ACORE_INVENTORY_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage17_inventory_view.tscn` passed with `slots=39`, `populated=7`, and `coinage=0`.
- `godot-4 --headless --path . --quit` passed.
- Local `qwen-agent` advisory review produced only generic checklist items; no actionable blocker was confirmed after checking parser bounds, field indexing, bridge shape, and self-test coverage.

## 2026-07-01 - Add Stage 17 Inventory Item Details Slice

Goal: upgrade the Stage 17 inventory scene from GUID-only slot visibility to read-only item details resolved from the live AzerothCore protocol stream.

Plan:

- Parse inventory item object update fields for item entry, stack count, durability, and max durability.
- Keep inventory item objects out of the general nearby-visible-object list so equipped/backpack items do not masquerade as world actors.
- Query item templates for discovered entries with `CMSG_ITEM_QUERY_SINGLE`.
- Parse `SMSG_ITEM_QUERY_SINGLE_RESPONSE` early fields for item names and display metadata.
- Surface detail counts and resolved-name counts through the native CLI, Godot extension, GDScript bridge, and Stage 17 inventory scene.
- Rebuild the Godot extension and rerun native/live/Godot checks.

Result:

- Added item-object detail parsing to `parse_update_object_summary`.
- Added item-template query building and response parsing.
- Updated `read_inventory_snapshot` to wait for item details, query templates, and merge names into matching slots.
- Updated CLI, Godot extension, bridge, and `stage17_inventory_view.gd` output to show item entry, stack count, durability, and names.
- Updated the feature parity matrix, Stage 17 gate notes, and packet spec.

Validation:

- `cmake --build native/protocol_client/build` passed.
- `native/protocol_client/build/acore_protocol_client --self-test` passed, including synthetic item-object and item-template parsing.
- Native `--inventory-snapshot` passed for `Codexstage` with `inventory_seen=1`, `logged_in_world=1`, `slot_count=39`, `populated_count=7`, `item_detail_count=7`, and `item_template_count=7`.
- `./tools/build_godot_protocol_extension_compat.sh` passed.
- `ACORE_INVENTORY_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage17_inventory_view.tscn` passed with `slots=39`, `populated=7`, `details=7`, and `names=7`.
- `godot-4 --headless --path . --quit` passed.
- Local `qwen-agent` advisory review produced only generic checklist reminders; no actionable blocker was confirmed after live and Godot validation.

## 2026-07-01 - Add Stage 17 Reversible Inventory Move Slice

Goal: prove the Godot client path can perform a real inventory mutation against AzerothCore and then safely restore the test character state.

Plan:

- Add `CMSG_SWAP_INV_ITEM` packet support with the AzerothCore read order: destination slot first, source slot second.
- Build a native probe that snapshots inventory before the move, moves base-backpack slot `23` to slot `25`, rereads the server state, restores slot `25` to slot `23`, and rereads again.
- Expose the same probe through the Godot extension and script bridge.
- Add a `Test Move` control and headless self-test path to the Stage 17 inventory scene.
- Document the port milestone as the first reversible inventory action, while keeping full inventory parity gaps visible.

Result:

- Added `--swap-inventory-slots` to the native protocol helper.
- Added `InventorySwapProbeResult` and restore-aware confirmation logic.
- Added `AcoreProtocolClient.swap_inventory_slots(...)` and `ProtocolClientBridge.swap_inventory_slots(...)`.
- Updated `scenes/stage17_inventory_view.tscn` / `scripts/stage17_inventory_view.gd` to run the reversible move and refresh the inventory view.
- Updated the feature parity matrix, Stage 17 gate notes, and world-session packet spec.

Validation:

- `cmake --build native/protocol_client/build` passed.
- `native/protocol_client/build/acore_protocol_client --self-test` passed, including the `CMSG_SWAP_INV_ITEM` packet byte-order check.
- `./tools/build_godot_protocol_extension_compat.sh` passed.
- Native `--swap-inventory-slots` passed for `Codexstage` with `before_seen=1`, `swap_confirmed=1`, and `restore_confirmed=1` for slots `23` and `25`.
- `ACORE_INVENTORY_SWAP_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage17_inventory_view.tscn` passed with `swap_confirmed=true` and `restore_confirmed=true`.
- `ACORE_INVENTORY_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage17_inventory_view.tscn` still passed with `slots=39`, `populated=7`, `details=7`, and `names=7`.
- `godot-4 --headless --path . --quit` passed.
- Local `qwen-agent` advisory review returned only general checklist reminders; no actionable blocker was confirmed after live native and Godot validation.

## 2026-07-01 - Add Stage 17 Reversible Equipment Unequip Slice

Goal: extend the Stage 17 inventory mutation path from backpack-only movement into a safe equipment unequip/restore proof.

Plan:

- Reuse the generic `--swap-inventory-slots` / `swap_inventory_slots(...)` path with equipment source slot `15` and empty backpack destination slot `26`.
- Prove natively that AzerothCore accepts the equipment-to-backpack move and restore.
- Add a visible `Test Unequip` control to the Stage 17 inventory scene.
- Add a headless equipment self-test path for the Godot scene.
- Document this as the first equipment mutation milestone, not full equipment parity.

Result:

- Confirmed native unequip/restore works for `Codexstage` slot `15` to slot `26`.
- Updated `scripts/stage17_inventory_view.gd` with a second reversible mutation control and `ACORE_EQUIPMENT_SWAP_SELF_TEST=1`.
- Updated the feature parity matrix, Stage 17 gate notes, world-session packet spec, and task log.

Validation:

- Native `--swap-inventory-slots` passed for `Codexstage` with `before_seen=1`, `swap_confirmed=1`, and `restore_confirmed=1` for slots `15` and `26`.
- `ACORE_EQUIPMENT_SWAP_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage17_inventory_view.tscn` passed with `swap_confirmed=true` and `restore_confirmed=true`.
- `ACORE_INVENTORY_SWAP_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage17_inventory_view.tscn` still passed with `swap_confirmed=true` and `restore_confirmed=true`.
- `ACORE_INVENTORY_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage17_inventory_view.tscn` still passed with `slots=39`, `populated=7`, `details=7`, and `names=7`.
- `godot-4 --headless --path . --quit` passed.
- Local `qwen-agent` advisory review returned only checklist reminders; no actionable blocker was confirmed after the native and Godot validations.
