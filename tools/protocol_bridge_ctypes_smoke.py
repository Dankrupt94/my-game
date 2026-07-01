#!/usr/bin/env python3
"""Smoke-test the native protocol bridge shared library without exposing secrets."""

from __future__ import annotations

import ctypes
import os
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_LIBRARY = ROOT / "native" / "protocol_client" / "build" / "libacore_protocol_bridge.so"
BUFFER_SIZE = 65536


def _load_library(path: Path) -> ctypes.CDLL:
    lib = ctypes.CDLL(str(path))
    lib.acore_protocol_bridge_self_test_json.argtypes = [ctypes.c_char_p, ctypes.c_size_t]
    lib.acore_protocol_bridge_self_test_json.restype = ctypes.c_int
    lib.acore_protocol_bridge_character_flow_json.argtypes = [
        ctypes.c_char_p,
        ctypes.c_char_p,
        ctypes.c_char_p,
        ctypes.c_char_p,
        ctypes.c_char_p,
        ctypes.c_size_t,
    ]
    lib.acore_protocol_bridge_character_flow_json.restype = ctypes.c_int
    return lib


def _decode(buffer: ctypes.Array[ctypes.c_char]) -> str:
    return buffer.value.decode("utf-8", errors="replace")


def _call_self_test(lib: ctypes.CDLL) -> int:
    buffer = ctypes.create_string_buffer(BUFFER_SIZE)
    status = lib.acore_protocol_bridge_self_test_json(buffer, len(buffer))
    print(_decode(buffer))
    return status


def _call_character_flow(lib: ctypes.CDLL) -> int:
    account = os.environ.get("ACORE_PROTOCOL_ACCOUNT", "")
    password = os.environ.get("ACORE_PROTOCOL_PASSWORD", "")
    if not account or not password:
        print("CHARACTER_FLOW_SKIPPED missing ACORE_PROTOCOL_ACCOUNT or ACORE_PROTOCOL_PASSWORD")
        return 0

    host = os.environ.get("ACORE_PROTOCOL_HOST", "127.0.0.1")
    port = os.environ.get("ACORE_PROTOCOL_PORT", "3724")
    buffer = ctypes.create_string_buffer(BUFFER_SIZE)
    status = lib.acore_protocol_bridge_character_flow_json(
        host.encode("utf-8"),
        port.encode("utf-8"),
        account.encode("utf-8"),
        password.encode("utf-8"),
        buffer,
        len(buffer),
    )
    print(_decode(buffer))
    return status


def main() -> int:
    library = Path(os.environ.get("ACORE_PROTOCOL_BRIDGE_LIBRARY", DEFAULT_LIBRARY))
    if not library.exists():
        print(f"Missing native bridge library: {library}", file=sys.stderr)
        return 1

    lib = _load_library(library)
    self_test_status = _call_self_test(lib)
    character_status = _call_character_flow(lib)
    return 0 if self_test_status == 0 and character_status == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
