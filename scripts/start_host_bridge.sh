#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME_DIR="$PROJECT_DIR/local_runtime"
PID_FILE="$RUNTIME_DIR/host-bridge.pid"
LOG_FILE="$RUNTIME_DIR/host-bridge.log"

mkdir -p "$RUNTIME_DIR"

if [[ -f "$PID_FILE" ]]; then
    PID="$(cat "$PID_FILE" 2>/dev/null || true)"
    if [[ -n "$PID" ]] && kill -0 "$PID" 2>/dev/null; then
        echo "Host bridge already running with pid $PID"
        exit 0
    fi
fi

nohup python3 "$PROJECT_DIR/tools/host_control_bridge.py" > "$LOG_FILE" 2>&1 &
echo "$!" > "$PID_FILE"
echo "Host bridge started with pid $(cat "$PID_FILE")"
echo "Log: $LOG_FILE"
