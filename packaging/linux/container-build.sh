#!/usr/bin/env bash
# Runs inside the Linux builder container (native amd64 or arm64).
set -euo pipefail

ARCH="${FLAXTTER_LINUX_ARCH:?Set FLAXTTER_LINUX_ARCH to x86_64 or arm64}"

case "$ARCH" in
  x86_64)
    FLUTTER_PLATFORM="linux-x64"
    ;;
  arm64)
    FLUTTER_PLATFORM="linux-arm64"
    ;;
  *)
    echo "Unsupported FLAXTTER_LINUX_ARCH: $ARCH" >&2
    exit 1
    ;;
esac

cd /src
flutter pub get
flutter build linux --release --target-platform="$FLUTTER_PLATFORM"
