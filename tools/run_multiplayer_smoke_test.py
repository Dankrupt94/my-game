#!/usr/bin/env python3
"""Launch one Godot multiplayer server and two headless clients on localhost."""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCENE = "res://scenes/multiplayer_sandbox.tscn"


def godot_command() -> list[str]:
    if shutil.which("godot-4"):
        return ["godot-4"]
    if shutil.which("godot4"):
        return ["godot4"]
    if shutil.which("godot"):
        return ["godot"]
    raise RuntimeError("Godot 4 command was not found")


def start_process(extra_env: dict[str, str]) -> subprocess.Popen[str]:
    env = os.environ.copy()
    env.update(extra_env)
    command = godot_command() + [
        "--headless",
        "--quit-after",
        "900",
        "--path",
        str(ROOT),
        "--scene",
        SCENE,
    ]
    return subprocess.Popen(
        command,
        cwd=ROOT,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )


def collect(process: subprocess.Popen[str], timeout: int) -> tuple[int, str]:
    try:
        output, _ = process.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        process.kill()
        output, _ = process.communicate()
        return 124, output
    return process.returncode or 0, output


def main() -> int:
    server = start_process(
        {
            "ACORE_MP_MODE": "server",
            "ACORE_MP_SERVER_SELF_TEST": "1",
            "ACORE_MP_EXPECTED_PLAYERS": "2",
        }
    )
    time.sleep(2.0)
    if server.poll() is not None:
        _, output = collect(server, 1)
        print(output)
        return 1

    clients = [
        start_process(
            {
                "ACORE_MP_MODE": "client",
                "ACORE_MP_CLIENT_NAME": "ClientOne",
                "ACORE_MP_CLIENT_SELF_TEST": "1",
                "ACORE_MP_EXPECTED_PLAYERS": "2",
            }
        ),
        start_process(
            {
                "ACORE_MP_MODE": "client",
                "ACORE_MP_CLIENT_NAME": "ClientTwo",
                "ACORE_MP_CLIENT_SELF_TEST": "1",
                "ACORE_MP_EXPECTED_PLAYERS": "2",
            }
        ),
    ]

    ok = True
    for process in clients:
        code, output = collect(process, 30)
        print(output)
        if code != 0 or "MULTIPLAYER_CLIENT_SELF_TEST_OK" not in output:
            ok = False

    try:
        server_output, _ = server.communicate(timeout=10)
    except subprocess.TimeoutExpired:
        server.terminate()
        try:
            server_output, _ = server.communicate(timeout=5)
        except subprocess.TimeoutExpired:
            server.kill()
            server_output, _ = server.communicate()
    print(server_output)

    if "MULTIPLAYER_SERVER_SELF_TEST_OK" not in server_output:
        ok = False

    if not ok:
        return 1
    print("MULTIPLAYER_SMOKE_TEST_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
