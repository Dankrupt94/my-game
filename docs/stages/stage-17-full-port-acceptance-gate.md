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

### 2026-07-01 - Trainer List Protocol Probe

- Continued Stage 17 against [WotLK Client Parity Engine Spec](../wotlk_client_parity_engine_spec.md), specifically the trainer window/list portion of the full-playability checklist.
- Added `CMSG_TRAINER_LIST` / `SMSG_TRAINER_LIST` support to the native protocol helper and Godot extension.
- Matched AzerothCore's trainer interaction gate by moving the test character within NPC interaction range before sending the trainer-list request, then returning to the login position.
- Added `ProtocolClientBridge.trainer_list_probe(...)`.
- Added `scenes/stage17_trainer_view.tscn` as the first Godot trainer surface, with target controls, live greeting display, and spell rows showing server-returned cost and requirement fields.
- Validation: native `--trainer-list` passed for `Codexstage` with `live_target_found=1`, `approach_movement_sent=1`, `return_movement_sent=1`, `trainer_list_response_seen=1`, response opcode `0x1B1`, and 6 spell rows.
- Validation: `./tools/build_godot_protocol_extension_compat.sh` passed.
- Validation: `godot-4 --headless --path . --quit` passed.
- Validation: `ACORE_TRAINER_LIST_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage17_trainer_view.tscn` passed with `moved_close=true`, `returned=true`, `spell_count=6`, and response opcode `0x1B1`.
- Local `qwen-agent` advisory review reported no blockers.
- Remaining work: learn-spell packets, server money updates, failure-code UI, spell names/icons/ranks, normal player click-to-trainer selection, and persistent-session integration.

### 2026-07-01 - Trainer Buy Failure Response Probe

- Extended the trainer slice from read-only list viewing into a server-authoritative trainer-buy request path.
- Added `CMSG_TRAINER_BUY_SPELL`, `SMSG_TRAINER_BUY_SUCCEEDED`, and `SMSG_TRAINER_BUY_FAILED` support to the native packet layer.
- Added native `--trainer-buy`, Godot extension methods, `ProtocolClientBridge.trainer_buy_spell_probe(...)`, and a `Try Learn` action in `scenes/stage17_trainer_view.tscn`.
- The current local test character has only 2 copper, so the live validation intentionally proves the safe failure path for spell `6673` instead of forcing a successful learn.
- Validation: native `--trainer-buy` passed with `trainer_list_response_seen=1`, `buy_spell_sent=1`, `buy_response_seen=1`, `buy_failed=1`, `failure_reason=1`, and response opcode `0x1B4`.
- Validation: `./tools/build_godot_protocol_extension_compat.sh` passed.
- Validation: `godot-4 --headless --path . --quit` passed.
- Validation: `ACORE_TRAINER_LIST_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage17_trainer_view.tscn` still passed.
- Validation: `ACORE_TRAINER_BUY_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage17_trainer_view.tscn` passed with `succeeded=false`, `failed=true`, `failure_reason=1`, and response opcode `0x1B4`.
- Local `qwen-agent` advisory review reported no blockers for the native protocol changes or the Godot bridge/UI changes.
- Remaining work: prepare a money-backed local test fixture, prove `SMSG_TRAINER_BUY_SUCCEEDED`, verify spellbook and coinage refresh after learning, then replace the fixed test button with normal player trainer interaction.

### 2026-07-01 - Trainer Buy Success And Spellbook Proof

- Added `tools/prepare_trainer_buy_fixture.py` as an audited local-only fixture that prepares the disposable test character for repeatable trainer-buy success checks.
- The fixture ensures enough copper, resets only spell `6673` from `character_spell`, refuses online-character mutation by default, and writes to ignored `local_runtime/database-transactions.log`.
- Removed the native spellbook CLI print cap so helper fallback output can include newly learned spells even when they are not in the first rows.
- Added `ACORE_TRAINER_BUY_SUCCESS_SELF_TEST=1` to `scenes/stage17_trainer_view.tscn`; it snapshots spellbook and coinage before the trainer buy, learns through AzerothCore, then snapshots spellbook and coinage again.
- Validation: `python3 tools/prepare_trainer_buy_fixture.py --dry-run` passed with `online=0`, `before_money=2`, and `spell_rows_before=0`.
- Validation: `python3 tools/prepare_trainer_buy_fixture.py` passed, raising `Codexstage` to `10000` copper and leaving spell `6673` unlearned before the Godot test.
- Validation: `ACORE_TRAINER_BUY_SUCCESS_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage17_trainer_view.tscn` passed with `succeeded=true`, `before_known=false`, `after_known=true`, `coinage_delta=-9`, and response opcode `0x1B3`.
- Local `qwen-agent` advisory review reported no blockers for the fixture or Godot success self-test changes.
- Remaining work: replace fixed target/test-spell controls with normal trainer click flow, add spell names/icons/ranks and disabled-state details, and fold trainer learning into a persistent world session.

### 2026-07-01 - Trainer Visible Target Picker

- Reused the Stage 17 visible-target snapshot path in `scenes/stage17_trainer_view.tscn`.
- Added a trainer target scan list, exact runtime GUID selection, and selector-aware trainer list/buy calls.
- The scene now prefers trainer entry `911` when visible, while still allowing manual target entry/name edits.
- Validation: `ACORE_TRAINER_TARGET_PICKER_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage17_trainer_view.tscn` passed with `target_count=143`, selected entry `911`, and selected GUID `0xf13000038f000d00`.
- Validation: `ACORE_TRAINER_LIST_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage17_trainer_view.tscn` still passed after routing the trainer list through the selector-aware bridge path.
- Local `qwen-agent` advisory review reported no blockers for the trainer selector changes.
- Remaining work: replace the scan list with true in-world click selection, keep trainer interaction in a persistent session, and add spell names/icons/ranks.

### 2026-07-01 - Trainer Row State And Requirement Text

- Improved the trainer spell rows to show server state, cost, level/skill/prerequisite requirements, and disabled visual state for non-available rows.
- Kept the rows ID-based for now so no proprietary spell-name data is committed.
- Validation: `ACORE_TRAINER_LIST_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage17_trainer_view.tscn` passed after the row rendering update.
- Local `qwen-agent` advisory review reported no blockers for the row rendering update.
- Remaining work: wire real spell names/icons/ranks from the local-only data/asset pipeline and expand disabled-state explanations.

### 2026-07-01 - Vendor List Protocol Probe

- Continued Stage 17 against [WotLK Client Parity Engine Spec](../wotlk_client_parity_engine_spec.md), specifically the vendor-window portion of the NPC services checklist.
- Added `CMSG_LIST_INVENTORY` / `SMSG_LIST_INVENTORY` support to the native protocol helper and Godot extension.
- Added `ProtocolClientBridge.vendor_list_probe_selector(...)` with helper-process fallback parsing.
- Added `scenes/stage17_vendor_view.tscn` as the first Godot vendor surface, with live visible-target scanning, exact GUID selection, and numeric item rows for server-returned vendor stock.
- Kept committed vendor rows item-id based only; item names, icons, and client-derived tooltip data remain local-only future work.
- Local validation target: visible vendor entry `1213`, selected by runtime GUID when present.
- Validation: native `--vendor-list` passed for `Codexstage` against entry `1213` with `live_target_found=1`, `approach_movement_sent=1`, `return_movement_sent=1`, `vendor_list_response_seen=1`, response opcode `0x19F`, and 8 item rows.
- Validation: `ACORE_VENDOR_TARGET_PICKER_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage17_vendor_view.tscn` passed with `target_count=146`, selected entry `1213`, and selected GUID `0xf1300004bd000cf4`.
- Validation: `ACORE_VENDOR_LIST_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage17_vendor_view.tscn` passed with `moved_close=true`, `returned=true`, 8 item rows, and response opcode `0x19F`.
- Local `qwen-agent` advisory review reported no blockers for the vendor protocol, bridge, and scene slice.
- Remaining work: live buy/sell/repair packets, inventory refresh after purchases/sales, stock and failure-code UI, item metadata/icons/tooltips through local-only pipelines, in-world click targeting, and persistent-session integration.

### 2026-07-01 - Vendor Buy/Sell Round Trip Probe

- Extended the vendor slice from read-only list viewing into a bounded server-authoritative commerce mutation.
- Added `CMSG_BUY_ITEM`, `SMSG_BUY_ITEM`, `SMSG_BUY_FAILED`, `CMSG_SELL_ITEM`, and `SMSG_SELL_ITEM` support to the packet layer.
- The native flow snapshots inventory and coinage, buys one known local test item from a visible vendor row, finds the newly-owned item GUID, sells that exact GUID back, and snapshots inventory/coinage again.
- `scenes/stage17_vendor_view.tscn` now has a `Buy + Sell` control and `ACORE_VENDOR_BUY_SELL_SELF_TEST=1`.
- Validation: native `--vendor-buy-sell` passed against local vendor entry `1213`, buying item id `17184` from slot `8`, observing buy opcode `0x1A4`, finding the bought item in slot `34`, selling it back without a sell error, and confirming `roundtrip_confirmed=1`.
- Validation: the live coinage path changed `9965 -> 9933 -> 9939`, proving buy and sell deltas through server-owned state while leaving the bought item slot restored.
- Validation: `ACORE_VENDOR_BUY_SELL_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage17_vendor_view.tscn` passed with `roundtrip=true`, buy opcode `0x1A4`, bought slot `34`, and roundtrip coinage delta `-26`.
- Remaining work: turn this fixed proof into normal row-selected vendor buy/sell UI, add quantity controls, item names/icons/tooltips through the local-only data pipeline, stock refresh, repair, failure-code UI, in-world click targeting, and persistent-session integration.

### 2026-07-01 - Vendor Selected Row Buy/Sell UI

- Moved the vendor `Buy + Sell` action from a fixed hidden test item path toward a normal vendor-window interaction.
- `scenes/stage17_vendor_view.tscn` now stores metadata for each live server-returned vendor row, tracks the selected row, shows selected slot/item/price/stock, and exposes a quantity control.
- The buy/sell action now sends the selected row's vendor slot, item id, and quantity through the existing server-authoritative buy/sell proof path.
- The headless self-test first refreshes the live vendor list and selects the known safe local row, so repeat validation still stays bounded while proving the player-facing selected-row path.
- Validation: `godot-4 --headless --path . --quit` passed.
- Validation: `ACORE_VENDOR_BUY_SELL_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage17_vendor_view.tscn` passed with selected item id `17184`, bought slot `34`, buy opcode `0x1A4`, `roundtrip=true`, and coinage delta `-26`.
- Validation: `ACORE_VENDOR_LIST_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage17_vendor_view.tscn` passed after the selected-row UI change.
- Remaining work: keep inventory visibly refreshed after purchase/sale, add stock refresh and failure-code UI, add repair, wire local-only item names/icons/tooltips, replace scan-list targeting with in-world click targeting, and move into a persistent world session.

### 2026-07-01 - Vendor Transaction Inventory Feedback

- Added visible transaction feedback to `scenes/stage17_vendor_view.tscn`.
- After a selected-row buy/sell proof, the scene now shows transaction success state, inventory snapshot presence, money deltas, and the bought slot state before buy, after buy, and after sell when the native extension provides slot dictionaries.
- Tightened `ACORE_VENDOR_BUY_SELL_SELF_TEST=1` so it now requires `inventory_before_seen`, `inventory_after_buy_seen`, and `inventory_after_sell_seen` in addition to the existing buy/sell roundtrip proof.
- Added `ACORE_VENDOR_UI_SELF_TEST=1` as a UI-lane validation path that renders selected-row and transaction feedback with synthetic dictionaries only, without invoking bridge or live-session code.
- Validation: `godot-4 --headless --path . --quit` passed.
- Validation: `ACORE_VENDOR_UI_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage17_vendor_view.tscn` passed with selected slot `8`, item id `17184`, 7 rendered result rows, and transaction snapshots `true/true/true`.
- Validation: `ACORE_VENDOR_BUY_SELL_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage17_vendor_view.tscn` passed with selected item id `17184`, bought slot `34`, buy opcode `0x1A4`, `roundtrip=true`, and coinage delta `-26`.
- Validation: `ACORE_VENDOR_LIST_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage17_vendor_view.tscn` still passed after the transaction feedback change.
- Remaining work: replace this transaction proof list with a persistent vendor/inventory layout that refreshes the actual inventory panel after buy/sell, add stock refresh and failure-code UI, add repair, and move the interaction into a persistent world session.

### 2026-07-01 - Settings And Keybindings First Slice

- Added `scenes/settings_view.tscn` and `scripts/settings_view.gd` as the first Godot-native options menu.
- Added dashboard navigation to the settings scene.
- The scene saves preferences to `user://settings.cfg`, applies window mode, window size, VSync, audio bus volume/mute state, and keybindings through `InputMap`.
- The self-test uses `user://settings-self-test.cfg`, removes it before and after validation, and does not commit or print secrets.
- Validation: `ACORE_SETTINGS_SELF_TEST=1 godot-4 --headless --path . res://scenes/settings_view.tscn` passed.
- Validation: `godot-4 --headless --path . --scene res://scenes/settings_view.tscn --quit` loaded the scene outside self-test mode.
- Local `qwen-agent` advisory review reported no blockers for the settings scene and dashboard navigation changes.
- Remaining work: add mouse/camera settings, UI scale, more complete keybind coverage, per-character/account scope decisions, and use these settings from the persistent gameplay HUD.

### 2026-07-01 - Gameplay Sandbox Consumes Saved Keybindings

- Added `scripts/settings_runtime.gd` as shared settings load/save/apply code for the settings scene and gameplay consumers.
- Expanded default keybindings to include movement, camera yaw, target cycling, primary attack, interact, reset, and jump actions.
- Updated `scenes/gameplay_sandbox.tscn` logic to apply saved keybindings at startup and use `InputMap` actions instead of hardcoded movement/action keys.
- Updated the modular sandbox bootstrap to apply the same saved keybindings before registering fallback defaults.
- Validation: `ACORE_SETTINGS_SELF_TEST=1 godot-4 --headless --path . res://scenes/settings_view.tscn` still passed after the shared runtime refactor.
- Validation: `ACORE_SANDBOX_KEYBIND_SETTINGS_SELF_TEST=1 godot-4 --headless --path . res://scenes/gameplay_sandbox.tscn` passed, proving the sandbox consumes a saved `move_forward=KEY_UP` binding.
- Validation: `ACORE_SANDBOX_SELF_TEST=1 godot-4 --headless --path . res://scenes/gameplay_sandbox.tscn` still passed after switching to action-based input.
- Local `qwen-agent` advisory review reported no blockers for the shared settings runtime and sandbox input changes.
- Remaining work: carry the shared settings runtime into the future persistent world HUD, live camera controls, and broader interaction/combat keybinds.
