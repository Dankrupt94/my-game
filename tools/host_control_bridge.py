#!/usr/bin/env python3
"""Localhost-only host control bridge for the Godot companion dashboard."""

from __future__ import annotations

import argparse
import json
import secrets
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, urlparse


ROOT = Path(__file__).resolve().parents[1]
LOCAL_RUNTIME = ROOT / "local_runtime"
LOCAL_REPORTS = ROOT / "local_reports"
TOKEN_PATH = LOCAL_RUNTIME / "host-bridge-token.txt"
TRANSACTION_LOG = LOCAL_RUNTIME / "database-transactions.log"
STATUS_TOOL = ROOT / "tools" / "audit_server_stack.py"
STATUS_REPORT = LOCAL_REPORTS / "server-stack-audit.json"
DATA_TOOL = ROOT / "tools" / "read_only_data_browser.py"
DATA_REPORT = LOCAL_REPORTS / "read-only-data-browser.json"
START_SCRIPT = Path("/run/media/doodbro/New 1tb/AzerothCore/scripts/start.sh")
STOP_SCRIPT = Path("/run/media/doodbro/New 1tb/AzerothCore/scripts/stop.sh")
CLIENT_EXE = Path("/run/media/doodbro/New 1tb/AzerothCore/client/Wow.exe")
ALLOWED_DATA_VIEWS = {"summary", "accounts", "characters", "online", "creatures", "items", "quests", "spells", "all"}
MAX_DATA_SEARCH_LENGTH = 80
MUTATING_ENDPOINTS = {"/start", "/stop", "/client/launch"}


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def ensure_token() -> str:
    LOCAL_RUNTIME.mkdir(parents=True, exist_ok=True)
    if TOKEN_PATH.exists():
        token = TOKEN_PATH.read_text(encoding="utf-8").strip()
        if token:
            return token
    token = secrets.token_urlsafe(32)
    TOKEN_PATH.write_text(token + "\n", encoding="utf-8")
    TOKEN_PATH.chmod(0o600)
    return token


def append_transaction_log(action: str, ok: bool, detail: dict[str, Any]) -> None:
    LOCAL_RUNTIME.mkdir(parents=True, exist_ok=True)
    entry = {
        "timestamp": utc_now(),
        "action": action,
        "ok": ok,
        "detail": detail,
    }
    with TRANSACTION_LOG.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(entry, sort_keys=True) + "\n")
    TRANSACTION_LOG.chmod(0o600)


def run_command(command: list[str], timeout: int) -> dict[str, Any]:
    try:
        completed = subprocess.run(
            command,
            check=False,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=timeout,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        return {
            "ok": False,
            "exit_code": 1,
            "output": str(exc),
        }

    return {
        "ok": completed.returncode == 0,
        "exit_code": completed.returncode,
        "output": completed.stdout[-20000:],
    }


def launch_client() -> dict[str, Any]:
    if not CLIENT_EXE.exists():
        return {
            "ok": False,
            "exit_code": 1,
            "output": f"Client executable not found: {CLIENT_EXE}",
        }

    wine = shutil.which("wine")
    if not wine:
        return {
            "ok": False,
            "exit_code": 1,
            "output": "Wine is not installed or not visible to the host bridge.",
        }

    try:
        process = subprocess.Popen(
            [wine, str(CLIENT_EXE)],
            cwd=str(CLIENT_EXE.parent),
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
    except OSError as exc:
        return {
            "ok": False,
            "exit_code": 1,
            "output": str(exc),
        }

    return {
        "ok": True,
        "exit_code": 0,
        "output": f"Client launch started with process id {process.pid}",
        "pid": process.pid,
    }


def load_json_report(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}


class BridgeHandler(BaseHTTPRequestHandler):
    server_version = "AcoreHostBridge/0.2"

    def log_message(self, format: str, *args: Any) -> None:
        sys.stderr.write("[%s] %s\n" % (utc_now(), format % args))

    @property
    def bridge_token(self) -> str:
        return self.server.bridge_token  # type: ignore[attr-defined]

    def _send_json(self, status: HTTPStatus, payload: dict[str, Any]) -> None:
        body = json.dumps(payload, indent=2, sort_keys=True).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _authorized(self) -> bool:
        return self.headers.get("X-Acore-Bridge-Token") == self.bridge_token

    def _require_token(self) -> bool:
        if self._authorized():
            return True
        self._send_json(
            HTTPStatus.UNAUTHORIZED,
            {
                "ok": False,
                "error": "missing or invalid X-Acore-Bridge-Token",
                "generated_at": utc_now(),
            },
        )
        return False

    def do_GET(self) -> None:
        parsed_url = urlparse(self.path)
        path = parsed_url.path
        if path == "/health":
            self._send_json(
                HTTPStatus.OK,
                {
                    "ok": True,
                    "service": "azerothcore-host-control-bridge",
                    "generated_at": utc_now(),
                    "bind_host": self.server.server_address[0],
                    "mutating_endpoints": sorted(MUTATING_ENDPOINTS),
                    "token_required_for_mutation": True,
                    "transaction_log": str(TRANSACTION_LOG),
                },
            )
            return

        if path == "/status":
            command = [sys.executable, str(STATUS_TOOL)]
            result = run_command(command, timeout=20)
            self._send_json(
                HTTPStatus.OK if result["ok"] else HTTPStatus.INTERNAL_SERVER_ERROR,
                {
                    "ok": result["ok"],
                    "generated_at": utc_now(),
                    "command": "audit_server_stack",
                    "result": result,
                    "report": load_json_report(STATUS_REPORT),
                },
            )
            return

        if path == "/data":
            params = parse_qs(parsed_url.query)
            view = params.get("view", ["summary"])[0]
            search = params.get("search", [""])[0]
            limit_text = params.get("limit", ["25"])[0]

            if view not in ALLOWED_DATA_VIEWS:
                self._send_json(
                    HTTPStatus.BAD_REQUEST,
                    {"ok": False, "error": f"unsupported data view: {view}", "generated_at": utc_now()},
                )
                return

            if len(search) > MAX_DATA_SEARCH_LENGTH:
                self._send_json(
                    HTTPStatus.BAD_REQUEST,
                    {"ok": False, "error": "search term is too long", "generated_at": utc_now()},
                )
                return

            try:
                limit_value = int(limit_text)
            except ValueError:
                self._send_json(
                    HTTPStatus.BAD_REQUEST,
                    {"ok": False, "error": "limit must be a number", "generated_at": utc_now()},
                )
                return

            limit = str(max(1, min(limit_value, 100)))
            command = [
                sys.executable,
                str(DATA_TOOL),
                "--view",
                view,
                "--search",
                search,
                "--limit",
                limit,
            ]
            result = run_command(command, timeout=30)
            report: dict[str, Any] = {}
            if result["output"]:
                try:
                    parsed_report = json.loads(result["output"])
                    if isinstance(parsed_report, dict):
                        report = parsed_report
                except json.JSONDecodeError:
                    report = load_json_report(DATA_REPORT)
            self._send_json(
                HTTPStatus.OK if result["ok"] else HTTPStatus.INTERNAL_SERVER_ERROR,
                {
                    "ok": result["ok"],
                    "generated_at": utc_now(),
                    "command": "read_only_data_browser",
                    "result": result,
                    "report": report,
                },
            )
            return

        self._send_json(HTTPStatus.NOT_FOUND, {"ok": False, "error": "unknown endpoint", "generated_at": utc_now()})

    def do_POST(self) -> None:
        path = urlparse(self.path).path
        if path not in MUTATING_ENDPOINTS:
            self._send_json(HTTPStatus.NOT_FOUND, {"ok": False, "error": "unknown endpoint", "generated_at": utc_now()})
            return

        if not self._require_token():
            return

        if path == "/client/launch":
            result = launch_client()
            append_transaction_log(
                "client_launch",
                bool(result["ok"]),
                {
                    "endpoint": path,
                    "client": self.client_address[0],
                    "target": str(CLIENT_EXE),
                    "pid": result.get("pid"),
                    "exit_code": result.get("exit_code"),
                    "output_tail": str(result.get("output", ""))[-1200:],
                },
            )
            self._send_json(
                HTTPStatus.OK if result["ok"] else HTTPStatus.INTERNAL_SERVER_ERROR,
                {
                    "ok": result["ok"],
                    "generated_at": utc_now(),
                    "action": "client_launch",
                    "target": str(CLIENT_EXE),
                    "result": result,
                },
            )
            return

        script = START_SCRIPT if path == "/start" else STOP_SCRIPT
        if not script.exists():
            append_transaction_log(
                path.strip("/"),
                False,
                {
                    "endpoint": path,
                    "client": self.client_address[0],
                    "script": str(script),
                    "error": "script not found",
                },
            )
            self._send_json(
                HTTPStatus.NOT_FOUND,
                {"ok": False, "error": f"script not found: {script}", "generated_at": utc_now()},
            )
            return

        result = run_command(["/usr/bin/env", "bash", str(script)], timeout=240)
        append_transaction_log(
            path.strip("/"),
            bool(result["ok"]),
            {
                "endpoint": path,
                "client": self.client_address[0],
                "script": str(script),
                "exit_code": result.get("exit_code"),
                "output_tail": str(result.get("output", ""))[-1200:],
            },
        )
        self._send_json(
            HTTPStatus.OK if result["ok"] else HTTPStatus.INTERNAL_SERVER_ERROR,
            {
                "ok": result["ok"],
                "generated_at": utc_now(),
                "action": path.strip("/"),
                "script": str(script),
                "result": result,
            },
        )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--print-token", action="store_true")
    args = parser.parse_args()

    if args.host not in ["127.0.0.1", "localhost"]:
        print("Refusing to bind outside localhost.", file=sys.stderr)
        return 2

    token = ensure_token()
    if args.print_token:
        print(token)
        return 0

    server = ThreadingHTTPServer((args.host, args.port), BridgeHandler)
    server.bridge_token = token  # type: ignore[attr-defined]
    print(f"AzerothCore host control bridge listening on http://{args.host}:{args.port}")
    print(f"Token path: {TOKEN_PATH}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("Stopping bridge.")
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
