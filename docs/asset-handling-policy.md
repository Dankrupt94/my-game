# Asset Handling Policy

## Short Version

This Git repo should not track proprietary WotLK client assets.

The local project folder may contain proprietary assets for the authorized private prototype, but only inside ignored local-only folders or existing local client paths. Those files must stay on this machine and must not be committed or pushed to GitHub.

## Authorization For This Local Prototype

The project owner states they are authorized to evaluate a Godot-based WotLK client/engine port and has instructed Codex to use the proprietary client files locally for that prototype.

That authorization applies to local use on this machine. It does not change the Git/GitHub rule: the repository stores code, documentation, tooling, manifests, references, and original placeholder assets, not proprietary client files or derived copies.

## Why

The long-term goal is a faithful Godot-AzerothCore-WotLK game/client experience. That goal may require local authorized reference assets while we study behavior, data shapes, UI flows, and client/server expectations. It does not require pushing proprietary client files to GitHub.

Even a private GitHub repo is still a remote copy. For this project, proprietary client files stay local.

## Important Distinction

There are two different things:

- The **local project folder** may hold authorized private local-only asset files.
- The **Git repo/history/GitHub remote** must not track or receive those files.

If Git tracks a file, it can be pushed later. To keep proprietary files local forever, keep them untracked in ignored folders.

## Allowed In Git

- Original Godot scenes, scripts, UI, and tooling.
- Documentation about local paths.
- Placeholder assets created for this project.
- Open-license assets with documented licenses.
- Asset manifests that reference local files by path, hash, ID, or description.
- Import/conversion code that operates on local files, as long as it does not commit proprietary input or derived output.

## Allowed Locally, But Not In Git

- WotLK MPQ files.
- Extracted WotLK models.
- Extracted WotLK textures.
- Extracted WotLK maps.
- Extracted WotLK sounds/music.
- Extracted proprietary database/client files.
- Converted files derived from proprietary client assets.

These may only live in ignored local-only folders or in the existing external client locations.

## Not Allowed In Git

- WotLK MPQ files.
- Extracted WotLK models.
- Extracted WotLK textures.
- Extracted WotLK maps.
- Extracted WotLK sounds/music.
- Extracted proprietary database/client files.
- Converted files derived from proprietary client assets.

## Local-Only Folders

The `.gitignore` blocks these folders for the authorized local prototype:

```text
local_assets/
proprietary_assets/
client_assets/
extracted_client_assets/
```

These folders may exist on this machine, but Git should not track them. They are for authorized local-only private experiments.

## Known Local Client Paths

```text
WotLK client:       /run/media/doodbro/5e07d7d7-039f-43a8-94da-999f100ab1fb/World of Warcraft - WoTLK
Bundle client copy: /run/media/doodbro/New 1tb/AzerothCore/client
```

## Working Rule

If a future stage needs client-derived visuals or data, first document:

- what file is needed,
- why it is needed,
- where it lives locally,
- whether the repo stores only a reference or a derived copy.

Default answer: store only a reference in Git. Keep the asset itself local and untracked.
