#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${ACORE_GODOT_EXTENSION_BUILD_IMAGE:-acore-godot-protocol-build:24.04}"
DOCKER_CONTEXT="${ROOT_DIR}/tools/docker"

docker build \
    -t "${IMAGE}" \
    -f "${DOCKER_CONTEXT}/godot-protocol-build.Dockerfile" \
    "${DOCKER_CONTEXT}"

printf 'Built Godot protocol build image: %s\n' "${IMAGE}"
