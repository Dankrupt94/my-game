#!/usr/bin/env python3
"""Small CLI client for the localhost AzerothCore host bridge."""

from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TOKEN_PATH = ROOT / "local_runtime" / "host-bridge-token.txt"
DEFAULT_BASE_URL = "http://127.0.0.1:8765"


def read_token() -> str | None:
    if not TOKEN_PATH.exists():
        return None
    token = TOKEN_PATH.read_text(encoding="utf-8").strip()
    return token or None


def request_json(base_url: str, action: str, timeout: int) -> tuple[int, dict[str, object]]:
    method = "GET" if action in ["health", "status"] else "POST"
    path = "/" + action
    headers = {}

    if method == "POST":
        token = read_token()
        if not token:
            return 2, {"ok": False, "error": f"token file missing: {TOKEN_PATH}"}
        headers["X-Acore-Bridge-Token"] = token

    request = urllib.request.Request(base_url.rstrip("/") + path, method=method, headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return response.status, json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        try:
            payload = json.loads(exc.read().decode("utf-8"))
        except json.JSONDecodeError:
            payload = {"ok": False, "error": str(exc)}
        return exc.code, payload
    except Exception as exc:
        return 1, {"ok": False, "error": str(exc)}


def compact_summary(action: str, status: int, payload: dict[str, object]) -> dict[str, object]:
    summary: dict[str, object] = {
        "action": action,
        "http_status": status,
        "ok": payload.get("ok", False),
    }

    report = payload.get("report")
    if isinstance(report, dict):
        summary["ports"] = report.get("ports", {})
        summary["docker_mysql"] = report.get("docker_mysql", {})
        summary["runtime_environment"] = report.get("runtime_environment", {})
    elif "error" in payload:
        summary["error"] = payload["error"]

    result = payload.get("result")
    if isinstance(result, dict):
        summary["exit_code"] = result.get("exit_code")
        output = str(result.get("output", ""))
        summary["output_tail"] = output[-1200:]

    return summary


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["health", "status", "start", "stop"])
    parser.add_argument("--base-url", default=DEFAULT_BASE_URL)
    parser.add_argument("--timeout", type=int, default=30)
    parser.add_argument("--compact", action="store_true")
    args = parser.parse_args()

    status, payload = request_json(args.base_url, args.action, args.timeout)
    output = compact_summary(args.action, status, payload) if args.compact else payload
    print(json.dumps(output, indent=2, sort_keys=True))

    ok = bool(payload.get("ok")) and 200 <= status < 300
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
