# Godot-AzerothCore-WotLK Master Plan

## Mission

Build toward a Godot-powered AzerothCore WotLK game/client experience.

The long-term dream is a Godot client that can reproduce the WotLK client experience as closely as possible while using AzerothCore as the server/backend. This must be built in layers. The project begins with Path A, then moves to Path B only after Path A is achieved.

## Path Order

### Path A First: Godot As Its Own MMO Engine Layer

Path A builds a working Godot game engine layer using original placeholder content, AzerothCore-shaped data, bridge services, and Godot-native networking.

This gives us:

- A useful companion app immediately.
- A safe command and data layer.
- A playable Godot RPG sandbox.
- A multiplayer proof of concept.
- A persistence model we control.
- Real engine experience before attempting the WotLK protocol.

Path A is achieved when Godot can run a small multiplayer RPG loop using AzerothCore data/bridge support, with login-like identity, characters, movement, NPCs, combat, inventory placeholders, and persistence.

### Path B Second: Godot As An AzerothCore-Compatible WotLK Client

Path B begins after Path A works.

Path B attempts the faithful port/replacement-client goal:

- Godot connects to AzerothCore through compatible auth/world protocol work.
- Godot receives and interprets server object updates.
- Godot sends movement, interaction, chat, combat, spell, loot, inventory, and quest actions.
- Godot recreates the WotLK client experience as faithfully as possible in behavior and presentation.

The WotLK client remains a local reference client and input source. Under the project owner's stated authorization, all Blizzard/WotLK client files available on this machine may be used locally for this prototype, but they must stay untracked and out of Git/GitHub. See [local-blizzard-file-authorization.md](local-blizzard-file-authorization.md) and [asset-handling-policy.md](asset-handling-policy.md).

## Definition Of "Port The Client"

For this project, "port the WotLK client to Godot" means rebuilding the client-side functionality in Godot:

- rendering layer,
- input layer,
- UI layer,
- networking/client protocol layer,
- movement prediction/reconciliation,
- object visibility,
- combat feedback,
- inventory/equipment UI,
- quest UI,
- chat/social systems,
- world/map presentation,
- tooling and diagnostics.

It does not mean copying the old executable or importing proprietary files into this Git repo.

## Living Documentation Rule

Each stage has a dedicated file in `docs/stages/`.

As changes occur:

- Update the active stage file.
- Record decisions and blockers.
- Mark checklist items complete.
- Add links to commits, scripts, scenes, bridge endpoints, or test notes.
- Keep `docs/task-log.md` for chronological task history.

## Local AI Resources

This project has local AI support available through Ollama.

Primary local coding model:

```text
qwen2.5-coder:7b
```

Additional local model:

```text
qwen-agent:latest
```

See [local-ai-resources.md](local-ai-resources.md) for usage notes and guardrails.

## Asset Handling

The repo tracks original code, documentation, tooling, placeholder assets, and references to local client paths. The local project folder may contain ignored private asset folders for the authorized local prototype, but Git must not track proprietary WotLK MPQs, extracted assets, or converted derivatives.

See [local-blizzard-file-authorization.md](local-blizzard-file-authorization.md) and [asset-handling-policy.md](asset-handling-policy.md).

## Stage Index

Path A:

- [Stage 00 - Foundation](stages/stage-00-foundation.md)
- [Stage 01 - Companion Dashboard](stages/stage-01-companion-dashboard.md)
- [Stage 02 - Command Layer](stages/stage-02-command-layer.md)
- [Stage 03 - Read-Only Data Browser](stages/stage-03-read-only-data-browser.md)
- [Stage 04 - Local Bridge Service](stages/stage-04-local-bridge-service.md)
- [Stage 05 - Godot Gameplay Sandbox](stages/stage-05-godot-gameplay-sandbox.md)
- [Stage 06 - Data-Driven Sandbox](stages/stage-06-data-driven-sandbox.md)
- [Stage 07 - Godot-Native Multiplayer](stages/stage-07-godot-native-multiplayer.md)
- [Stage 08 - Persistence Layer](stages/stage-08-persistence-layer.md)
- [Stage 09 - Path A Completion Gate](stages/stage-09-path-a-completion-gate.md)

Path B:

- [Stage 10 - Protocol Research](stages/stage-10-protocol-research.md)
- [Stage 11 - Minimal Protocol Client](stages/stage-11-minimal-protocol-client.md)
- [Stage 12 - Enter World Prototype](stages/stage-12-enter-world-prototype.md)
- [Stage 13 - Movement And Reconciliation](stages/stage-13-movement-and-reconciliation.md)
- [Stage 14 - Object Visibility](stages/stage-14-object-visibility.md)
- [Stage 15 - Combat And Interaction](stages/stage-15-combat-and-interaction.md)
- [Stage 16 - WotLK Client Feature March](stages/stage-16-client-feature-march.md)

## Current Status

Current stage: Stage 01 should be the next implementation target.

Reason: the project already has a Godot shell and known local paths. The next useful step is making the dashboard operate the local AzerothCore setup.

## Non-Negotiable Safety Rules

- Do not reset or revert local AzerothCore source changes unless explicitly requested.
- Do not write directly into AzerothCore character/world/auth tables until a stage explicitly allows it.
- Do not put secrets into Godot scenes.
- Do not commit, push, or share proprietary client assets or converted derivatives.
- Use the local Blizzard/WotLK files as authorized local inputs when they are needed for the port.
- Verify local AI model output before committing it.
- Keep every meaningful task committed and pushed.
