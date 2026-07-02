# Playable Toolchain

This file records the local developer tools installed to speed up the path from
protocol proofs to a playable Godot-native AzerothCore client.

## Why These Tools Matter

- Godot 4 runs the client prototype and headless smoke tests.
- Blender, Assimp, glTF Transform, gltfpack, ImageMagick, and FFmpeg make local
  visual/audio conversion experiments faster once the port reaches the asset
  pipeline work.
- smpq and warcraft-rs give us local-only inspection for MPQ archives and common
  World of Warcraft client formats before we decide what metadata, conversion
  code, or generated Godot import path is safe to build.
- SQLite, sqlite-utils, jq, tshark, tcpdump, and scapy make local data and
  packet inspection faster without hand-copying runtime data into docs.
- Xvfb, xdotool, wmctrl, and Wine make GUI automation and local reference-client
  comparison possible. Wine is for authorized local comparison only; the target
  remains a Godot-native client that does not depend on the original executable.
- apitrace gives a local graphics diagnostics path when Godot rendering becomes
  complex. Treat apitrace outputs like local-only runtime evidence: they can
  reveal frames, paths, or other test context and should stay in ignored local
  folders. RenderDoc is still deferred because it was not available from apt or
  Snap on this machine during this pass.
- cargo-watch, Ninja, shellcheck, gdformat, and gdlint shorten repeated edit,
  build, and validation loops.

## Installed Or Integrated On 2026-07-01

- System packages: `blender`, `assimp-utils`, `imagemagick`, `xvfb`,
  `xdotool`, `wmctrl`, `wine64`, `apitrace`, `python3-scapy`, `pipx`, and
  `gltfpack`.
- User-local packages: `@gltf-transform/cli`, `sqlite-utils`, and
  `cargo-watch`.
- Repo integration: `tools/check_playable_toolchain.sh`.

## Added On 2026-07-01 After Follow-Up

- System package: `smpq`.
- User-local package: `warcraft-rs`.
- Local model installed for slow review: `qwen2.5-coder:14b`.

`warcraft-rs` is especially useful because it exposes subcommands for MPQ, DBC,
BLP, M2, WMO, ADT, WDT, and WDL inspection. Use it to understand local input
shape before writing conversion code. Do not use either archive tool to write
client-derived files into Git-tracked paths.

When the workflow needs GPU time for Godot, Blender, graphics tracing,
conversion experiments, or native debugging, unload any running Ollama model
first with `ollama ps` and `ollama stop <model>`.

## How To Check It

Run:

```bash
./tools/check_playable_toolchain.sh
```

The script prints a readable status table and writes an ignored local report to:

```text
local_reports/playable-toolchain-report.md
```

## Git And Privacy Boundary

These tools may read local authorized client files during future porting stages,
but Git must only store scripts, source code, documentation, metadata, and
placeholder/original project assets.

Do not commit:

- local captures,
- packet dumps,
- graphics traces,
- extracted client assets,
- converted client-derived assets,
- MPQ/DBC/map/vmap/mmap files,
- secrets or private runtime configuration.

The `.gitignore` now blocks common local capture and graphics trace outputs:
`local_captures/`, `*.pcap`, `*.pcapng`, `*.trace`, and `*.rdc`.

Use `local_captures/` as the default folder for temporary packet captures,
graphics traces, and reference-client automation recordings.

## Remaining Deferred Tool

- `renderdoccmd`: useful for deep GPU frame debugging, but unavailable from apt
  and Snap during this setup pass. Keep apitrace as the current graphics capture
  fallback and revisit RenderDoc when rendering work demands it.
