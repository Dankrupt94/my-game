#!/usr/bin/env python3
"""Small CLI client for the localhost AzerothCore host bridge."""

from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.request
import urllib.parse
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TOKEN_PATH = ROOT / "local_runtime" / "host-bridge-token.txt"
DEFAULT_BASE_URL = "http://127.0.0.1:8765"
ACTION_PATHS = {
    "health": "/health",
    "status": "/status",
    "start": "/start",
    "stop": "/stop",
    "data": "/data",
    "nearby": "/nearby",
    "launch_client": "/client/launch",
}


def read_token() -> str | None:
    if not TOKEN_PATH.exists():
        return None
    token = TOKEN_PATH.read_text(encoding="utf-8").strip()
    return token or None


def request_json(
    base_url: str,
    action: str,
    timeout: int,
    view: str,
    search: str,
    limit: int,
    map_id: int,
    x: float,
    y: float,
    radius: float) -> tuple[int, dict[str, object]]:
    method = "GET" if action in ["health", "status"] else "POST"
    path = ACTION_PATHS[action]
    headers = {}

    if action == "data":
        method = "GET"
        query = urllib.parse.urlencode({"view": view, "search": search, "limit": str(limit)})
        path += "?" + query
    elif action == "nearby":
        method = "GET"
        query = urllib.parse.urlencode({
            "map": str(map_id),
            "x": str(x),
            "y": str(y),
            "radius": str(radius),
            "limit": str(limit),
        })
        path += "?" + query

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
        if action == "data":
            summary["data"] = {
                "view": report.get("view"),
                "search": report.get("search"),
                "limit": report.get("limit"),
                "summary": report.get("views", {}).get("summary", {}) if isinstance(report.get("views"), dict) else {},
                "errors": report.get("errors", {}),
            }
        elif action == "nearby":
            summary["nearby"] = {
                "map": report.get("map"),
                "radius": report.get("radius"),
                "counts": report.get("counts", {}),
                "sample": report.get("objects", [])[:3] if isinstance(report.get("objects"), list) else [],
            }
        else:
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
    parser.add_argument("action", choices=["health", "status", "start", "stop", "data", "nearby", "launch_client"])
    parser.add_argument("--base-url", default=DEFAULT_BASE_URL)
    parser.add_argument("--timeout", type=int, default=30)
    parser.add_argument("--compact", action="store_true")
    parser.add_argument("--view", default="summary")
    parser.add_argument("--search", default="")
    parser.add_argument("--limit", type=int, default=25)
    parser.add_argument("--map", type=int, default=0)
    parser.add_argument("--x", type=float, default=0.0)
    parser.add_argument("--y", type=float, default=0.0)
    parser.add_argument("--radius", type=float, default=80.0)
    args = parser.parse_args()

    status, payload = request_json(
        args.base_url,
        args.action,
        args.timeout,
        args.view,
        args.search,
        args.limit,
        args.map,
        args.x,
        args.y,
        args.radius)
    output = compact_summary(args.action, status, payload) if args.compact else payload
    print(json.dumps(output, indent=2, sort_keys=True))

    ok = bool(payload.get("ok")) and 200 <= status < 300
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
