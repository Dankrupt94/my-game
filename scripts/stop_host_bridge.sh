#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PID_FILE="$PROJECT_DIR/local_runtime/host-bridge.pid"

if [[ ! -f "$PID_FILE" ]]; then
    echo "Host bridge is not running."
    exit 0
fi

PID="$(cat "$PID_FILE" 2>/dev/null || true)"
if [[ -n "$PID" ]] && kill -0 "$PID" 2>/dev/null; then
    kill "$PID" || true
    sleep 1
    kill -9 "$PID" 2>/dev/null || true
    echo "Stopped host bridge pid $PID"
else
    echo "Host bridge pid was stale."
fi

rm -f "$PID_FILE"
