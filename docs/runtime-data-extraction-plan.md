# Runtime Data Extraction Plan

## Purpose

Worldserver previously reached local data loading and stopped because the AzerothCore runtime data folders were missing.

This document tracks the completed local-only process for generating the required AzerothCore runtime data from the authorized local WotLK client files.

## Local Inputs

Authorized local client input:

```text
/run/media/doodbro/New 1tb/AzerothCore/client
```

Current client evidence:

- `Wow.exe` is present.
- Core MPQ archives are present under `Data/`.

## Local Outputs

Expected local-only output root:

```text
/run/media/doodbro/New 1tb/AzerothCore/data
```

Required subfolders/files:

- `maps/`
- `dbc/`
- `vmaps/`
- `mmaps/`

These outputs are generated from proprietary local client data and must remain outside Git/GitHub.

Verified local-only output counts on 2026-06-30:

- `dbc`: 246 `.dbc` files, about 87 MB.
- `maps`: 5744 `.map` files, about 289 MB.
- `Cameras`: about 60 KB.
- `vmaps`: 101 `.vmtree` files and 2693 `.vmtile` files, about 658 MB.
- `mmaps`: 98 `.mmap` files and 3682 `.mmtile` files, about 2.1 GB.

## Extractor Tooling

Initial status before this task:

```text
TOOLS_BUILD=none
```

The build was reconfigured locally with:

```text
TOOLS_BUILD=maps-only
```

Built Linux tools:

- `map_extractor`
- `vmap4_extractor`
- `vmap4_assembler`
- `mmaps_generator`

The tools were built under `/home/doodbro/azeroth-build/src/tools/`.

## Step Plan

1. Build the AzerothCore extraction tools. Done.
2. Locate the generated Linux tool binaries. Done.
3. Run map/DBC extraction against the local bundle client. Done.
4. Run VMap extraction and assembly. Done.
5. Run MMap generation. Done.
6. Move required generated runtime data into `/run/media/doodbro/New 1tb/AzerothCore/data`. Done.
7. Re-run `tools/audit_server_stack.py`. Done.
8. Start the AzerothCore stack and verify whether worldserver reaches port `8085`. Done.
9. Document results and follow-up work in `docs/task-log.md`. Done.

## Verified Result

The local stack reached a live game-server state after the extraction and startup-script repairs:

- MySQL: `127.0.0.1:3306` listening.
- Authserver: `0.0.0.0:3724` listening.
- Worldserver: `0.0.0.0:8085` listening.
- Ollama: `127.0.0.1:11434` listening.
- LLM bridge: running.

Worldserver logged `WORLD: World Initialized In 1 Minutes 1 Seconds` and `worldserver-daemon ready`.

## Local Cleanup

The temporary VMap extraction scratch folder at `/run/media/doodbro/New 1tb/AzerothCore/client/Buildings` was removed after successful verification. The final runtime outputs remain in `/run/media/doodbro/New 1tb/AzerothCore/data`.

## Safety Boundary

- Do not commit extracted data.
- Do not commit MPQs or converted derivatives.
- Do not paste proprietary file contents into docs.
- Commit only documentation, scripts, manifests, or tooling source that does not include proprietary payloads.
