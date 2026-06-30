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
