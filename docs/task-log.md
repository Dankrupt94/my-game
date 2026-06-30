# Task Log

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
