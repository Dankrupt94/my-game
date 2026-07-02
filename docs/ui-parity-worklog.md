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

## 2026-07-02 - World Session Death And Respawn Panel Started (Codex UI lane)

Goal: add resident death, ghost, corpse-run, and resurrection status surfaces
to the active world-session HUD so safe live-session snapshots can display in
the normal gameplay view.

Scope:

- Stay in the UI lane by changing only the world-session view and UI docs.
- Render session-provided alive/dead/ghost state, release timers, corpse
  distance/position, resurrection offers, durability loss, and respawn health
  summaries without calling or editing the protocol bridge.
- Keep live death packets, release-spirit requests, graveyard teleport,
  corpse-respawn requests, resurrection accept/decline, and server failure
  states in Claude's live-session lane.

## 2026-07-02 - World Session Auction Panel (Codex UI lane)

Context: the Stage 17 parity spec requires normal auction browse/search,
bid/buyout, sell, and cancel surfaces, but the active world-session HUD did not
yet have a resident Auction House window.

Result:

- Added a resident `Auction House` panel to `scripts/world_session_view.gd`.
- The panel renders safe session auction dictionaries without calling the
  protocol bridge: browse/search rows, active bid rows, owned-auction rows,
  item ids or local-safe names, quantities, bid prices, buyout prices, owners,
  bidders, time-left summaries, search text, auctioneer GUID, and response
  opcode when present.
- Keep live auctioneer discovery, browse/search packets, bid, buyout, sell,
  cancel, deposit, delivery, mailbox handoff, and server failure states in
  Claude's live-session lane.

Validation:

- `ACORE_WORLD_SESSION_SELF_TEST=1 godot-4 --headless --path . --scene
  res://scenes/world_session_view.tscn` passed with `auction_panel=true`.

Remaining work:

- Feed live auction snapshots from Claude's persistent session lane into the
  world-session context.
- Add player-driven search filters, paging, bid, buyout, sell, cancel, deposit
  estimates, failure-code feedback, mailbox delivery handoff, owned-auction
  refresh, local-only item names/icons/tooltips, and normal auctioneer
  targeting.

## 2026-07-02 - World Session Aura And Unit Status Panel (Codex UI lane)

Context: a separate aura simulation existed, but the active world-session HUD
did not yet have a resident surface for health, power, buffs, debuffs, target
status, or cooldown-like rows.

Result:

- Added a resident `Auras` panel to `scripts/world_session_view.gd`.
- The panel renders safe session player and selected-target status dictionaries
  without calling the protocol bridge: health, power, level, class,
  faction/reaction, buffs, debuffs, generic aura rows, and cooldown-like rows
  when present.
- The compact selected-target HUD frame now also displays safe target
  health/power and aura counts when those fields are present in the visible
  object snapshot.
- Keep live update-field parsing, combat health deltas, aura application,
  expiration, dispels, and server-synchronized unit-frame updates in Claude's
  live-session lane.

Validation:

- `ACORE_WORLD_SESSION_SELF_TEST=1 godot-4 --headless --path . --scene
  res://scenes/world_session_view.tscn` passed with `auras_panel=true`.

Remaining work:

- Feed live player/target health, power, aura, cooldown, and update-field
  snapshots from Claude's persistent session lane into the world-session
  context.
- Add normal unit frames, buff/debuff icons, timers, dispel/cancel affordances,
  combat health deltas, death/ghost state, target-of-target, party/raid unit
  frames, and local-only spell metadata/icons/tooltips.

## 2026-07-02 - World Session Mail Panel (Codex UI lane)

Context: the Stage 17 parity spec requires normal mailbox list/read/send
surfaces, but the active world-session HUD did not yet have a resident Mail
window.

Result:

- Added a resident `Mail` panel to `scripts/world_session_view.gd`.
- The panel renders safe session mail dictionaries without calling the protocol
  bridge: message rows, sender, subject, preview text, unread state, attached
  money, COD amount, and attachment summaries when present.
- Actual mailbox discovery, read/send/delete, attachment pickup, and COD actions
  stay in Claude's live-session/native lane.

Validation:

- `ACORE_WORLD_SESSION_SELF_TEST=1 godot-4 --headless --path . --scene
  res://scenes/world_session_view.tscn` passed with `mail_panel=true`.

Remaining work:

- Feed live mailbox snapshots from Claude's persistent session lane into the
  world-session context.
- Add player-driven read, send, delete, return, attachment pickup, COD payment,
  mailbox object discovery, message body expansion, and local-only item
  names/icons/tooltips.

## 2026-07-02 - World Session Social Panel (Codex UI lane)

Context: the Stage 17 parity spec requires normal social, group, and guild
surfaces, but the active world-session HUD did not yet have a resident social
window.

Result:

- Added a resident `Social` panel to `scripts/world_session_view.gd`.
- The panel renders safe session social dictionaries without calling the
  protocol bridge: friends, ignore rows, party/group members, guild members,
  pending invites, party leader, guild name, online state, rank, role, level,
  class, zone, notes, and GUID details when present.
- Fixed nested social row extraction so `party.members` and `guild.members`
  shapes are accepted alongside flat row arrays.
- Actual invite, friend, ignore, party, guild, and social mutation actions stay
  in Claude's live-session/native lane.

Validation:

- `ACORE_WORLD_SESSION_SELF_TEST=1 godot-4 --headless --path . --scene
  res://scenes/world_session_view.tscn` passed with `social_panel=true`.

Remaining work:

- Feed live social/group/guild snapshots from Claude's persistent session lane
  into the world-session context.
- Add player-driven invite/accept/decline, friend/ignore, party leave, guild
  roster/rank actions, status updates, and chat integration.

## 2026-07-02 - World Session Trainer Panel (Codex UI lane)

Context: Stage 17 has live trainer proof scenes, but the active world-session
HUD did not yet have a resident trainer-window surface.

Result:

- Added a resident `Trainer` panel to `scripts/world_session_view.gd`.
- The panel renders safe session trainer dictionaries without calling the
  protocol bridge: target entry/GUID, response opcode, trainer type, greeting,
  spell rows, money cost, usable/known state, requirements, and learn
  success/failure feedback when present.
- Actual learn-spell requests, fixture setup, spellbook refresh, and money
  verification remains in Claude's live-session/native lane.

Validation:

- `ACORE_WORLD_SESSION_SELF_TEST=1 godot-4 --headless --path . --scene
  res://scenes/world_session_view.tscn` passed with `trainer_panel=true`.

Remaining work:

- Feed live trainer snapshots from Claude's persistent session lane into the
  world-session context.
- Add player-driven learn controls, failure-code feedback, spellbook/money
  refresh after learning, local-only names/icons/ranks, richer disabled-state
  explanations, and normal click-to-trainer targeting.

## 2026-07-02 - World Session Vendor Panel (Codex UI lane)

Context: Stage 17 has live vendor proof scenes, but the active world-session
HUD did not yet have a resident vendor-window surface.

Result:

- Added a resident `Vendor` panel to `scripts/world_session_view.gd`.
- The panel renders safe session vendor dictionaries without calling the
  protocol bridge: target entry/GUID, response opcode, vendor item rows, price,
  buy count, stock, durability, extended cost, and transaction snapshots when
  present.
- Replaced the return-heavy panel-title helper with a title lookup table as the
  panel list grows.
- Actual buy, sell, repair, stock refresh, and in-world click targeting remains
  in Claude's live-session/native lane.

Validation:

- `ACORE_WORLD_SESSION_SELF_TEST=1 godot-4 --headless --path . --scene
  res://scenes/world_session_view.tscn` passed with `vendor_panel=true`.

Remaining work:

- Feed live vendor snapshots from Claude's persistent session lane into the
  world-session context.
- Add player-driven buy/sell/repair controls, failure-code feedback, inventory
  refresh after transactions, local-only names/icons/tooltips, stock refresh,
  and normal click-to-vendor targeting.

## 2026-07-02 - World Session Loot Panel (Codex UI lane)

Context: Stage 17 has live loot proof scenes, but the active world-session HUD
did not yet have a resident normal loot-window surface.

Result:

- Added a resident `Loot` panel to `scripts/world_session_view.gd`.
- The panel renders safe session loot dictionaries without calling the protocol
  bridge: status, target entry/GUID, response opcode, loot money, item rows,
  removed-item notices, and changed inventory slots when present.
- Actual loot pickup, release, autostore, and click-targeting behavior remains
  in Claude's live-session/native lane.

Validation:

- `ACORE_WORLD_SESSION_SELF_TEST=1 godot-4 --headless --path . --scene
  res://scenes/world_session_view.tscn` passed with `loot_panel=true`.

Remaining work:

- Feed live loot snapshots from Claude's persistent session lane into the
  world-session context after combat/corpse loot.
- Add player-driven loot row pickup, money loot, release/autostore controls,
  full-bag/error feedback, group loot rolls, local-only names/icons/tooltips,
  and persistent inventory refresh.

## 2026-07-02 - World Session Character Panel (Codex UI lane)

Context: the active world-session HUD had bags and target data, but no resident
character/paper-doll style surface for identity, location, money, or equipped
slot feedback.

Result:

- Added a resident `Character` panel to `scripts/world_session_view.gd`.
- The panel renders safe character profile data from the session handoff:
  name, level/class, race when present, map, position, orientation, zone when
  present, and money.
- Added a 19-slot equipment grid using the same safe inventory-slot summaries as
  the Bags panel.
- This remains UI-lane work only and does not call or edit the protocol bridge.

Validation:

- `ACORE_WORLD_SESSION_SELF_TEST=1 godot-4 --headless --path . --scene
  res://scenes/world_session_view.tscn` passed with `character_panel=true`.

Remaining work:

- Feed live character/equipment refresh snapshots from Claude's persistent
  session lane after equipment, money, aura, level, skill, and location changes.
- Add item names/icons/tooltips/stats from local-only metadata, model/portrait
  preview, paper-doll drag/drop equip/unequip, durability/repair state, and
  server failure feedback.

## 2026-07-02 - World Session Chat Log Data (Codex UI lane)

Context: the resident world-session `Chat` panel had a local send box, but it
did not display session-provided chat/system rows.

Result:

- Added safe chat-row extraction to `scripts/world_session_view.gd`.
- The resident `Chat` panel now renders session chat dictionaries/arrays above
  the local send box without calling the protocol bridge.
- Chat rows show safe mode/channel, sender, and message text when available.
- Send behavior remains a local queue until Claude's live-session lane wires
  server chat sends into the persistent world session.

Validation:

- `ACORE_WORLD_SESSION_SELF_TEST=1 godot-4 --headless --path . --scene
  res://scenes/world_session_view.tscn` passed with `chat=true`.

Remaining work:

- Feed live `SMSG_MESSAGECHAT`, system messages, combat log rows, and channel
  updates into the world-session context.
- Add tabs, filters, timestamps, scrollback controls, colors, command parsing,
  and live send/whisper/channel calls through the persistent session lane.

## 2026-07-02 - World Session Spellbook Data (Codex UI lane)

Context: the world-session HUD had a `Spells` shortcut and panel, but that
panel still showed placeholder text even when spellbook-style session data
could be supplied by the login/session handoff.

Result:

- Added safe spell-row extraction to `scripts/world_session_view.gd`.
- The resident `Spells` panel now renders dictionary/array spellbook rows from
  session data without calling the protocol bridge.
- Spell rows show safe numeric spell ids, slots, and available flags/state
  fields, with selectable rows that update the HUD status/detail text.
- This remains UI-lane work only; live casting, cooldowns, names, icons, and
  failure feedback still depend on later live-session and local-only metadata
  slices.

Validation:

- `ACORE_WORLD_SESSION_SELF_TEST=1 godot-4 --headless --path . --scene
  res://scenes/world_session_view.tscn` passed with `spellbook=true`.

Remaining work:

- Feed live `SMSG_INITIAL_SPELLS` and learned-spell refresh snapshots from
  Claude's persistent session lane into the world-session context.
- Add local-only spell names/icons/ranks, cooldown/failure/cast state, drag/drop
  action placement, and actual spell-cast calls through the live-session lane.

## 2026-07-02 - World Session Action Bar Data (Codex UI lane)

Context: the world-session HUD had twelve shortcut buttons, but they stayed
static even when action-button data could be provided by the session.

Result:

- Added safe action-slot extraction to `scripts/world_session_view.gd`.
- The bottom twelve-slot HUD action bar now renders Stage 16-style action slot
  dictionaries: button, action id, action type, packed value, and populated
  state.
- The resident `Actions` panel now reports loaded action-slot count and lists
  safe slot/action/type rows.
- This remains UI-lane work only and does not call or edit the protocol bridge.

Validation:

- `ACORE_WORLD_SESSION_SELF_TEST=1 godot-4 --headless --path . --scene
  res://scenes/world_session_view.tscn` passed with `action_slots=true`.

Remaining work:

- Feed live `SMSG_ACTION_BUTTONS` snapshots from Claude's persistent session
  lane into the world-session context.
- Replace numeric action labels with local-only spell/item names and icons, add
  real casting/item-use calls through the live session lane, drag/drop action
  assignment, paging, cooldowns, macros, and failure feedback.

## 2026-07-02 - World Session Target Panel (Codex UI lane)

Context: the world-session HUD could cycle a target count, but it did not have
a real target frame or target-list surface for live visible-object rows.

Result:

- Added an always-visible `Target` HUD frame to `scripts/world_session_view.gd`.
- Added a resident `Targets` panel to the movable/resizable world-session panel
  system.
- The target UI renders safe numeric visible-object data from session
  dictionaries: target index, type, entry/id, GUID, distance, and position when
  present.
- This remains UI-lane work only and does not call or edit the protocol bridge.

Validation:

- `ACORE_WORLD_SESSION_SELF_TEST=1 godot-4 --headless --path . --scene
  res://scenes/world_session_view.tscn` passed with `targets=true`.

Remaining work:

- Feed live visible-object rows from Claude's persistent session lane into the
  frame and panel.
- Add true in-world click picking, target health/power/aura fields, target
  portrait/model preview, reaction/combat status, party target frames, and
  target-of-target.

## 2026-07-02 - World Session Map Panel (Codex UI lane)

Context: the world-session HUD had a `Map` shortcut, but it still opened the
Quests panel. A playable client needs map access to be its own resident HUD
surface.

Result:

- Added a resident `Map` panel to `scripts/world_session_view.gd`.
- The `Map` shortcut and a new nav-bar `Map` button now open the map panel.
- The panel renders safe numeric map/session state: map id, server position,
  Godot marker position, orientation, visible-object count, and selected target.
- This remains UI-lane work only and does not call or edit the protocol bridge.

Validation:

- `ACORE_WORLD_SESSION_SELF_TEST=1 godot-4 --headless --path . --scene
  res://scenes/world_session_view.tscn` passed with `map_panel=true`.

Remaining work:

- Feed richer live map/minimap state from Claude's persistent session lane.
- Add local-only zone names, minimap markers, world-map art/tiles, quest
  objective hooks, and click-to-track/objective navigation.

## 2026-07-02 - World Session Quest Tracker (Codex UI lane)

Context: the resident Quests panel made quest-log data available in a HUD
window, but a normal client also needs a small tracker visible during play.

Result:

- Added an always-visible `Quest Tracker` HUD surface to
  `scripts/world_session_view.gd`.
- The tracker renders numeric active quest rows from the same safe session
  dictionaries as the movable Quests panel: slot id, quest id, objective
  counters, timers, and status flags when present.
- The tracker has an `Open` action that opens the resident Quests panel without
  leaving the world-session view.
- This remains UI-lane work only and does not call or edit the protocol bridge.

Validation:

- `ACORE_WORLD_SESSION_SELF_TEST=1 godot-4 --headless --path . --scene
  res://scenes/world_session_view.tscn` passed with `tracker=true`.

Remaining work:

- Feed live quest-log snapshots from Claude's persistent session lane into the
  tracker.
- Add local-only quest titles/objective text/icons, pinned tracking choices,
  objective progress updates, completion/reward controls, abandon/share
  controls, and map objective hooks.

## 2026-07-02 - World Session Quest Panel (Codex UI lane)

Context: the world-session HUD had a Quests shortcut and panel, but it only
showed a placeholder. A playable client needs quest tracking to live in the
active world view instead of only in separate Stage 17 proof scenes.

Result:

- Added safe quest-log slot extraction to `scripts/world_session_view.gd`.
- The resident `Quests` HUD panel now renders observed slot count, active
  quest count, active quest ids, objective counters, timers, and status flags
  when those numeric fields are present in session dictionaries.
- The panel stays UI-only and does not call the protocol bridge; it is ready for
  Claude's persistent session lane to feed live snapshot dictionaries later.

Validation:

- `ACORE_WORLD_SESSION_SELF_TEST=1 godot-4 --headless --path . --scene
  res://scenes/world_session_view.tscn` passed with `quests=true`.
- `ACORE_WORLD_SESSION_LAYOUT_SELF_TEST=1 godot-4 --headless --path . --scene
  res://scenes/world_session_view.tscn` passed.
- `ACORE_WORLD_SESSION_KEYBIND_SELF_TEST=1 godot-4 --headless --path . --scene
  res://scenes/world_session_view.tscn` passed.
- `godot-4 --headless --path . --quit` passed.

Remaining work:

- Feed live quest-log snapshots from Claude's persistent session lane into this
  panel.
- Add local-only quest titles/objective text/icons, tracker pinning, completion
  and reward-choice UI, abandon/share controls, and map objective hooks.

## 2026-07-01 - World Session Bags Panel (Codex UI lane)

Context: the world-session HUD had a Bag shortcut, but it opened the Actions
panel. A playable client needs inventory/bag access to live inside the active
world view instead of only in a separate Stage 17 proof scene.

Result:

- Added a resident `Bags` HUD panel to `scripts/world_session_view.gd`.
- The Bag shortcut and nav button now open the Bags panel in the world-session
  overlay.
- The panel renders a 39-slot equipment/bag/backpack grid from safe session
  dictionaries when they are available, including money, stack counts, empty
  slots, GUID/entry detail, and durability text.
- When no live inventory snapshot exists yet, the panel stays in the session
  HUD and shows a waiting state instead of calling the protocol bridge.

Validation:

- `ACORE_WORLD_SESSION_SELF_TEST=1 godot-4 --headless --path . --scene
  res://scenes/world_session_view.tscn` now verifies the Bags panel, synthetic
  money, populated backpack slot rendering, and a 39-slot in-session grid.

Remaining work:

- Feed live inventory snapshots from Claude's persistent session lane into this
  panel.
- Add normal player drag/drop, item use, equip/unequip, split/merge, sell/buy
  refresh, item icons, local-only tooltip metadata, and server failure display.

## 2026-07-01 - Resizable World Session HUD Panels (Codex UI lane)

Context: the world-session HUD supported multiple movable panels, but each panel
still used a fixed size. A playable client needs windows that can be shaped
around the player's preferred layout.

Result:

- Added a `Resize` handle to each world-session HUD panel.
- Panel resizing clamps to sane minimum and maximum sizes, stays inside the
  viewport, and saves through the same `user://world-session-layout.cfg` file
  as panel positions.
- Panel content now sits inside a scroll region so large option/chat/action
  contents do not force the whole HUD window to grow uncontrollably.
- `Reset HUD` restores every panel to the default position and default size.

Validation:

- `ACORE_WORLD_SESSION_LAYOUT_SELF_TEST=1 godot-4 --headless --path . --scene
  res://scenes/world_session_view.tscn` now saves and reloads separate Options
  and Actions panel positions plus distinct resized dimensions before
  reset/cleanup.
- `ACORE_WORLD_SESSION_SELF_TEST=1`,
  `ACORE_WORLD_SESSION_KEYBIND_SELF_TEST=1`, and
  `ACORE_UI_LAYOUT_SELF_TEST=1` still pass.

Remaining work:

- Feed live data into the individual panels as Claude's persistent session lane
  exposes stable world-session APIs.
- Add per-character/profile scope decisions, full action-bar paging, and
  drag/drop action placement.

## 2026-07-01 - Multi-Panel World Session HUD (Codex UI lane)

Context: the world-session HUD panel could move and persist its placement, but
it still swapped one panel body between Chat, Spells, Actions, Quests, and
Options. A playable client needs multiple windows open at the same time.

Result:

- Refactored `scripts/world_session_view.gd` so Chat, Spells, Actions, Quests,
  and Options are separate floating panels.
- Each panel has its own header, close button, position, size, drag state, and
  saved layout section in `user://world-session-layout.cfg`.
- The same bottom action strip and navigation buttons can now open multiple
  resident panels without closing the others.
- `Reset HUD` now restores every world-session panel to its default position and
  clears the saved layout file.

Validation:

- `ACORE_WORLD_SESSION_SELF_TEST=1 godot-4 --headless --path . --scene
  res://scenes/world_session_view.tscn` now confirms Chat and Actions are
  separate visible panels at the same time, then checks the remaining panel
  builders.
- `ACORE_WORLD_SESSION_LAYOUT_SELF_TEST=1 godot-4 --headless --path . --scene
  res://scenes/world_session_view.tscn` now saves and reloads separate Options
  and Actions panel positions before reset/cleanup.

Remaining work:

- Feed live data into the individual panels as Claude's persistent session lane
  exposes stable world-session APIs.
- Add per-character/profile scope decisions, full action-bar paging, and
  drag/drop action placement.

## 2026-07-01 - Movable World Session HUD Layout (Codex UI lane)

Context: the world-session HUD panels existed inside the active game view, but
they were fixed in the top HUD flow. A playable client needs the player-facing
panels to move and remember their placement.

Result:

- Moved the world-session panel shell into an overlay so it can float above the
  world view instead of taking space in the HUD stack.
- Added drag handling on the panel header, grid snapping, viewport clamping, and
  automatic layout save after dropping the panel.
- Added `user://world-session-layout.cfg` for normal layout persistence and
  `user://world-session-layout-self-test.cfg` for temporary self-test storage.
- Added a `Reset HUD` action inside the Options panel to restore the default
  panel position and remove the saved layout file.

Validation:

- `ACORE_WORLD_SESSION_LAYOUT_SELF_TEST=1 godot-4 --headless --path . --scene
  res://scenes/world_session_view.tscn` saves a snapped panel position, reloads
  it, resets to default, and confirms the temporary layout file is removed.
- `ACORE_WORLD_SESSION_SELF_TEST=1` and
  `ACORE_WORLD_SESSION_KEYBIND_SELF_TEST=1` still pass after the overlay
  refactor.

Remaining work:

- Add per-character/profile scope decisions, full action-bar paging, and
  drag/drop action placement.

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
- Add full action-bar paging and drag/drop action placement.

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
