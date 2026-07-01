# Stage 17 - Full Port Acceptance Gate

Status: In progress

## Goal

Verify that the Godot client is a fully functional WotLK port for AzerothCore, not a companion tool, not a reimagined game, and not a partial prototype.

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
