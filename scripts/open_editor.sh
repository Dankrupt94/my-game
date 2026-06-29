#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$REPO_DIR"

if command -v snap >/dev/null 2>&1 && snap list godot-4 >/dev/null 2>&1; then
  exec snap run godot-4 --editor --path "$REPO_DIR"
fi

if command -v godot4 >/dev/null 2>&1; then
  exec godot4 --editor --path "$REPO_DIR"
fi

if command -v godot >/dev/null 2>&1; then
  exec godot --editor --path "$REPO_DIR"
fi

echo "Godot 4 was not found."
echo "Install Godot 4.7 or run it from your app launcher, then open:"
echo "$REPO_DIR/project.godot"
read -r -p "Press Enter to close..." _

