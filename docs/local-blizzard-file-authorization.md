# Local Blizzard File Authorization

## Purpose

This project is an authorized local prototype for evaluating how well AI agents can help create a fully functional Godot-native WotLK client/port while using the local AzerothCore setup.

The goal is not a companion-only tool, not a reimagined game, and not a half-port that still depends on the original WotLK executable for normal play. The original client is a local reference/input source and validation target only.

The project owner has instructed Codex and future AI agents to use the Blizzard/WotLK files available on this local machine as inputs for the porting work.

## Authorized Local Inputs

For this prototype, all Blizzard/WotLK client files available in the documented local client locations are authorized for local use on this machine.

Known local client locations:

```text
WotLK client:       /run/media/doodbro/5e07d7d7-039f-43a8-94da-999f100ab1fb/World of Warcraft - WoTLK
Bundle client copy: /run/media/doodbro/New 1tb/AzerothCore/client
```

Authorized local use includes:

- inspecting file structure, metadata, and local manifests,
- building local scanners, importers, converters, validators, and diagnostic tools,
- generating Godot import pipelines that read local client files,
- creating ignored local converted outputs for prototype testing,
- using local client behavior and assets as reference material for the Godot port.

## Autonomous Work Directive

Codex and future agents should work autonomously toward the prototype goal:

- plan the next safe stage,
- implement the needed tools or Godot project changes,
- use the local Blizzard/WotLK files when needed for the port,
- verify with local checks,
- document decisions and blockers,
- commit and push non-proprietary project changes.

The goal is to let the project owner's company evaluate future product use and design patterns for AI-assisted full client porting and game-engine work.

## GitHub Boundary

The authorization above is local-only. It does not authorize pushing proprietary files.

GitHub may receive:

- original Godot code, scenes, and tools,
- documentation,
- local path references,
- manifests that contain paths, hashes, IDs, counts, or descriptions,
- importer/converter source code,
- placeholder or original assets created for this project.

GitHub must not receive:

- Blizzard/WotLK MPQs,
- extracted Blizzard/WotLK models, textures, maps, sounds, music, or database/client files,
- converted derivatives from proprietary client files,
- raw binary payloads,
- proprietary file contents pasted into docs, logs, commit messages, or issues,
- secrets, cookies, passwords, private configs, or runtime dumps.

## Local Output Rule

Any extracted, converted, cached, or generated files derived from proprietary Blizzard/WotLK files must go into ignored local-only folders such as:

```text
local_assets/
proprietary_assets/
client_assets/
extracted_client_assets/
```

Code and documentation may reference those outputs by local path, hash, count, or description, but should not commit the files themselves.

## Agent Handling Rule

Prefer local tooling for proprietary file inspection. Avoid dumping raw proprietary file contents into chat transcripts or tracked documentation unless the project owner explicitly asks for a tiny diagnostic excerpt and it is necessary for debugging.

When in doubt:

- use local tools,
- summarize metadata,
- commit code/docs only,
- leave the files themselves local and ignored.
