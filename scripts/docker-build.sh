#!/usr/bin/env bash
#
# Build everything inside the pinned Docker toolchain.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${IMAGE:-legacyfixes-build}"

docker build -t "$IMAGE" -f "$ROOT/docker/Dockerfile" "$ROOT"

docker run --rm \
    -u "$(id -u):$(id -g)" \
    -e HOME=/tmp \
    -v "$ROOT:/work" \
    -w /work \
    "$IMAGE" \
    ./scripts/build.sh
