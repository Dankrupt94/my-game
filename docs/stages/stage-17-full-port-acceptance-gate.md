# Stage 17 - Full Port Acceptance Gate

Status: In progress

## Goal

Verify that the Godot client is a fully functional WotLK port for AzerothCore, not a companion tool, not a reimagined game, and not a partial prototype.

## Engine Spec

Stage 17 uses [WotLK Client Parity Engine Spec](../wotlk_client_parity_engine_spec.md) as the detailed checklist for full playability. The gate cannot be treated as complete while that spec still has normal player-facing client behavior missing without an explicit compatibility note.

## Acceptance Requirements

- Godot can authenticate, list realms, list characters, enter world, and maintain a live world session through the AzerothCore protocol.
- Godot can run normal player-facing gameplay without launching the original WotLK client.
- Movement, object visibility, targeting, combat, spells, auras, loot, inventory, equipment, quests, vendors, trainers, chat, groups, guilds, mail, auction house, maps/minimap, settings, and major UI flows are implemented or have explicit parity notes.
- Required local asset/data pipelines are documented and keep proprietary inputs and derived files local-only.
- Any behavior difference caused by Godot, Linux, local tooling, or AzerothCore is documented as a compatibility deviation.
- Major feature areas have regression tests or manual test checklists.

## Not Accepted

- A dashboard-only companion.
- A Godot sandbox that merely resembles WotLK.
- A client that still requires the original WotLK executable for normal play.
- A client that implements only login, movement, or a small subset of gameplay.
- A reimagined MMO that uses AzerothCore data but does not aim for WotLK client parity.

## Done Criteria

- The user can use Godot as the player-facing client for normal AzerothCore WotLK play.
- Remaining deviations are documented, justified, and tracked.
- The original client is no longer needed for ordinary runtime play, only for comparison or validation.

## Documentation To Update During Work

- Full feature checklist.
- Parity matrix.
- Known deviations.
- Manual test scripts.
- Local asset/data pipeline notes.
- Performance and stability notes.

## Checkpoints

### 2026-07-01 - Read-Only Inventory Slot Snapshot

- Added a first inventory slice that reads player private update fields from `SMSG_UPDATE_OBJECT` / `SMSG_COMPRESSED_UPDATE_OBJECT`.
- Godot now exposes a 39-slot equipment, bag, and backpack grid through `scenes/stage17_inventory_view.tscn`.
- The slice reports live item GUID presence only. Item names, icons, stack counts, durability, bag contents beyond the base backpack, and item actions remain future work.
- Validation: `ACORE_INVENTORY_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage17_inventory_view.tscn` passed with 39 slots and 7 populated slots for `Codexstage`.

### 2026-07-01 - Inventory Item Detail Snapshot

- Expanded the inventory slice from GUID-only slots to item object details.
- The native parser now extracts item entry, stack count, durability, and max durability from item object value updates.
- The flow now sends bounded `CMSG_ITEM_QUERY_SINGLE` requests for discovered item entries and applies `SMSG_ITEM_QUERY_SINGLE_RESPONSE` names back onto matching inventory slots.
- The Godot extension, script bridge, and Stage 17 inventory scene now surface item detail counts and resolved-name counts.
- Validation: native `--inventory-snapshot` passed for `Codexstage` with 39 slots, 7 populated slots, 7 item-detail rows, and 7 resolved names.
- Validation: `ACORE_INVENTORY_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage17_inventory_view.tscn` passed with `slots=39`, `populated=7`, `details=7`, and `names=7`.
- Remaining work: item icons, full tooltips/stats, nested bag contents beyond the base backpack, item actions, equipment changes, loot-to-inventory flow, and persistence checks after mutation.

### 2026-07-01 - Reversible Inventory Move/Swap Probe

- Added the first server-mutating Stage 17 inventory action through `CMSG_SWAP_INV_ITEM`.
- The native flow reads the current inventory, refuses to run if the source slot is empty, sends a base-backpack move from slot `23` to slot `25`, rereads the server state, then restores the item from slot `25` to slot `23`.
- The confirmation checks compare the pre-move and post-move slot GUIDs so the probe proves the server state changed and then returned to its starting shape.
- The Godot extension, script bridge, and `scenes/stage17_inventory_view.tscn` expose the same reversible action through a `Test Move` control and a headless swap self-test.
- Validation: native `--swap-inventory-slots` passed for `Codexstage` with `before_seen=1`, `swap_confirmed=1`, and `restore_confirmed=1` for slots `23` and `25`.
- Validation: `ACORE_INVENTORY_SWAP_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage17_inventory_view.tscn` passed with `swap_confirmed=true` and `restore_confirmed=true`.
- Remaining work: player-driven drag/drop, arbitrary slot validation, nested bag moves, equipment swaps, item splitting, item use, item destruction, failure-code UI, item cooldowns, loot-to-bag handoff, and long-session persistence checks.

### 2026-07-01 - Reversible Equipment Unequip/Restore Probe

- Extended the Stage 17 inventory scene with a `Test Unequip` control that uses the same authenticated world-session bridge to move an equipped main-hand item into the backpack and restore it.
- The live probe uses source slot `15` and destination slot `26`, then confirms the equipped item GUID leaves slot `15`, appears in slot `26`, and returns to slot `15` after restore.
- This is the first equipment mutation milestone. It proves Godot can change live equipped state through AzerothCore without launching the original client.
- Validation: native `--swap-inventory-slots` passed for `Codexstage` with `before_seen=1`, `swap_confirmed=1`, and `restore_confirmed=1` for slots `15` and `26`.
- Validation: `ACORE_EQUIPMENT_SWAP_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage17_inventory_view.tscn` passed with `swap_confirmed=true` and `restore_confirmed=true`.
- Remaining work: paper doll UI, arbitrary equip/unequip, item requirements, stat/aura display changes, weapon/offhand rules, failure-code UI, repair/durability workflows, and long-session persistence checks after normal player-driven equipment changes.

### 2026-07-01 - Reversible Stack Split/Merge Probe

- Added `CMSG_SPLIT_ITEM` support for a bounded stack mutation from the Godot client path.
- The packet uses AzerothCore's base inventory bag id `255` for source and destination bag fields, then source slot, destination slot, and split count.
- The live probe splits one item from backpack slot `23` into empty backpack slot `25`, confirms the source stack decreases from `4` to `3` and the destination stack becomes `1`, then merges slot `25` back into slot `23`.
- The Stage 17 inventory scene now exposes this as a `Test Split` control plus `ACORE_STACK_SPLIT_SELF_TEST=1`.
- Validation: native `--split-inventory-stack` passed for `Codexstage` with `split_confirmed=1` and `merge_confirmed=1`.
- Validation: `ACORE_STACK_SPLIT_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage17_inventory_view.tscn` passed with `split_confirmed=true` and `merge_confirmed=true`.
- Remaining work: player-selected split amounts, stackable-item discovery, drag/drop stack UI, nested bag support, failure-code UI, item locks/trade windows, and persistence checks over normal play sessions.

### 2026-07-01 - Loot Open Protocol Probe

- Added the first Stage 17 loot protocol slice.
- The native packet layer now builds `CMSG_LOOT`, `CMSG_LOOT_RELEASE`, and `CMSG_AUTOSTORE_LOOT_ITEM`, and parses `SMSG_LOOT_RESPONSE` error and success payloads.
- The live flow resolves a nearby creature entry to a runtime object GUID, moves within interaction range, selects the target, sends `CMSG_LOOT`, and records either `SMSG_LOOT_RESPONSE` or `SMSG_LOOT_RELEASE_RESPONSE`.
- Added `scenes/stage17_loot_view.tscn` as the first Godot loot surface, with `ACORE_LOOT_OPEN_SELF_TEST=1` as its headless validation path.
- Validation: native `--loot-open-probe` passed for `Codexstage` against entry `38` with `loot_open_sent=1`, `loot_release_response_seen=1`, `loot_release_success=1`, and response opcode `0x161`.
- Validation: the Ubuntu 22.04 Docker compatibility build refreshed the Godot-loadable extension and compatibility helper.
- Validation: `ACORE_LOOT_OPEN_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage17_loot_view.tscn` passed with release response opcode `0x161`.
- Remaining work: kill-to-corpse combat loop, real loot-window success response, money pickup, item pickup, inventory handoff, loot errors in UI, corpse release after looting, group loot/rolls, and persistence checks over normal play.

### 2026-07-01 - Corpse Loot Pickup Probe

- Extended the loot slice from a not-yet-lootable open request into a bounded kill-to-corpse pickup flow.
- The visible-object parser now reads unit health, max health, unit flags, and dynamic flags from create/value updates so the client can wait for real server death/lootable state.
- Added a stepped approach helper for combat positioning, then repeatedly maintains selection/attack until the target reports health `0` or `UNIT_DYNFLAG_LOOTABLE`.
- The native flow opens corpse loot, sends `CMSG_LOOT_MONEY` when the loot window contains copper, sends `CMSG_AUTOSTORE_LOOT_ITEM` for each loot slot, observes `SMSG_LOOT_REMOVED`, and releases the loot window.
- `scenes/stage17_loot_view.tscn` now exposes a `Fight + Loot` control and `ACORE_CORPSE_LOOT_SELF_TEST=1`.
- Validation: `ACORE_CORPSE_LOOT_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage17_loot_view.tscn` passed with `dead=true`, `lootable=true`, `loot_response=true`, `item_removed=2`, `release_response=true`, and response opcode `0x160`.
- Validation: `ACORE_LOOT_OPEN_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage17_loot_view.tscn` still passed with release response opcode `0x161` after the corpse-loot movement work.
- Remaining work: turn this from a test button into normal player-controlled combat-to-loot UX, integrate actual inventory slot updates after pickup, collect nonzero-money evidence, handle full bags/loot errors, support group loot and rolls, and add long-session persistence checks.

### 2026-07-01 - Loot-To-Inventory Handoff Probe

- Added a before/after inventory proof around the corpse-loot path so item pickup is not accepted as complete until the player's inventory state changes.
- The native `--loot-inventory-handoff` flow snapshots inventory, runs the corpse-loot pickup, snapshots inventory again, and compares all 39 tracked equipment/bag/backpack slots plus coinage.
- `scenes/stage17_loot_view.tscn` now exposes a `Loot + Bag` control and `ACORE_LOOT_INVENTORY_SELF_TEST=1`.
- The latest native run looted entry `299`, observed `item_count=1`, then confirmed slot `30` changed by increasing the `Ruined Pelt` stack to `3`.
- Validation: `ACORE_LOOT_INVENTORY_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage17_loot_view.tscn` passed with `changed_slots=1`, `stack_changed=1`, `handoff=true`, and response opcode `0x160`.
- Validation: `ACORE_LOOT_OPEN_SELF_TEST=1` and `ACORE_CORPSE_LOOT_SELF_TEST=1` still passed when rerun sequentially after the handoff change.
- Remaining work: replace this proof button with normal corpse-click loot UX, refresh the visible inventory panel automatically after pickup, handle full bags and item locks, collect nonzero-money evidence, and add long-session persistence checks.

### 2026-07-01 - Loot Scene Target And Inventory Refresh UI

- Extended `scenes/stage17_loot_view.tscn` from fixed test buttons toward a more player-facing loot workflow.
- Added editable target entry/name controls for the fight-to-loot and loot-to-bag paths.
- The `Loot + Bag` path now renders both changed inventory slots and a refreshed after-loot inventory list in the scene, so the player-facing surface shows where the picked-up item landed or stacked.
- Validation: `godot-4 --headless --path . --quit` passed.
- Validation: `ACORE_LOOT_INVENTORY_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage17_loot_view.tscn` passed with `changed_slots=1`, `stack_changed=1`, `handoff=true`, and response opcode `0x160`.
- Validation: `ACORE_LOOT_OPEN_SELF_TEST=1` passed, and a rerun of `ACORE_CORPSE_LOOT_SELF_TEST=1` passed after a transient live-target miss.
- Remaining work: replace target-entry controls with in-world click targeting, keep a persistent session instead of one-shot probes, and merge the loot/inventory surfaces into the normal gameplay HUD.

### 2026-07-01 - Loot Visible Target Snapshot Picker

- Added a reusable native `visible_targets_snapshot` flow that logs into the world, waits for update packets, captures visible objects, answers time sync, and logs out cleanly without combat or loot mutation.
- Exposed the snapshot through the Godot extension and `ProtocolClientBridge.visible_targets_snapshot(...)`.
- `scenes/stage17_loot_view.tscn` now starts with a non-mutating target scan outside self-test mode, lists live visible creature targets, selects entry `299` when present, and fills the loot target controls from the chosen row.
- The helper fallback parser now preserves `VISIBLE_OBJECT` rows from the enter-world helper output when the native extension is unavailable.
- Validation: `./tools/build_godot_protocol_extension_compat.sh` passed after the native protocol and extension changes.
- Validation: `godot-4 --headless --path . --quit` passed.
- Validation: `ACORE_LOOT_TARGET_PICKER_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage17_loot_view.tscn` passed with `target_count=144`, selected entry `299`, and selected GUID `0xf13000012b006e67`.
- Validation: `ACORE_LOOT_OPEN_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage17_loot_view.tscn` still passed with release response opcode `0x161`.
- Validation: `ACORE_CORPSE_LOOT_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage17_loot_view.tscn` passed with `dead=true`, `lootable=true`, `loot_response=true`, `item_removed=1`, `release_response=true`, and opcode `0x160`.
- Caveat: `ACORE_LOOT_INVENTORY_SELF_TEST=1` was rerun three times in this checkpoint and failed to confirm a new inventory handoff (`changed_slots=0`). The narrower corpse-loot proof still passed, so the next handoff task should stabilize target choice/session timing and then restore this regression to green.
- Remaining work: exact GUID selection from the visible target list, real in-world click picking, persistent session reuse across target/combat/loot/inventory, and a stabilized loot-to-bag proof.

### 2026-07-01 - Exact Target Selector And Handoff Stabilization

- Added [WotLK Client Parity Engine Spec](../wotlk_client_parity_engine_spec.md) as the explicit Stage 17 reference for full Godot-native client playability.
- Added selector-based loot methods through the Godot extension and script bridge so `stage17_loot_view.tscn` can pass either an entry id or an exact runtime object GUID.
- Updated the loot scene so `Fight + Loot` and `Loot + Bag` scan visible targets first, choose a live known-lootable local test target, and send the selected exact GUID into the native protocol flow.
- Added `tools/stage17_visible_targets_report.gd` to print visible target candidates with entry, GUID, distance, health, and flags for safe local diagnostics.
- Validation: `./tools/build_godot_protocol_extension_compat.sh` passed.
- Validation: `godot-4 --headless --path . --quit` passed.
- Validation: `ACORE_LOOT_TARGET_PICKER_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage17_loot_view.tscn` passed with `target_count=140`, selected entry `69`, and selected GUID `0xf130000045000daa`.
- Validation: `ACORE_LOOT_INVENTORY_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage17_loot_view.tscn` passed with selected entry `69`, `changed_slots=1`, `added_slots=1`, `handoff=true`, and response opcode `0x160`.
- Validation: `ACORE_CORPSE_LOOT_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage17_loot_view.tscn` passed with selected entry `69`, `dead=true`, `lootable=true`, `item_removed=2`, `release_response=true`, and response opcode `0x160`.
- Validation: `ACORE_LOOT_OPEN_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage17_loot_view.tscn` still passed with release response opcode `0x161`.
- Local `qwen-agent` advisory review reported no blockers.
- Remaining work: replace the list picker with real in-world click picking, keep one persistent world session across scan/combat/loot/inventory refresh, and turn the proof buttons into normal HUD gameplay.
