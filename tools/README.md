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

## AzerothCore Database Audit

Run:

```bash
python3 tools/audit_azerothcore_db.py
```

Outputs:

```text
local_reports/azerothcore-db-audit.json
local_reports/azerothcore-db-audit.md
```

The script parses local AzerothCore config files, redacts credentials, and runs read-only connectivity/table-count checks when `mysql` is available and the database server is reachable.

## Read-Only Data Browser

Run:

```bash
python3 tools/read_only_data_browser.py --view summary --compact
```

Outputs:

```text
local_reports/read-only-data-browser.json
local_reports/read-only-data-browser.md
```

The tool runs `SELECT` queries only and avoids credential, email, registration mail, and IP fields. It provides summary counts plus read-only views for accounts, characters, online characters, creature templates, item templates, quest templates, and spell metadata.

## Server Stack Audit

Run:

```bash
python3 tools/audit_server_stack.py
```

Outputs:

```text
local_reports/server-stack-audit.json
local_reports/server-stack-audit.md
```

The script checks ports, processes, script paths, Linux binaries, runtime data readiness, log files, Docker MySQL container state, and WotLK client launch candidates. It does not start or stop services by default.

## Host Control Bridge

Run outside Snap Godot:

```bash
scripts/start_host_bridge.sh
```

Stop:

```bash
scripts/stop_host_bridge.sh
```

The bridge listens on `127.0.0.1:8765`, provides read-only status/data endpoints, and requires a local token for start, stop, and client-launch requests.

CLI client:

```bash
python3 tools/bridge_client.py health
python3 tools/bridge_client.py status --compact
python3 tools/bridge_client.py data --view summary --compact
python3 tools/bridge_client.py launch_client --compact
```

Mutating bridge actions write ignored local JSONL audit entries to:

```text
local_runtime/database-transactions.log
```
