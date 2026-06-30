# Task Log

## 2026-06-30 - Move Godot Project Into AzerothCore Bundle

Goal: move the Godot project out of the SSD trash and into the local AzerothCore bundle where it is easier to find and manage.

Result:

- Moved the project to `/run/media/doodbro/New 1tb/AzerothCore/godot-azerothcore-companion`.
- Preserved the existing Git repo and GitHub remote.
- Documented the local AzerothCore, build, and WotLK client paths in `docs/location-notes.md`.

## 2026-06-30 - Rename And Reset For AzerothCore Companion

Goal: abandon the previous RPG prototype and reset this Godot repo for the local AzerothCore companion project.

Result:

- Renamed the folder to `/run/media/doodbro/New 1tb/AzerothCore/godot-azerothcore-companion`.
- Removed retired gameplay scripts, the old controls doc, the old scene copy, and old desktop launchers.
- Replaced the main Godot scene with an AzerothCore companion dashboard shell.
- Renamed project launchers and Desktop shortcuts for the AzerothCore companion project.
- Verified the renamed Godot shell launches with Godot 4.7.
