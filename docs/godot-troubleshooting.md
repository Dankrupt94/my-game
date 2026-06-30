# Godot Launch Troubleshooting

## Fastest Way To Run

Use the desktop shortcut named `Run AzerothCore Companion`.

That shortcut runs the scene directly:

```text
res://main.tscn
```

If the shortcut closes right away, it writes a log here:

```text
logs/godot-launch.log
```

## Opening The Editor

Use the desktop shortcut named `Open AzerothCore Companion in Godot`.

## If The Play Button Uses A Stale Scene

In the editor:

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

Without that permission, Godot may open the project through a temporary `/run/user/1000/doc/...` path and fail to create its `.godot` working folder.
