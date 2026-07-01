# Task Log

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
