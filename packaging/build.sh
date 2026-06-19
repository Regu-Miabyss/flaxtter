#!/usr/bin/env bash
# Build Flaxtter release artifacts.
#
# Linux desktop (Flutter): x86_64, arm64
#   Packages: .deb, .rpm, .AppImage, .tar.gz
# Android APK (Flutter):    armv7 (android-arm), arm64, x86_64
#
# Usage:
#   ./packaging/build.sh                    # build everything possible on this host
#   ./packaging/build.sh linux              # Linux packages only
#   ./packaging/build.sh linux x86_64       # single Linux arch
#   ./packaging/build.sh linux arm64 deb    # Linux arm64, .deb only
#   ./packaging/build.sh android            # Android APKs only
#
# Linux arm64 on x86_64 host:
#   Flutter does NOT support cross-compiling linux-arm64 from linux-x64.
#   This script uses Docker/Podman (--platform linux/arm64 + QEMU) automatically.
#   Requires: docker or podman, qemu-user-static / binfmt (see build-in-container.sh).
#
# Environment:
#   FORMATS              deb,rpm,appimage,tar.gz (default: all four)
#   CONTAINER_ENGINE     docker or podman (auto-detected)
#   REBUILD_BUILDER      1 to rebuild the Linux builder container image
#   LINUX_ARM64_METHOD   auto | container | native  (default: auto)
#
# Linux packaging tools (install as needed):
#   deb:       dpkg-deb (debhelper / dpkg)
#   rpm:       rpmbuild (rpm-build / rpmdevtools)
#   appimage:  curl/wget (auto-downloads appimagetool) or appimagetool in PATH
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
LINUX_SCRIPT="$SCRIPT_DIR/linux/package.sh"
CONTAINER_SCRIPT="$SCRIPT_DIR/linux/build-in-container.sh"

TARGET="${1:-all}"
ARCH_FILTER="${2:-}"
FORMAT_FILTER="${3:-}"

if [[ -n "$FORMAT_FILTER" ]]; then
  export FORMATS="$FORMAT_FILTER"
fi

mkdir -p "$DIST_DIR/linux" "$DIST_DIR/android"
cd "$ROOT_DIR"

host_is_arm64() {
  [[ "$(uname -m)" == "aarch64" || "$(uname -m)" == "arm64" ]]
}

host_is_x86_64() {
  [[ "$(uname -m)" == "x86_64" ]]
}

container_engine_available() {
  [[ -n "${CONTAINER_ENGINE:-}" ]] && return 0
  command -v docker >/dev/null 2>&1 || command -v podman >/dev/null 2>&1
}

build_linux_native() {
  local arch="$1"
  local flutter_platform="$2"

  echo "==> Building Linux $arch natively ($flutter_platform)"
  flutter build linux --release --target-platform="$flutter_platform"
}

build_linux_via_container() {
  local arch="$1"
  bash "$CONTAINER_SCRIPT" "$arch"
}

build_linux_arch() {
  local arch="$1"
  local flutter_platform=""
  local flutter_arch_dir=""

  case "$arch" in
    x86_64)
      flutter_platform="linux-x64"
      flutter_arch_dir="x64"
      if host_is_x86_64; then
        build_linux_native "$arch" "$flutter_platform"
      elif host_is_arm64; then
        if container_engine_available; then
          echo "Note: building linux/x86_64 via amd64 container (no native x86_64 host)" >&2
          build_linux_via_container "$arch"
        else
          echo "Skip linux/x86_64: host is $(uname -m); install docker/podman or use an x86_64 machine" >&2
          return 0
        fi
      else
        echo "Skip linux/x86_64: unsupported host $(uname -m)" >&2
        return 0
      fi
      ;;
    arm64)
      flutter_platform="linux-arm64"
      flutter_arch_dir="arm64"
      if host_is_arm64; then
        build_linux_native "$arch" "$flutter_platform"
      elif host_is_x86_64; then
        local method="${LINUX_ARM64_METHOD:-auto}"
        case "$method" in
          native)
            echo "ERROR: Flutter cannot cross-build linux-arm64 from linux-x64." >&2
            echo "Use LINUX_ARM64_METHOD=container, an arm64 host, or CI on arm64 runners." >&2
            exit 1
            ;;
          container|auto)
            if container_engine_available; then
              echo "Note: Flutter has no x64→arm64 cross-compile; using arm64 container build" >&2
              build_linux_via_container "$arch"
            else
              echo "Skip linux/arm64: Flutter cannot cross-compile from x86_64." >&2
              echo "  Install docker/podman + qemu-user-static, or build on an arm64 machine." >&2
              return 0
            fi
            ;;
          *)
            echo "Unknown LINUX_ARM64_METHOD: $method (use auto, container, or native)" >&2
            exit 1
            ;;
        esac
      else
        echo "Skip linux/arm64: unsupported host $(uname -m)" >&2
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
