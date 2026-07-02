#!/usr/bin/env bash
# shellcheck disable=SC2016
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_PATH="${ACORE_PLAYABLE_TOOLCHAIN_REPORT:-${ROOT_DIR}/local_reports/playable-toolchain-report.md}"
MISSING_REQUIRED=0
MISSING_OPTIONAL=0

mkdir -p "$(dirname "${REPORT_PATH}")"
exec > >(tee "${REPORT_PATH}")

print_header() {
    printf '# Playable Toolchain Check\n\n'
    printf 'Generated: %s\n\n' "$(date -Iseconds)"
    printf 'This report checks local developer tools for the Godot-AzerothCore playable-port workflow.\n'
    printf 'It does not inspect or copy proprietary client assets.\n\n'
}

print_category() {
    printf '## %s\n\n' "$1"
    printf '| Status | Tool | Path | Why it matters |\n'
    printf '| --- | --- | --- | --- |\n'
}

check_tool() {
    local level="$1"
    local tool="$2"
    local purpose="$3"
    local path=""

    if path="$(command -v "${tool}" 2>/dev/null)"; then
        printf '| OK | `%s` | `%s` | %s |\n' "${tool}" "${path}" "${purpose}"
    else
        if [[ "${level}" == "required" ]]; then
            MISSING_REQUIRED=$((MISSING_REQUIRED + 1))
            printf '| MISSING | `%s` | - | %s |\n' "${tool}" "${purpose}"
        else
            MISSING_OPTIONAL=$((MISSING_OPTIONAL + 1))
            printf '| OPTIONAL | `%s` | - | %s |\n' "${tool}" "${purpose}"
        fi
    fi
}

check_snap_media_access() {
    printf '\n## Godot Snap Access\n\n'
    if ! command -v godot-4 >/dev/null 2>&1; then
        printf 'Godot executable was not found, so Snap access was not checked.\n'
        return
    fi

    local godot_path
    godot_path="$(command -v godot-4)"
    if [[ "${godot_path}" != /snap/bin/* ]]; then
        printf 'Godot is not running from Snap at `%s`; removable-media Snap access is not needed.\n' "${godot_path}"
        return
    fi

    if ! command -v snap >/dev/null 2>&1; then
        printf 'Godot is a Snap command, but `snap` itself was not found for connection checks.\n'
        return
    fi

    local connections
    connections="$(snap connections godot-4 2>/dev/null || true)"
    if printf '%s\n' "${connections}" | awk '$1 == "removable-media" && $3 != "-" { found = 1 } END { exit found ? 0 : 1 }'; then
        printf 'OK: Godot Snap has removable-media access for external-drive project folders.\n'
    else
        printf 'WARN: Godot Snap may need removable-media access for `/run/media` project folders.\n'
        printf 'Fix locally with: `sudo snap connect godot-4:removable-media`.\n'
    fi
}

check_local_ai() {
    printf '\n## Local AI\n\n'
    if ! command -v ollama >/dev/null 2>&1; then
        MISSING_OPTIONAL=$((MISSING_OPTIONAL + 1))
        printf 'OPTIONAL: `ollama` is missing. Local Qwen advisory review will be unavailable.\n'
        return
    fi

    local models
    models="$(timeout 4 ollama list 2>/dev/null || true)"
    if printf '%s\n' "${models}" | awk 'NR > 1 && ($1 ~ /^qwen-agent/ || $1 ~ /^qwen2\.5-coder/) { found = 1 } END { exit found ? 0 : 1 }'; then
        printf 'OK: Ollama is available with a Qwen coding model for safe, bounded local review.\n'
    else
        MISSING_OPTIONAL=$((MISSING_OPTIONAL + 1))
        printf 'OPTIONAL: Ollama is installed, but no Qwen coding model was visible in a quick check.\n'
    fi
}

print_versions() {
    printf '\n## Version Smoke Checks\n\n'
    if command -v blender >/dev/null 2>&1; then
        printf -- '- Blender: `%s`\n' "$(blender --version 2>/dev/null | head -n 1)"
    fi
    if command -v gltf-transform >/dev/null 2>&1; then
        printf -- '- glTF Transform: `%s`\n' "$(gltf-transform --version 2>/dev/null | head -n 1)"
    fi
    if command -v gltfpack >/dev/null 2>&1; then
        printf -- '- gltfpack: `%s`\n' "$(gltfpack -h 2>&1 | head -n 1)"
    fi
    if command -v wine >/dev/null 2>&1; then
        printf -- '- Wine: `%s`\n' "$(wine --version 2>/dev/null | head -n 1)"
    fi
    if command -v cargo-watch >/dev/null 2>&1; then
        printf -- '- cargo-watch: `%s`\n' "$(cargo watch --version 2>/dev/null | head -n 1)"
    fi
    if command -v sqlite-utils >/dev/null 2>&1; then
        printf -- '- sqlite-utils: `%s`\n' "$(sqlite-utils --version 2>/dev/null | head -n 1)"
    fi
}

print_summary() {
    printf '\n## Summary\n\n'
    printf -- '- Missing required tools: `%s`\n' "${MISSING_REQUIRED}"
    printf -- '- Missing optional tools: `%s`\n' "${MISSING_OPTIONAL}"
    printf -- '- Local report path: `%s`\n' "${REPORT_PATH}"
    if [[ "${MISSING_REQUIRED}" -eq 0 ]]; then
        printf '\nRequired playable-port tools are ready.\n'
    else
        printf '\nRequired playable-port tools are missing. Install them before relying on the full workflow.\n'
    fi
}

print_header

print_category "Engine And Visual Asset Pipeline"
check_tool required godot-4 "Run the Godot project and headless smoke tests."
check_tool required blender "Inspect, repair, and convert local-only model work before Godot import."
check_tool required assimp "Batch inspect and convert common 3D formats."
check_tool required gltf-transform "Inspect, validate, and optimize glTF/GLB conversion outputs."
check_tool required gltfpack "Fast mesh and scene optimization for converted glTF/GLB files."
check_tool required magick "Texture/image inspection and conversion helper."
check_tool required ffmpeg "Audio/video conversion and test capture helper."

printf '\n'
print_category "Data And Protocol Work"
check_tool required sqlite3 "Inspect local derived SQLite data and generated reports."
check_tool required sqlite-utils "Export and query local SQLite tables quickly."
check_tool required jq "Read and reshape JSON reports."
check_tool required tshark "Inspect local-only packet captures."
check_tool required tcpdump "Capture local loopback protocol traffic when needed."
check_tool required scapy "Prototype packet parsing and safe local packet experiments."

printf '\n'
print_category "Playable Testing And Debugging"
check_tool required xvfb-run "Run GUI-oriented checks in a virtual display."
check_tool required xdotool "Automate keyboard and mouse input for local test clients."
check_tool required wmctrl "Position and inspect local desktop windows during multi-client tests."
check_tool required wine "Run the original Windows client locally for authorized reference comparison."
check_tool required apitrace "Capture graphics API traces for local rendering diagnostics."
check_tool optional renderdoccmd "GPU frame debugging; deferred because it is not available from apt or Snap here."

printf '\n'
print_category "Build And Quality Loop"
check_tool required cmake "Configure native protocol and Godot extension builds."
check_tool required ninja "Fast native rebuilds."
check_tool required cargo-watch "Automatically rerun Rust/native helper checks while editing."
check_tool required shellcheck "Validate shell automation scripts."
check_tool required gdformat "Format GDScript files."
check_tool required gdlint "Lint GDScript files."

check_snap_media_access
check_local_ai
print_versions
print_summary

exit "${MISSING_REQUIRED}"
