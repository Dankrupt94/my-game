# Client Feature Parity Matrix

Status: Active during Stage 16

## Purpose

This matrix tracks the march from the current Godot protocol prototype toward a fully functional Godot-native WotLK client for AzerothCore.

The target is not a companion dashboard, a partial client, or a reimagined MMO. Every normal player-facing client feature needs either a working Godot implementation or an explicit compatibility note explaining what remains and why.

## Current Foundation

| Foundation Area | Status | Evidence | Remaining Work |
| --- | --- | --- | --- |
| Auth and realm connection | Working prototype | Stage 11 protocol helper authenticates and reaches realm/world flow. | Harden retry/error handling and long-session stability. |
| Character listing | Working prototype | Stage 11/12 helper can list characters. | Build full Godot character-select UI. |
| Enter world | Working prototype | Stage 12 enters the world and reads initial server state. | Keep session alive through broader feature usage. |
| Movement | Working prototype | Stage 13 sends movement and verifies drift. | Add complete movement modes, prediction, collisions, fall/swim/fly edge cases, and manual tests. |
| Object visibility | Working prototype | Stage 14 parses nearby creatures/gameobjects. | Expand update-field parsing, despawns, object values, dynamic objects, corpses, and players. |
| Targeting, interaction, combat probe | Working prototype | Stage 15 targets live object GUIDs, opens gossip, and starts combat. | Add complete combat loop, spells, range/facing feedback, death, regen, and loot. |

## Stage 16 Feature Areas

| Feature Area | Stage 16 Status | Protocol/Data Targets | Godot Surface | Validation Target | Current Notes |
| --- | --- | --- | --- | --- | --- |
| Chat | Working expanded slice | `CMSG_MESSAGECHAT`, `SMSG_MESSAGECHAT`, basic say type, self-whisper type, race language selection, server echo parse. | `scenes/stage16_chat_view.tscn` with chat log, mode selector, input, and send button. | `ACORE_CHAT_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage16_chat_view.tscn` returns say echo and self-whisper/inform responses through opcode `0x096`. | Say and self-whisper round trips work. Remaining chat parity includes true receiver-side whispers, channels, party/guild/raid chat, system filters, tabs, history, and social integration. |
| Inventory | Planned | Bag inventory lists, item update fields, swap/split/use packets. | Backpack and bag grid. | Load inventory from live character and move/use a safe item. | Needs fuller item update-field parsing. |
| Equipment | Planned | Equipment slots, durability, item stats, equip/unequip packets. | Character paper doll. | Equip or unequip a harmless item and confirm server state. | Depends on inventory parsing. |
| Loot | Planned | Loot response packets, loot slots, money, roll flows. | Loot window. | Kill a creature and loot from Godot. | Depends on complete combat loop. |
| Vendors | Planned | Gossip/vendor list packets, buy/sell/repair packets. | Vendor window. | Open vendor, inspect list, buy/sell a safe item. | Builds from Stage 15 gossip. |
| Quests | Planned | Quest gossip, accept/complete, objective tracking, reward selection. | Quest detail, tracker, reward UI. | Accept and complete a simple test quest. | Requires database-assisted quest target selection. |
| Trainers | Planned | Trainer list, learn-spell packet, money checks. | Trainer window. | View trainer list and learn a safe spell if available. | Builds from gossip and spellbook. |
| Spells | Working expanded slice | `SMSG_INITIAL_SPELLS` parser, initial spell IDs, cooldown rows present in packet, `CMSG_CAST_SPELL`, empty-target casts, unit-target casts, `SMSG_SPELL_START`, `SMSG_SPELL_GO`. | `scenes/stage16_spellbook_view.tscn` with spell list and `scenes/stage16_spell_cast_view.tscn` with no-target and unit-target cast tests. | `ACORE_SPELLBOOK_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage16_spellbook_view.tscn` returns 48 initial spells. `ACORE_SPELL_CAST_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage16_spell_cast_view.tscn` casts spell `2457` and receives opcode `0x132`. `ACORE_TARGETED_SPELL_CAST_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage16_spell_cast_view.tscn` casts spell `78` at a live nearby creature and receives opcode `0x131`. | Read-only spellbook, safe no-target casting, and live unit-target casting work. Remaining spell parity includes names/icons/ranks, item/destination/string targets, cooldown update packets, interrupt/fail messages, auras, damage/healing consequences, and combat results. |
| Action bars | Working first slice | `SMSG_ACTION_BUTTONS` parser, 144 packed action slots, action id/type unpacking. | `scenes/stage16_action_bar_view.tscn` with read-only slot grid and populated-slot details. | `ACORE_ACTION_BAR_SELF_TEST=1 godot-4 --headless --path . res://scenes/stage16_action_bar_view.tscn` returns 144 slots and 3 populated slots for `Codexstage`. | Read-only server-provided action buttons work. Remaining action-bar parity includes names/icons, drag/drop placement, keybinds, `CMSG_SET_ACTION_BUTTON`, persistence checks, macros, items, equipment sets, and spell casting from slots. |
| Auras | Planned | Aura update fields, buff/debuff display, durations. | Unit frames and buff bars. | Observe an aura appear/disappear correctly. | Depends on update-field parser expansion. |
| Groups | Planned | Invite/accept/leave, party member updates, loot settings. | Party frames and invite dialogs. | Form and leave a local party. | Likely needs a second local test character/session. |
| Guilds | Planned | Guild roster, invite, chat, rank permissions. | Guild panel. | Read guild state or create a controlled local test guild. | Needs careful local-only state changes. |
| Mail | Planned | Mailbox list/read/send/delete. | Mailbox UI. | Read local test mail and optionally send to a test character. | Requires mailbox object discovery. |
| Auction house | Planned | Browse/search/bid/buyout/sell packets. | Auction house browser. | Browse auction listings from Godot. | Later-stage high-complexity UI/protocol work. |
| Maps/minimap | Planned | Map position, zone/area, POIs, discovered areas. | Map and minimap. | Show current map/zone and player marker. | Visual fidelity depends on local-only asset/data pipeline. |
| Addon-like UI customization | Planned | Saved UI layout/config only; not Lua compatibility initially. | Movable/resizable panels and saved settings. | Persist UI layout across runs. | Full addon API is a separate major effort. |
| Settings | Planned | Video/audio/input/interface settings. | Options menu. | Persist settings and apply keybindings. | Godot-native implementation with compatibility mapping. |

## Compatibility Rules

- Prefer exact AzerothCore/WotLK protocol behavior where possible.
- When Godot requires a technical adaptation, document it as a compatibility deviation.
- Keep proprietary client assets, extracted files, converted derivatives, secrets, account config, and generated runtime data out of Git.
- Use local AI models only as bounded advisory reviewers for non-sensitive snippets; the project checks remain the source of truth.
- Update this matrix whenever a feature moves from planned to in progress, working prototype, complete, blocked, or explicitly deferred.

## Stage 17 Gate Link

Stage 17 can only be treated as reached when this matrix shows the normal client feature surface is implemented or has explicit, justified compatibility notes, and Godot can serve as the player-facing client for ordinary AzerothCore play without launching the original client.
