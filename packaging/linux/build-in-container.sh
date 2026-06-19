#!/usr/bin/env bash
# Build Flutter Linux release inside a container (native arch, not cross-compile).
#
# Usage:
#   ./packaging/linux/build-in-container.sh x86_64
#   ./packaging/linux/build-in-container.sh arm64
#
# Environment:
#   CONTAINER_ENGINE   docker (default) or podman
#   REBUILD_BUILDER    1 to force rebuild of the builder image
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

ARCH="${1:?Usage: build-in-container.sh <x86_64|arm64>}"

case "$ARCH" in
  x86_64) DOCKER_PLATFORM="linux/amd64" ;;
  arm64) DOCKER_PLATFORM="linux/arm64" ;;
  *)
    echo "Unsupported arch: $ARCH" >&2
    exit 1
    ;;
esac

ENGINE="${CONTAINER_ENGINE:-}"
if [[ -z "$ENGINE" ]]; then
  if command -v docker >/dev/null 2>&1; then
    ENGINE="docker"
  elif command -v podman >/dev/null 2>&1; then
    ENGINE="podman"
  else
    echo "ERROR: need docker or podman (set CONTAINER_ENGINE)" >&2
    exit 1
  fi
fi

if [[ "$(uname -m)" == "x86_64" && "$ARCH" == "arm64" ]]; then
  if ! "$ENGINE" run --rm --platform linux/arm64 alpine:3.20 uname -m >/dev/null 2>&1; then
    echo "ERROR: arm64 containers do not run on this x86_64 host." >&2
    echo "Install QEMU user emulation, for example:" >&2
    echo "  Debian/Ubuntu: sudo apt install qemu-user-static binfmt-support" >&2
    echo "  Then: sudo $ENGINE run --privileged --rm tonistiigi/binfmt --install all" >&2
    echo "Or build linux/arm64 on a real arm64 machine instead." >&2
    exit 1
  fi
fi

IMAGE="flaxtter-linux-builder:${ARCH}"
DOCKERFILE="$SCRIPT_DIR/Dockerfile.build"

if [[ "${REBUILD_BUILDER:-0}" == "1" ]] || ! "$ENGINE" image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "==> Building container image $IMAGE ($DOCKER_PLATFORM)"
  "$ENGINE" build --platform "$DOCKER_PLATFORM" -f "$DOCKERFILE" -t "$IMAGE" "$ROOT_DIR"
fi

echo "==> Flutter build in container ($ARCH / $DOCKER_PLATFORM)"
"$ENGINE" run --rm --platform "$DOCKER_PLATFORM" \
  -v "$ROOT_DIR:/src" \
  -e FLAXTTER_LINUX_ARCH="$ARCH" \
  "$IMAGE"

BUNDLE="$ROOT_DIR/build/linux/$( [[ "$ARCH" == x86_64 ]] && echo x64 || echo arm64 )/release/bundle"
if [[ ! -x "$BUNDLE/flaxtter" ]]; then
  echo "ERROR: expected bundle at $BUNDLE/flaxtter" >&2
  exit 1
fi

echo "Built $BUNDLE"
