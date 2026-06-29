# Godot Launch Troubleshooting

## Fastest Way To Play

Use the desktop shortcut named `Run Frostbound Prototype`.

That shortcut runs the scene directly:

```text
res://main.tscn
```

This bypasses stale Godot editor state, such as the editor remembering an older scene path.

If the shortcut closes right away, it now writes a log here:

```text
logs/godot-launch.log
```

The shortcut also opens in a terminal window so the error should stay visible.

## Opening The Editor

Use the desktop shortcut named `Open Frostbound in Godot`.

The editor may show a plain brown/gray 3D viewport with axes before you press Play. That is normal for this early prototype because the snowy yard is built by the game script when the scene runs.

## If The Play Button Still Mentions main.tscm

Godot is remembering a bad path. In the editor:

1. Open `Project > Project Settings`.
2. Search for `Main Scene`.
3. Set it to `res://main.tscn`.
4. Close and reopen Godot.

## Snap Permission For External Drives

This project is stored on an external drive under `/run/media`. The Snap version of Godot needs the `removable-media` permission to access that folder directly.

The permission has been enabled on this machine:

```text
godot-4:removable-media -> :removable-media
```

Without that permission, Godot opens the project through a temporary `/run/user/1000/doc/...` path and cannot create its `.godot` working folder.
