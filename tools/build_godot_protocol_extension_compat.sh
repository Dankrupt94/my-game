#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${ACORE_GODOT_EXTENSION_BUILD_IMAGE:-ubuntu:24.04}"

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
    "${IMAGE}" \
    bash -lc '
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    cmake \
    git \
    libssl-dev \
    pkg-config \
    python3 \
    scons \
    zlib1g-dev

cd /work/local_dependencies/godot-cpp
scons platform=linux custom_api_file=../godot-api/extension_api.json target=template_debug -j"$(nproc)"

cd /work
cmake -S native/protocol_client -B native/protocol_client/build-compat -DCMAKE_BUILD_TYPE=Debug
cmake --build native/protocol_client/build-compat -j"$(nproc)"

cmake -S native/godot_protocol_extension -B native/godot_protocol_extension/build-compat \
    -DPROTOCOL_BUILD_DIR=/work/native/protocol_client/build-compat \
    -DGODOT_CPP_DIR=/work/local_dependencies/godot-cpp \
    -DGODOT_CPP_LIBRARY=/work/local_dependencies/godot-cpp/bin/libgodot-cpp.linux.template_debug.x86_64.a
cmake --build native/godot_protocol_extension/build-compat -j"$(nproc)"
'
