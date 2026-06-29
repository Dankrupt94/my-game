#!/usr/bin/env bash
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$REPO_DIR/logs"
LOG_FILE="$LOG_DIR/godot-launch.log"
EXTRA_ARGS=()

mkdir -p "$LOG_DIR"

if [ "${FROSTBOUND_HEADLESS:-0}" = "1" ]; then
  EXTRA_ARGS=(--headless --quit-after 10)
fi

pause_if_possible() {
  if [ -t 0 ]; then
    echo
    read -r -p "Press Enter to close this window..." _ || true
  fi
}

run_godot() {
  local -a command_line=("$@")

  {
    echo "============================================================"
    echo "Open Frostbound in Godot"
    echo "Time: $(date)"
    echo "Project: $REPO_DIR"
    echo "Command: ${command_line[*]}"
    echo "============================================================"
  } | tee -a "$LOG_FILE"

  "${command_line[@]}" 2>&1 | tee -a "$LOG_FILE"
  local status="${PIPESTATUS[0]}"

  echo "Godot exited with code: $status" | tee -a "$LOG_FILE"
  if [ "$status" -ne 0 ]; then
    echo "A launch error happened. The log was saved here:" | tee -a "$LOG_FILE"
    echo "$LOG_FILE" | tee -a "$LOG_FILE"
    pause_if_possible
  elif [ "${FROSTBOUND_PAUSE:-0}" = "1" ]; then
    pause_if_possible
  fi

  return "$status"
}

cd "$REPO_DIR"

if command -v snap >/dev/null 2>&1 && snap list godot-4 >/dev/null 2>&1; then
  run_godot snap run godot-4 "${EXTRA_ARGS[@]}" --editor --path "$REPO_DIR"
  exit "$?"
fi

if command -v godot4 >/dev/null 2>&1; then
  run_godot godot4 "${EXTRA_ARGS[@]}" --editor --path "$REPO_DIR"
  exit "$?"
fi

if command -v godot >/dev/null 2>&1; then
  run_godot godot "${EXTRA_ARGS[@]}" --editor --path "$REPO_DIR"
  exit "$?"
fi

echo "Godot 4 was not found."
echo "Install Godot 4.7 or run it from your app launcher, then open:"
echo "$REPO_DIR/project.godot"
pause_if_possible
exit 1
