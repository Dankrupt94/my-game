# WotLK Client Parity Engine Spec

Status: Active Stage 17 reference

## Purpose

This file is the Stage 17 engine-level definition of a fully functional Godot-native WotLK client for AzerothCore.

The target is not a helper dashboard, a partial protocol tester, a reimagined MMO, or a Godot front end that still depends on the original WotLK executable for normal play. Stage 17 is only complete when Godot can serve as the player-facing game client for ordinary local AzerothCore play.

## Authority In The Plan

- The master plan defines the project direction.
- `docs/client-feature-parity-matrix.md` tracks feature-by-feature progress.
- `docs/stages/stage-17-full-port-acceptance-gate.md` tracks the final acceptance gate.
- This spec defines the detailed engine surface that Stage 17 must satisfy before the port can be called fully playable.

If another document says a feature slice is done but this spec still lists normal client behavior that is missing, the feature remains incomplete for full-port acceptance.

## Non-Negotiable Constraints

- Godot is the runtime game engine.
- AzerothCore is the authoritative server.
- The original WotLK client is allowed only as a local comparison or validation reference, not as a runtime dependency.
- Proprietary client archives, extracted files, converted derivatives, account files, secrets, generated cache data, and runtime logs stay out of Git.
- Local-only data and asset pipelines may read authorized local files from ignored folders, but the repo must store only original code, docs, tooling, placeholders, and metadata that is safe to share.
- Local Ollama models, including `qwen-agent`, may be used as bounded advisory reviewers for safe snippets. They do not replace compiler, Godot, protocol, or live-server validation.

## Acceptance Evidence Pattern

Each major feature area needs the same proof pattern before it can move from a prototype slice to parity-complete:

- Godot surface: a player-facing UI or in-world interaction path exists.
- Protocol proof: the Godot client sends and receives the expected AzerothCore/WotLK packets.
- Server-state proof: the server-owned state changes or remains stable as expected.
- Regression proof: a headless self-test, focused tool check, or manual checklist can reproduce the behavior.
- Documentation proof: the parity matrix, Stage 17 gate, task log, and relevant packet/data notes are updated.
- Deviation proof: any Godot-specific adaptation is documented with the reason and user-visible impact.

## Engine Subsystems Required For Full Playability

### Session And Connection

- Login, realm listing, character listing, character selection, and enter-world flow.
- Authenticated world session with encrypted headers and reconnect-safe error handling.
- Time sync, ping/pong, logout, disconnect, retry, and crash-safe cleanup behavior.
- Persistent session reuse across normal play instead of one-shot helper probes.

### Character Lifecycle

- Character select screen with race/class/faction display, level, zone, equipment preview, and delete/create flows when safe.
- Enter-world loading flow with progress and useful failure messages.
- Character data refresh after equipment, quest, spell, currency, reputation, and location changes.

### World State And Object Visibility

- Full object create/update/out-of-range parsing for players, creatures, gameobjects, dynamic objects, corpses, and owned items.
- Stable runtime GUID model for selection, combat, interaction, loot, quest objectives, and UI frames.
- Health, power, level, faction, flags, dynamic flags, display ids, movement, stand state, and aura-relevant fields.
- Despawn, respawn, phasing/visibility, and range transition behavior.

### Movement, Physics, And Reconciliation

- Player input for walking, running, strafing, turning, jumping, falling, swimming, sitting, mounts, and collision-friendly traversal.
- Server-authoritative movement packets with reconciliation, anti-cheat-safe timing, and rubber-band recovery.
- Camera, mouse look, click-to-move compatibility decisions, and collision behavior that feels playable in Godot.
- Terrain, liquid, transport, elevator, and indoor/outdoor edge cases tracked as explicit parity items.

### Targeting, Interaction, And Combat

- In-world click targeting by exact GUID, target frames, hover feedback, and target clearing.
- Auto attack, attack stop, facing/range feedback, threat/combat state, death, regen, and corpse transition.
- Melee, ranged, spell-start, spell-go, interrupts, misses, resists, dodges, parries, blocks, crits, and damage/heal feedback.
- NPC gossip, gameobject interaction, trainers, vendors, mailboxes, auctioneers, questgivers, and lootable corpses.

### Spells, Auras, Cooldowns, And Action Bars

- Spellbook, ranks, passive/active spells, shapeshift/forms where applicable, and spell detail display.
- Targeted, self, ground, item, and destination spell casts.
- Cast bars, interrupts, global cooldown, per-spell cooldowns, item cooldowns, and failure reasons.
- Buff/debuff auras on player, target, party, and nearby units with duration and stack display.
- Action bars with drag/drop, keybinds, paging, stance/form bars, item actions, macros where feasible, and saved layout.

### Inventory, Equipment, Items, And Loot

- Equipment, backpack, bags, bank, keyring/reagent-style slots where applicable, currency/coinage, and item durability.
- Drag/drop moves, swaps, stack split/merge, item use, destroy, equip, unequip, repair, sell, buy, trade, mail, auction, and error handling.
- Item templates, names, icons, quality, class/subclass, bind rules, stats, requirements, cooldowns, charges, and tooltips.
- Loot windows, corpse loot, money loot, autostore, manual slot pickup, full-bag handling, bind prompts, loot errors, group loot, rolls, and quest loot.
- Inventory refresh after every item mutation, with server state treated as the source of truth.

### Quests, NPC Services, And Progression

- Quest offer, accept, objective tracking, progress, completion, reward choice, abandonment, sharing where applicable, and failure states.
- Gossip menus, vendor lists, buy/sell/repair, trainer lists, spell learning, innkeepers, flight masters, banks, guild banks, stable masters where applicable.
- XP, level-up, skill, reputation, honor, achievements or equivalent server messages as supported by the target core.

### Social, Chat, Group, Guild, Mail, And Auction House

- Say, yell, whisper, party, raid, guild, officer, channel, emote, system, combat-log, and server-message display.
- Friends, ignore, who, party invite/accept/leave, raid conversion, party frames, loot settings, ready checks where supported.
- Guild roster, ranks, invites, guild chat, message of the day, and permissions appropriate to the target server.
- Mailbox list/read/send/delete, attachments, COD behavior if supported.
- Auction browse/search/bid/buyout/sell/cancel and enough filtering to be usable.

### Maps, Minimap, World Presentation, And Audio

- Current map/zone/area, player marker, discovered areas, minimap rotation/zoom decisions, quest markers, vendors/trainers/mail markers where available.
- Terrain, world objects, doodads, water, sky, weather, lighting, fog, and zone transitions through a local-only asset/data pipeline.
- Character, creature, item, spell, UI, and environment visuals sourced through safe local conversion or placeholder-backed development until parity assets are available locally.
- Music, ambience, UI sounds, spell sounds, combat sounds, and volume settings through local-only pipelines or documented placeholders.

### UI, Input, Settings, And Accessibility

- Main HUD, unit frames, bags, spellbook, action bars, quest log/tracker, map/minimap, social panels, chat, options, character panel, inspect/trade/mail/vendor/auction windows.
- Keyboard/mouse input, keybind persistence, camera controls, UI scale, window/fullscreen settings, audio/video settings, and saved user preferences.
- Clear error dialogs for auth, packet, server-state, inventory, loot, spell, movement, and service failures.

### Persistence, Stability, Performance, And Tooling

- Multi-minute and long-session play tests without launching the original client.
- Clean logout, reconnect, scene reload, and crash-recovery behavior.
- Headless tests for protocol slices and manual checklists for visual/in-world flows.
- Performance budgets for world update parsing, rendering, UI refresh, packet handling, and local conversion tools.
- Logs that help debug without leaking secrets or proprietary file paths into committed artifacts.

## Current Stage 17 Focus

The immediate Stage 17 work is still a narrow slice inside this larger spec:

- Stabilize exact visible target GUID selection in `scenes/stage17_loot_view.tscn`.
- Restore the loot-to-inventory handoff self-test to green using the selected target GUID instead of relying on entry-only selection.
- Keep the player-facing loot scene moving from test buttons toward normal target, combat, loot, and inventory UI.
- Add common NPC service slices, starting with trainer-list parity through `scenes/stage17_trainer_view.tscn`, while keeping learn-spell, vendor, quest, and other service mutations explicitly tracked.
- Document every proof as a step toward this full spec, not as final parity by itself.

## Full-Port Exit Rule

Stage 17 is not complete until a user can start Godot, log into AzerothCore, select a character, enter the world, move around, interact, fight, cast, loot, manage inventory/equipment, quest, use common NPC services, chat/socialize, and configure normal client settings through Godot without launching the original WotLK client.

Remaining deviations must be specific, justified, user-visible, and tracked. Broad labels like "not implemented yet" or "use the old client for this part" do not satisfy the full-port exit rule.
