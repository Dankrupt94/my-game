# Read-Only Data Browser

## Purpose

Stage 03 begins with a safe read-only data path from AzerothCore MySQL to Godot.

The dashboard does not hold database credentials. It calls the local bridge client, the bridge client asks the localhost host bridge for read-only data, and the bridge runs a local Python tool that performs `SELECT` queries only.

## Files

```text
tools/read_only_data_browser.py
tools/host_control_bridge.py
tools/bridge_client.py
scripts/companion_dashboard.gd
```

Ignored local reports:

```text
local_reports/read-only-data-browser.json
local_reports/read-only-data-browser.md
```

## Bridge Endpoint

```text
GET /data?view=summary&search=&limit=25
```

CLI examples:

```bash
python3 tools/bridge_client.py data --view summary --compact
python3 tools/bridge_client.py data --view creatures --search trainer --limit 5 --compact
python3 tools/bridge_client.py data --view items --search sword --limit 5 --compact
```

## Current Views

- `summary`
- `accounts`
- `characters`
- `online`
- `creatures`
- `items`
- `quests`
- `spells`
- `all`

## Tables And Fields

Auth database:

- `realmlist`: `id`, `name`, `address`, `port`, `gamebuild`, `population`
- `account`: `id`, `username`, `online`, `expansion`, `locale`, `os`, `totaltime`

Characters database:

- `characters`: `guid`, `account`, `name`, `race`, `class`, `gender`, `level`, `online`, `map`, `zone`, `totaltime`

World database:

- `creature_template`: `entry`, `name`, `subname`, `minlevel`, `maxlevel`, `rank`, `faction`, `npcflag`
- `item_template`: `entry`, `name`, `Quality`, `InventoryType`, `ItemLevel`, `RequiredLevel`, `class`, `subclass`
- `quest_template`: `ID`, `LogTitle`, `QuestLevel`, `MinLevel`, `QuestType`, `QuestSortID`
- `spell_dbc`: `ID`, `Name_Lang_enUS`, `NameSubtext_Lang_enUS`, `Description_Lang_enUS`, `SpellLevel`, `BaseLevel`, `PowerType`, `ManaCost`

The account view intentionally avoids credential, email, registration mail, and IP fields.

## Dashboard Integration

The dashboard now has:

- a `Browse Data` command action,
- selectable views for summary, accounts, characters, online characters, creatures, items, quests, and spells,
- a search box for template/spell views,
- a row limit control,
- a result panel for row output,
- a `Data Snapshot` panel,
- live counts for accounts, characters, online characters, creature templates, item templates, quest templates, and spell rows,
- realm name and world port.

## Query Containment

- `view` is restricted by `tools/read_only_data_browser.py` choices.
- The bridge rejects unsupported `view` values before launching the data tool.
- `limit` is clamped to 1-100 rows.
- The bridge rejects non-numeric `limit` values before launching the data tool.
- The bridge rejects search terms longer than 80 characters.
- `search` is quoted before entering SQL and used only in `LIKE` filters.
- The bridge exposes the data browser through `GET`; no database write endpoint exists for this stage.

## Validation

Validated on 2026-06-30:

- Direct `summary`, `accounts`, `characters`, `online`, `creatures`, `items`, `quests`, and `spells` views run successfully.
- Bridge `data --view summary` returns live counts from the running stack.
- Bridge `data --view items --search sword --limit 5` returns successfully.
- Godot 4.7 loads the dashboard scene headlessly with the Data Snapshot panel and read-only browser controls present.
