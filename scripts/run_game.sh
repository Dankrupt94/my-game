#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCENE_PATH="res://main.tscn"

cd "$REPO_DIR"

if command -v snap >/dev/null 2>&1 && snap list godot-4 >/dev/null 2>&1; then
  exec snap run godot-4 --path "$REPO_DIR" --scene "$SCENE_PATH"
fi

if command -v godot4 >/dev/null 2>&1; then
  exec godot4 --path "$REPO_DIR" --scene "$SCENE_PATH"
fi

if command -v godot >/dev/null 2>&1; then
  exec godot --path "$REPO_DIR" --scene "$SCENE_PATH"
fi

echo "Godot 4 was not found."
echo "Install Godot 4.7 or run it from your app launcher, then open:"
echo "$REPO_DIR/project.godot"
read -r -p "Press Enter to close..." _

