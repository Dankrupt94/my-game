# Godot-AzerothCore-WotLK Master Plan

## Mission

Build a fully functional Godot-native WotLK client/port for the local AzerothCore setup.

The destination is not a companion app, not a reimagined game, not a partial proof of concept, and not continued dependence on the original WotLK client as the player-facing runtime. The destination is a Godot client that can replace the original WotLK client for normal play against AzerothCore as completely as possible.

Some features may need technical tweaks because Godot, Linux, local tooling, or AzerothCore differ from the original client environment. Those tweaks must be documented as compatibility deviations, not treated as permission to redesign the game.

This must be built in layers. The project begins with Path A, then moves to Path B only after Path A is achieved. Path A is scaffolding, learning, tooling, and risk reduction. Path B is the actual port destination.

## Path Order

### Path A First: Godot As Its Own MMO Engine Layer

Path A builds a working Godot game engine layer using original placeholder content, AzerothCore-shaped data, bridge services, and Godot-native networking.

This gives us:

- A useful companion app immediately, but only as a bootstrap tool.
- A safe command and data layer.
- A playable Godot RPG sandbox.
- A multiplayer proof of concept.
- A persistence model we control.
- Real engine experience before attempting the WotLK protocol.

Path A is achieved when Godot can run a small multiplayer RPG loop using AzerothCore data/bridge support, with login-like identity, characters, movement, NPCs, combat, inventory placeholders, and persistence.

Path A is not an acceptable final product. A working dashboard, sandbox, database browser, or original Godot MMO loop does not satisfy the project goal by itself.

### Path B Second: Godot As An AzerothCore-Compatible WotLK Client

Path B begins after Path A works.

Path B attempts the faithful port/replacement-client goal:

- Godot connects to AzerothCore through compatible auth/world protocol work.
- Godot receives and interprets server object updates.
- Godot sends movement, interaction, chat, combat, spell, loot, inventory, and quest actions.
- Godot recreates the WotLK client experience as faithfully as possible in behavior and presentation.

The WotLK client remains a local reference client and input source only. It is useful for comparison, behavior study, local file inputs, and validation, but it is not the final runtime and does not satisfy the goal.

Under the project owner's stated authorization, all Blizzard/WotLK client files available on this machine may be used locally for this prototype, but they must stay untracked and out of Git/GitHub. See [local-blizzard-file-authorization.md](local-blizzard-file-authorization.md) and [asset-handling-policy.md](asset-handling-policy.md).

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

It does not mean copying the old executable, using the original client as the player-facing runtime, stopping at a dashboard, or importing proprietary files into this Git repo.

## Full Port Acceptance Standard

The project should only be considered a completed WotLK Godot port when Godot can provide the normal player-facing client experience against AzerothCore without launching the original WotLK client.

Acceptance requires:

- auth, realm, character selection, and enter-world flows through Godot,
- server-authoritative movement, visibility, combat, spell, interaction, loot, inventory, quest, chat, social, group, guild, mail, vendor, trainer, auction, map/minimap, and settings flows,
- faithful UI/UX behavior where practical,
- local asset/data pipelines that support the required visual/audio/world presentation while keeping proprietary files local-only,
- documented deviations where a feature must be adapted for Godot or AzerothCore,
- regression tests or manual test checklists for major feature areas.

No feature should be permanently treated as "good enough to skip" unless a later documented decision explicitly explains why exact parity is impossible or intentionally deferred.

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
- [Stage 17 - Full Port Acceptance Gate](stages/stage-17-full-port-acceptance-gate.md)

## Logical Plan Concerns & Risks

To ensure the logical porting plan remains sound, the following technical and architectural concerns must be actively managed:

- **SRP6 & RC4 Cryptography (Stage 11):** The WotLK login flow utilizes SRP6, and the world server connection encrypts packet headers using an RC4-like cipher. Because pure GDScript is computationally slow and complex for this, compiled libraries (such as C# libraries or a C++ GDExtension helper) should be prioritized during Stage 10 research.
- **Proprietary Asset Pipeline (Stage 14 / Path B):** Faithfully porting the client requires parsing proprietary client assets (`.m2` models, `.blp` textures, `.adt` terrain, `.wmo` world objects) from local MPQ archives. A dedicated offline/runtime local converter must be designed to dump standard structures (e.g., GLTF, PNG) into Git-ignored local folders, ensuring proprietary files remain local-only while keeping conversion tools tracked.
- **Movement Synchronization & Desyncs (Stage 13):** WoW uses client-predicted movement verified by server heartbeats and fall/jump speed checks. Desyncs cause server-side rubber-banding or disconnects. Stage 13 must focus on simple "read-only movement mimicry" (mimicking a character controlled by an official client) before introducing direct client-authoritative movement inputs from Godot.

## Nice-to-Have Future Enhancements

These optimizations and visual enhancements can be introduced in later stages or post-port to improve fidelity, speed, and safety:

- **Physically Based Rendering (PBR) Materials:** Generate normal, roughness, and metallic maps procedurally from client diffuse textures during local conversion. Enable PBR shader parameters to support wetness during weather effects and metal specular reflections.
- **Global Illumination & Atmospheres:** Leverage Godot 4’s **SDFGI (Signed Distance Field Global Illumination)** for dynamic light bounces in dungeons and caves, and dynamic directional lights mapping to the server’s day/night cycles. Add volumetric fog and Screen Space Reflections (SSR) for realistic water surfaces.
- **VRAM Optimizations:** Compress converted assets to BPTC (Vulkan Desktop) format. Batch repetitive town/dungeon props (barrels, crates, fences) via `MultiMeshInstance3D` to minimize draw calls, and configure automatic mesh LODs.
- **Zone-Based VRAM Streaming:** Implement a chunked asset-streaming system aligned with the client’s ADT map grid. Unload meshes and textures beyond a 2-chunk radius to maintain a stable, lightweight VRAM footprint.
- **Rust GDExtension Parser:** Implement the core network stream reader, opcode decryption, and the heavy packet parsing logic (`SMSG_UPDATE_OBJECT`) in Rust via a GDExtension helper (`godot-rust`). This achieves native C++ execution speeds with zero-copy packet deserialization, eliminating GDScript garbage collection spikes while guaranteeing memory safety.

## Current Status

Current stage: Stage 06 is complete; Stage 07 is next.

Reason: the project already has a Godot shell, known local paths, installed Linux server binaries, reachable local databases, generated local runtime data, a verified live AzerothCore stack on ports `3306`, `3724`, `8085`, and `11434`, a completed read-only data browser, a hardened localhost bridge boundary, a playable original Godot sandbox scene, and a data-driven sandbox slice that displays and spawns placeholders from read-only AzerothCore records. Stage 07 should begin the Godot-native multiplayer prototype.

## Non-Negotiable Safety Rules

- Do not reset or revert local AzerothCore source changes unless explicitly requested.
- Do not write directly into AzerothCore character/world/auth tables until a stage explicitly allows it.
- Do not put secrets into Godot scenes.
- Do not commit, push, or share proprietary client assets or converted derivatives.
- Use the local Blizzard/WotLK files as authorized local inputs when they are needed for the port.
- Verify local AI model output before committing it.
- Keep every meaningful task committed and pushed.
