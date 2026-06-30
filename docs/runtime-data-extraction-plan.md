# Runtime Data Extraction Plan

## Purpose

Worldserver now reaches local data loading, but stops because the AzerothCore runtime data folders are missing.

This document tracks the local-only process for generating the required AzerothCore runtime data from the authorized local WotLK client files.

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
- `maps/0000.map`
- `dbc/`
- `vmaps/`
- `mmaps/`

These outputs are generated from proprietary local client data and must remain outside Git/GitHub.

## Extractor Tooling

Initial status:

```text
TOOLS_BUILD=none
```

The build has now been reconfigured locally with:

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
3. Run map/DBC extraction against the local bundle client. In progress.
4. Run VMap extraction and assembly. Pending.
5. Run MMap generation if feasible. Pending.
6. Re-run `tools/audit_server_stack.py`.
7. Start the AzerothCore stack and verify whether worldserver reaches port `8085`.
8. Document results and blockers in `docs/task-log.md`.

## Safety Boundary

- Do not commit extracted data.
- Do not commit MPQs or converted derivatives.
- Do not paste proprietary file contents into docs.
- Commit only documentation, scripts, manifests, or tooling source that does not include proprietary payloads.
