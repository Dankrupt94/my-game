#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_IMAGE="acore-godot-protocol-build:24.04"
IMAGE="${ACORE_GODOT_EXTENSION_BUILD_IMAGE:-${DEFAULT_IMAGE}}"

if [[ "${ACORE_REBUILD_GODOT_EXTENSION_BUILD_IMAGE:-0}" == "1" ]]; then
    "${ROOT_DIR}/tools/build_godot_protocol_build_image.sh"
elif ! docker image inspect "${IMAGE}" >/dev/null 2>&1; then
    if [[ "${IMAGE}" == "${DEFAULT_IMAGE}" ]]; then
        "${ROOT_DIR}/tools/build_godot_protocol_build_image.sh"
    else
        printf 'Docker image not found: %s\n' "${IMAGE}" >&2
        printf 'Build it first or unset ACORE_GODOT_EXTENSION_BUILD_IMAGE to use %s.\n' "${DEFAULT_IMAGE}" >&2
        exit 1
    fi
fi

if [[ ! -f "${ROOT_DIR}/local_dependencies/godot-api/extension_api.json" ]]; then
    mkdir -p "${ROOT_DIR}/local_dependencies/godot-api"
    (
        cd "${ROOT_DIR}/local_dependencies/godot-api"
        godot-4 --headless --dump-extension-api --quit
    )
fi

if [[ ! -d "${ROOT_DIR}/local_dependencies/godot-cpp/.git" ]]; then
    mkdir -p "${ROOT_DIR}/local_dependencies"
    git clone --depth 1 https://github.com/godotengine/godot-cpp.git "${ROOT_DIR}/local_dependencies/godot-cpp"
fi

docker run --rm \
    -v "${ROOT_DIR}:/work" \
    -w /work \
    -e ACORE_BUILD_JOBS="${ACORE_BUILD_JOBS:-}" \
    -e ACORE_CMAKE_GENERATOR="${ACORE_CMAKE_GENERATOR:-}" \
    -e CCACHE_DIR="/work/local_dependencies/.ccache" \
    "${IMAGE}" \
    bash -lc '
set -euo pipefail

if ! command -v cmake >/dev/null 2>&1 || ! command -v scons >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        ccache \
        cmake \
        git \
        libssl-dev \
        ninja-build \
        pkg-config \
        python3 \
        scons \
        zlib1g-dev
fi

JOBS="${ACORE_BUILD_JOBS:-$(nproc)}"
mkdir -p "${CCACHE_DIR}"

configure_cmake() {
    local source_dir="$1"
    local build_dir="$2"
    shift 2

    local generator="${ACORE_CMAKE_GENERATOR:-}"
    if [[ -z "${generator}" && ! -f "${build_dir}/CMakeCache.txt" ]] && command -v ninja >/dev/null 2>&1; then
        generator="Ninja"
    fi

    local compiler_cache_args=()
    if command -v ccache >/dev/null 2>&1; then
        compiler_cache_args=(
            -DCMAKE_C_COMPILER_LAUNCHER=ccache
            -DCMAKE_CXX_COMPILER_LAUNCHER=ccache
        )
    fi

    if [[ -n "${generator}" ]]; then
        cmake -S "${source_dir}" -B "${build_dir}" -G "${generator}" "${compiler_cache_args[@]}" "$@"
    else
        cmake -S "${source_dir}" -B "${build_dir}" "${compiler_cache_args[@]}" "$@"
    fi
}

cd /work/local_dependencies/godot-cpp
scons platform=linux custom_api_file=../godot-api/extension_api.json target=template_debug -j"${JOBS}"

cd /work
configure_cmake native/protocol_client native/protocol_client/build-compat -DCMAKE_BUILD_TYPE=Debug
cmake --build native/protocol_client/build-compat --parallel "${JOBS}"

configure_cmake native/godot_protocol_extension native/godot_protocol_extension/build-compat \
    -DPROTOCOL_BUILD_DIR=/work/native/protocol_client/build-compat \
    -DGODOT_CPP_DIR=/work/local_dependencies/godot-cpp \
    -DGODOT_CPP_LIBRARY=/work/local_dependencies/godot-cpp/bin/libgodot-cpp.linux.template_debug.x86_64.a
cmake --build native/godot_protocol_extension/build-compat --parallel "${JOBS}"
'
