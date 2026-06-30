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
    rm -f "$PID_FILE"
fi

if command -v setsid >/dev/null 2>&1; then
    setsid python3 "$PROJECT_DIR/tools/host_control_bridge.py" > "$LOG_FILE" 2>&1 < /dev/null &
else
    nohup python3 "$PROJECT_DIR/tools/host_control_bridge.py" > "$LOG_FILE" 2>&1 < /dev/null &
fi

PID="$!"
echo "$PID" > "$PID_FILE"
echo "Log: $LOG_FILE"

for _ in {1..20}; do
    if python3 "$PROJECT_DIR/tools/bridge_client.py" health --compact --timeout 2 >/dev/null 2>&1; then
        echo "Host bridge started with pid $PID"
        exit 0
    fi

    if ! kill -0 "$PID" 2>/dev/null; then
        echo "Host bridge exited before it became ready."
        tail -40 "$LOG_FILE" 2>/dev/null || true
        rm -f "$PID_FILE"
        exit 1
    fi

    sleep 0.25
done

echo "Host bridge did not answer health checks in time."
tail -40 "$LOG_FILE" 2>/dev/null || true
exit 1
