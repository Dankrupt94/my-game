# UI Parity Worklog (Godot UI lane)

This is the shared worklog for the Godot UI view layer. It is kept separate
from `docs/task-log.md` so the two agents do not clobber each other's
documentation. See the lane split in the header of this file.

## Agent Lanes

**Lanes were swapped on 2026-07-01** (see
`docs/agent-coordination-requests.md`). Current assignment:

- **Claude lane (now):** native/protocol — `native/`,
  `scripts/protocol_client_bridge.gd`, the `stage17_*` live-protocol scenes, and
  protocol docs (`task-log.md`, `stage-17-full-port-acceptance-gate.md`,
  `world-session-packet-spec.md`, `wotlk_client_parity_engine_spec.md`).
- **Codex lane (now):** the Godot UI view layer — `scripts/*_view.gd` +
  `scenes/*_view.tscn` (non-`stage17_*`) and their dashboard/`project.godot`
  wiring.
- The entries below the swap line (intake of the UI view layer) were done by
  Claude while it still held the UI lane.
- **Git hygiene:** each agent stages only its own explicit paths (never
  `git add -A`/`-am`) and commits in small chunks. Verified working: Codex and
  Claude commits interleaved on `main` with no conflicts.

## 2026-07-01 - World Session HUD Panels (Codex UI lane)

Context: the world-session shell had buttons for chat, spells, actions, quests,
and options, but those buttons still left the session shell for separate proof
scenes. A playable client needs those surfaces to live inside the active world
view.

Result:

- `scripts/world_session_view.gd` now opens Chat, Spells, Actions, Quests, and
  Options as in-world HUD panels.
- Roster and Dashboard remain explicit scene navigation buttons.
- Added a 12-slot bottom action strip inside the world-session HUD for primary
  action, interact, target, panel toggles, reset, and jump.
- The Actions panel reflects current visible-object and target state; the
  Options panel reads saved keybindings through `SettingsRuntime`.
- This remains UI-lane work only. The panels do not call the protocol bridge or
  take ownership of Claude's persistent live-session lane.

Validation:

- `ACORE_WORLD_SESSION_SELF_TEST=1 godot-4 --headless --path . --scene
  res://scenes/world_session_view.tscn` now validates 7 navigation buttons, 12
  HUD shortcut slots, and Chat/Actions panel creation.
- `ACORE_WORLD_SESSION_KEYBIND_SELF_TEST=1 godot-4 --headless --path . --scene
  res://scenes/world_session_view.tscn` still validates saved keybinding
  consumption.

Remaining work:

- Feed live chat, spellbook, action-button, quest, inventory, vendor, trainer,
  and combat data into these panels once the persistent session bridge is ready.
- Add draggable/movable panel layout persistence and full action-bar paging.

## 2026-07-01 - World Session Keybinding Input (Codex UI lane)

Context: the world-session shell was reachable after character select, but its
marker/camera still used Godot's generic UI arrow actions. The next UI-only
step was to make the shell consume the same saved keybindings as the options
menu and gameplay sandbox, without touching the native/protocol/live-session
lane that Claude is editing.

Result:

- `scripts/world_session_view.gd` now applies saved `SettingsRuntime`
  keybindings at startup.
- Marker movement uses `move_forward`, `move_backward`, `move_left`, and
  `move_right`; camera yaw uses `camera_left` and `camera_right`.
- Target-next, primary action, interact, reset, and jump keys now update HUD
  state in the world-session shell. These are UI feedback hooks only; they do
  not send protocol packets or modify the live bridge.
- Reset returns the marker to the last server-reported position captured from
  `SessionContext`.

Validation:

- `ACORE_WORLD_SESSION_SELF_TEST=1 godot-4 --headless --path . --scene
  res://scenes/world_session_view.tscn` validates the shell with synthetic
  session data plus target/action/interact/reset feedback.
- `ACORE_WORLD_SESSION_KEYBIND_SELF_TEST=1 godot-4 --headless --path . --scene
  res://scenes/world_session_view.tscn` validates saved keybinding consumption
  for movement, camera, target, action, interact, reset, and jump actions.

Remaining work:

- Replace HUD-only action feedback with live target, combat, interaction, and
  movement execution once the persistent world-session bridge is ready.
- Add mouse-look, camera sensitivity, UI scale, and complete action-bar keybind
  integration.

## 2026-07-01 - World Session Shell (Codex UI lane)

Context: the login and character-select UI can now authenticate, fetch a roster,
and call `enter_world`. The next UI gap was that a successful enter-world still
returned to the dashboard instead of landing in a game-facing session surface.

Result:

- Added `scenes/world_session_view.tscn` and `scripts/world_session_view.gd`.
- Successful character-select enter-world now routes to the world-session shell.
- The shell reads `SessionContext.selected_character` and
  `SessionContext.last_enter_world_result`, renders the selected character name,
  map, server-reported coordinates, visible-object count when present, a 3D
  marker/grid, basic HUD bars, and panel navigation buttons.
- The dashboard now has a `World Session` button for manual inspection.

Validation:

- `ACORE_WORLD_SESSION_SELF_TEST=1 godot-4 --headless --path . --scene
  res://scenes/world_session_view.tscn` validates the shell with synthetic
  session data.
- `ACORE_GAME_LOGIN_LIVE_SELF_TEST=1` still authenticated typed credentials and
  carried 1 character after the new world-session routing.
- `ACORE_CHARACTER_SELECT_LIVE_SELF_TEST=1` still fetched 1 live character and
  entered world as the selected character after the new world-session routing.

Remaining work:

- Keep one persistent authenticated protocol session alive after enter-world
  instead of using one-shot bridge probes.
- Replace the marker shell with server-synchronized movement, object spawning,
  click targeting, and integrated HUD panels.
- Move chat, spellbook, action bars, inventory, questing, vendors, trainers, and
  combat from separate proof scenes into this session shell.

## 2026-07-01 - Login Session Handoff (Codex UI lane)

Context: Claude added optional account/password bridge parameters in the
native/protocol lane. Codex stayed in the UI lane and wired the login and
character-select screens to use those parameters without editing
`scripts/protocol_client_bridge.gd`.

Result:

- Added `scripts/session_context.gd` as an autoloaded in-memory runtime handoff.
- `game_login_view` now collects host, port, account, and password, calls
  `ProtocolClientBridge.run_character_flow(host, port, account, password)`, and
  only advances to character select after an authenticated roster result.
- `character_select_view` consumes the roster from `SessionContext`, can refetch
  the roster with the same typed credentials, normalizes native-extension
  dictionaries and helper-process `CHAR ...` rows, and passes typed credentials
  into `enter_world`.
- The password remains runtime-only; it is not written to disk or printed.

Validation:

- `ACORE_GAME_LOGIN_SELF_TEST=1 godot-4 --headless --path . --scene
  res://scenes/game_login_view.tscn` passed with synthetic credentials and
  in-memory roster handoff.
- `ACORE_CHARACTER_SELECT_SELF_TEST=1 godot-4 --headless --path . --scene
  res://scenes/character_select_view.tscn` passed, including selected-character
  handoff for enter-world.
- `godot-4 --headless --path . --quit` loaded clean.
- With ignored local runtime/build outputs linked into the temporary worktree
  for validation only, `ACORE_GAME_LOGIN_LIVE_SELF_TEST=1` authenticated typed
  credentials and carried 1 character to the next screen.
- With the same temporary local-only links, `ACORE_CHARACTER_SELECT_LIVE_SELF_TEST=1`
  fetched 1 live character and entered world as the selected character.

Remaining work:

- Native/protocol lane: add typed-account support for character creation if
  normal account-driven character creation is kept in this UI.
- UI lane: route successful enter-world into the persistent gameplay HUD/session
  instead of returning to the dashboard.

## 2026-07-01 - Bridge accepts login credentials (native/protocol lane)

- `run_character_flow` / `enter_world` gained optional `account`/`password`
  params (commit `3672d9c`). Non-empty → drive auth on both the native-extension
  and helper-process paths; empty → unchanged file-driven behavior.
- Verified live against the running server: file path `ok=true`, override path
  `ok=true` (same roster), bad-override creds `ok=false`.
- Unblocks the UI lane's login → roster → enter-world flow (see the UI-lane
  follow-up in `docs/agent-coordination-requests.md`).

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
