#!/usr/bin/env bash
# Build Flaxtter release artifacts: Linux .deb/.tar.gz and Android .apk.
#
# Linux desktop (Flutter): x86_64, arm64
# Android APK (Flutter):    armv7 (android-arm), arm64, x86_64
#
# Usage:
#   ./packaging/build.sh              # build everything possible on this host
#   ./packaging/build.sh linux        # Linux packages only
#   ./packaging/build.sh android      # Android APKs only
#   ./packaging/build.sh linux x86_64 # single Linux arch
#
# Cross-compile Linux arm64 from x86_64 host:
#   export LINUX_ARM64_SYSROOT=/path/to/arm64-sysroot
#   ./packaging/build.sh linux arm64
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
LINUX_SCRIPT="$SCRIPT_DIR/linux/package.sh"

TARGET="${1:-all}"
ARCH_FILTER="${2:-}"

mkdir -p "$DIST_DIR/linux" "$DIST_DIR/android"
cd "$ROOT_DIR"

build_linux_arch() {
  local arch="$1"
  local flutter_platform=""
  local flutter_arch_dir=""
  local extra_args=()

  case "$arch" in
    x86_64)
      flutter_platform="linux-x64"
      flutter_arch_dir="x64"
      if [[ "$(uname -m)" != "x86_64" ]]; then
        echo "Skip linux/x86_64: host is $(uname -m), need native x86_64 builder" >&2
        return 0
      fi
      ;;
    arm64)
      flutter_platform="linux-arm64"
      flutter_arch_dir="arm64"
      if [[ "$(uname -m)" == "aarch64" || "$(uname -m)" == "arm64" ]]; then
        : # native arm64 build
      elif [[ -n "${LINUX_ARM64_SYSROOT:-}" ]]; then
        extra_args+=(--target-sysroot="$LINUX_ARM64_SYSROOT")
      else
        echo "Skip linux/arm64: set LINUX_ARM64_SYSROOT for cross-compile, or build on arm64 host" >&2
        return 0
      fi
      ;;
    armv7)
      echo "Skip linux/armv7: Flutter Linux desktop does not support 32-bit ARM" >&2
      return 0
      ;;
    *)
      echo "Unknown Linux arch: $arch" >&2
      return 1
      ;;
  esac

  echo "==> Building Linux $arch ($flutter_platform)"
  flutter build linux --release \
    --target-platform="$flutter_platform" \
    "${extra_args[@]}"

  local bundle="$ROOT_DIR/build/linux/$flutter_arch_dir/release/bundle"
  bash "$LINUX_SCRIPT" "$arch" "$bundle" "$DIST_DIR/linux"
}

build_linux() {
  local arches=(x86_64 arm64)
  if [[ -n "$ARCH_FILTER" ]]; then
    arches=("$ARCH_FILTER")
  fi
  for arch in "${arches[@]}"; do
    build_linux_arch "$arch"
  done
}

build_android() {
  echo "==> Building Android APKs (armv7, arm64, x86_64)"
  if [[ -f "$ROOT_DIR/android/key.properties" ]]; then
    echo "    Using release keystore from android/key.properties"
  else
    echo "    WARNING: android/key.properties not found; APK will be signed with debug key"
  fi

  flutter build apk --release --split-per-abi

  local version
  version="$(grep '^version:' pubspec.yaml | awk '{print $2}')"
  local version_name="${version%%+*}"
  local build_number="${version#*+}"
  if [[ "$build_number" == "$version" ]]; then
    build_number="1"
  fi

  local apk_dir="$ROOT_DIR/build/app/outputs/flutter-apk"
  local mappings=(
    "app-armeabi-v7a-release.apk:armv7"
    "app-arm64-v8a-release.apk:arm64"
    "app-x86_64-release.apk:x86_64"
  )

  for entry in "${mappings[@]}"; do
    local src="${entry%%:*}"
    local label="${entry##*:}"
    if [[ -n "$ARCH_FILTER" && "$ARCH_FILTER" != "$label" ]]; then
      continue
    fi
    if [[ -f "$apk_dir/$src" ]]; then
      local dest="flaxtter-${version_name}+${build_number}-android-${label}.apk"
      cp "$apk_dir/$src" "$DIST_DIR/android/$dest"
      echo "Created $DIST_DIR/android/$dest"
    fi
  done
}

case "$TARGET" in
  all)
    build_linux
    build_android
    ;;
  linux)
    build_linux
    ;;
  android|apk)
    build_android
    ;;
  *)
    echo "Unknown target: $TARGET (use all, linux, or android)" >&2
    exit 1
    ;;
esac

echo ""
echo "Done. Artifacts in $DIST_DIR/"
