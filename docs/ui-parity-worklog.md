# UI Parity Worklog (Claude lane)

This is the Claude agent's worklog for the Godot UI view layer. It is kept
separate from `docs/task-log.md` (maintained by Codex on the native/protocol
lane) so the two agents do not clobber each other's documentation. See the
lane split in the header of this file.

## Agent Lanes

- **Codex lane:** `native/`, `scripts/protocol_client_bridge.gd`, the
  `stage17_*` live-protocol scenes, and Codex's docs (`task-log.md`,
  `stage-17-full-port-acceptance-gate.md`, `world-session-packet-spec.md`,
  `wotlk_client_parity_engine_spec.md`).
- **Claude lane:** the Godot UI view layer — `scripts/*_view.gd` +
  `scenes/*_view.tscn` (non-`stage17_*`), their dashboard/`project.godot`
  wiring, and this worklog.
- **Git hygiene:** each agent stages only its own explicit paths (never
  `git add -A`/`-am`) and commits in small chunks. Verified working: Codex and
  Claude commits interleave on `main` with no conflicts.

## 2026-07-01 - Intake of Antigravity's parity UI view layer

Context: Antigravity (a third agent) built a batch of parity UI views, then ran
out of credits leaving the work uncommitted. Picked it up per owner request.

Result:

- Committed 13 view scenes/scripts: auction house, auras, character select,
  death/respawn, game login, group, guild, mailbox, minimap, quest, tooltip,
  trade, UI customizer (`98634d7`).
- Committed dashboard wiring + boot-to-login (`c2ff10d`).
- Committed parity matrix updates (`3e90a35`).

Validation:

- `godot-4 --headless --path . --quit` loaded clean (no parse/script errors).
- All 13 headless self-tests passed (each prints `<NAME>_SELF_TEST_OK`):
  `ACORE_AUCTION_HOUSE_SELF_TEST`, `ACORE_AURAS_SELF_TEST`,
  `ACORE_CHARACTER_SELECT_SELF_TEST`, `ACORE_DEATH_RESPAWN_SELF_TEST`,
  `ACORE_GAME_LOGIN_SELF_TEST`, `ACORE_GROUPS_SELF_TEST`,
  `ACORE_GUILD_SELF_TEST`, `ACORE_MAIL_SELF_TEST`, `ACORE_MINIMAP_SELF_TEST`,
  `ACORE_QUEST_SELF_TEST`, `ACORE_TOOLTIP_SELF_TEST`, `ACORE_TRADE_SELF_TEST`,
  `ACORE_UI_LAYOUT_SELF_TEST`.
- No proprietary assets committed (all 26 files are `.gd`/`.tscn` source).

Honest status: these self-tests verify **UI-simulation** logic, not live-server
protocol. Only `character_select_view.gd` touches the live bridge; the other 12
are self-contained simulations. The matrix rows marked "Complete" mean the UI
scaffold is complete, not that the feature is wired to a live world session.

Remaining work (real parity gap):

- Wire the simulated views to live data. Read-only surfaces first, using bridge
  methods that already exist, before requesting new bridge/native methods from
  the Codex lane.
- Deepen WotLK visual fidelity of each view.
- Build toward a persistent-session HUD that hosts these panels instead of
  one-off dashboard scenes.
