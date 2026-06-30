# Stage 09 - Path A Completion Gate

Status: Complete

## Goal

Decide whether Path A is achieved and whether the project is ready to begin Path B.

Path A is a readiness gate, not a product fork. A companion dashboard, original sandbox, or Godot-native multiplayer proof does not satisfy the full WotLK port goal by itself.

## Path A Completion Requirements

- Companion dashboard works.
- Safe command layer works.
- Local bridge service works.
- Godot can inspect safe AzerothCore data.
- Godot has an original playable sandbox.
- Godot-native multiplayer works locally.
- Godot persistence works.
- Documentation is current.

## Decision

Only after this stage is complete should the project begin Path B protocol-client work. The expected decision is "begin Path B" once the checklist is complete, unless the user explicitly changes the mission.

Decision on 2026-06-30: Path A is complete enough to begin Path B.

The next stage is Stage 10, protocol research. This decision does not reduce the final goal. The project still targets a full Godot-native WotLK client/port, not a dashboard, not a lightweight companion, and not an original reimagining.

## Done Criteria

- A written decision is added to this file.
- Missing Path A work is either complete or intentionally deferred.
- Risks for Path B are documented.

## Gate Review Start

Started on 2026-06-30.

This review checks whether Path A has achieved its intended purpose: a safe Godot-side engine layer, a local bridge boundary, read-only AzerothCore data inspection, an original playable sandbox, local multiplayer proof, and ignored local persistence.

The review must not mistake Path A for the final product. The final project goal remains a full Godot-native WotLK client/port that can replace the original WotLK client for normal play against AzerothCore as completely as possible.

## Completion Checklist

- [x] Companion dashboard works.
  - `scripts/run_game.sh` launched `res://main.tscn` headlessly through Godot 4.7 with the host bridge online.
  - Stage 01 is marked complete after validating dashboard launch and stop/start stack control.
- [x] Safe command layer works.
  - Dashboard commands route through named actions and bridge requests instead of raw scattered shell calls.
- [x] Local bridge service works.
  - `GET /status`, `GET /data`, token-gated `POST /start`, token-gated `POST /stop`, and token-gated `POST /client/launch` are implemented.
  - Unauthorized mutating requests were validated in Stage 04.
- [x] Godot can inspect safe AzerothCore data.
  - `tools/bridge_client.py data --view summary --compact --timeout 35` returned realm and count data from the live local stack.
  - Godot sandbox data self-test printed `SANDBOX_DATA_SELF_TEST_OK`.
- [x] Godot has an original playable sandbox.
  - `scenes/gameplay_sandbox.tscn` provides original placeholder gameplay, targeting, NPC/enemy placeholders, task state, HUD values, and return navigation.
- [x] Godot-native multiplayer works locally.
  - `tools/run_multiplayer_smoke_test.py` launched one headless server and two headless clients and printed `MULTIPLAYER_SMOKE_TEST_OK`.
- [x] Godot persistence works.
  - `ACORE_SANDBOX_PERSISTENCE_SELF_TEST=1` printed `SANDBOX_PERSISTENCE_SELF_TEST_OK`.
  - Persistence remains under ignored `local_runtime/sandbox-state.json` and does not write to AzerothCore core tables.
- [x] Documentation is current.
  - Stage files, the master plan, and the task log describe the current Path A status and Stage 10 handoff.

## Gate Validation

Completed on 2026-06-30:

- Bridge status returned live MySQL `3306`, authserver `3724`, worldserver `8085`, and Ollama `11434`.
- Bridge data summary returned real local AzerothCore counts for accounts, characters, templates, quests, and spells.
- Python compile checks passed for the bridge/data/smoke-test tools.
- `git diff --check` passed.
- Tracked-file guard found no MPQ, map, DBC, BLP, M2, WMO, ADT, WDT, WDL, local report, local runtime, or log files in Git.
- Dashboard headless launch passed.
- Gameplay sandbox data self-test passed.
- Gameplay sandbox persistence self-test passed.
- Multiplayer smoke test passed.

## Restart Validation Finding

During this gate, the full bridge stop/start flow exposed an operational issue in the local AzerothCore `scripts/start.sh`: the script tried to create a new Docker container when `ac-mysql` already existed but was stopped.

The local script was repaired outside this companion Git repo so it starts an existing stopped `ac-mysql` container before attempting `docker run`. After the repair, the stack returned to live ports for MySQL, authserver, worldserver, and Ollama.

This is a local stack operations fix, not proprietary asset work.

## Deferred Path A Work

These items are intentionally deferred and do not block Path B:

- Add richer interpolation, cooldown, range, reconnect, and disconnect handling to the Godot-native multiplayer prototype.
- Replace fixed sandbox creature placeholder positions with data from real spawn tables.
- Add friendlier race/class/item/quest labels and deeper data mapping.
- Migrate sandbox persistence from one ignored JSON file to SQLite if the save model grows.
- Add visual screenshots to documentation when a UI capture pass becomes useful.

## Path B Risk Register

Path B must explicitly manage:

- WotLK auth protocol details, including SRP6 challenge/proof math.
- World-server session proof and header encryption.
- WotLK build `12340` opcode boundaries and packet byte layouts.
- `SMSG_UPDATE_OBJECT` parsing and object visibility rules.
- Server-authoritative movement, prediction, reconciliation, and rubber-banding behavior.
- Faithful UI/UX behavior without using the original WotLK client as the player-facing runtime.
- Local-only proprietary asset conversion while keeping MPQs, extracted files, and converted derivatives out of Git/GitHub.
- Preventing accidental writes to AzerothCore `auth`, `characters`, or `world` tables until a stage explicitly allows them.

## Local AI Advisory Note

The local `qwen-agent:latest` model was used as a bounded advisory reviewer for this gate. It correctly highlighted multiplayer maturity, spawn positions, persistence migration, auth/world protocol work, object updates, and movement reconciliation as risks. The supervising decision is that the protocol, object update, and movement items are Path B work, not blockers for completing Path A.

## Documentation To Update During Work

- Completion checklist.
- Deferred work list.
- Path B go/no-go decision.
