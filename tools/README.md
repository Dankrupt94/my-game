# Local Tooling

This folder contains non-proprietary helper tools for the Godot-AzerothCore-WotLK prototype.

The tools may inspect local Blizzard/WotLK files on this machine under the project authorization, but they should write generated reports to ignored local folders by default.

## Reports Folder

Default local report output:

```text
local_reports/
```

This folder is ignored by Git because reports may contain local paths, proprietary file metadata, or large generated data.

## Toolchain Audit

Run:

```bash
python3 tools/audit_toolchain.py
```

Outputs:

```text
local_reports/toolchain-audit.json
local_reports/toolchain-audit.md
```

Use this before major work to see what development tools are installed and what is missing.

## Client Manifest Scanner

Run:

```bash
python3 tools/client_manifest_scan.py
```

Outputs:

```text
local_reports/client-file-manifest.json
local_reports/client-file-manifest.md
```

The scanner records metadata only. It does not extract MPQs, unpack assets, or write proprietary files into Git.

By default, it scans the documented local WotLK client paths and summarizes file counts, sizes, and extension groups. Use `--hash-mode sha256` only when exact provenance is needed and the extra runtime is acceptable.
