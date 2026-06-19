#!/usr/bin/env bash
# Shared metadata and helpers for Linux packaging scripts.
set -euo pipefail

packaging_linux_common_init() {
  local script_dir="$1"
  PACKAGING_LINUX_DIR="$script_dir"
  ROOT_DIR="$(cd "$script_dir/../.." && pwd)"

  VERSION="$(grep '^version:' "$ROOT_DIR/pubspec.yaml" | awk '{print $2}')"
  VERSION_NAME="${VERSION%%+*}"
  BUILD_NUMBER="${VERSION#*+}"
  if [[ "$BUILD_NUMBER" == "$VERSION" ]]; then
    BUILD_NUMBER="1"
  fi

  APP_ID="regu.flaxtter"
  APP_NAME="flaxtter"
  INSTALL_PREFIX="/opt/flaxtter"
  ICON_SRC="$ROOT_DIR/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png"
  DESKTOP_SRC="$PACKAGING_LINUX_DIR/flaxtter.desktop"
}

arch_to_deb() {
  case "$1" in
    x86_64) echo "amd64" ;;
    arm64) echo "arm64" ;;
    *) echo "Unsupported deb arch: $1" >&2; return 1 ;;
  esac
}

arch_to_rpm() {
  case "$1" in
    x86_64) echo "x86_64" ;;
    arm64) echo "aarch64" ;;
    *) echo "Unsupported rpm arch: $1" >&2; return 1 ;;
  esac
}

arch_to_appimage() {
  case "$1" in
    x86_64) echo "x86_64" ;;
    arm64) echo "aarch64" ;;
    *) echo "Unsupported AppImage arch: $1" >&2; return 1 ;;
  esac
}

ensure_bundle() {
  local bundle_dir="$1"
  if [[ ! -x "$bundle_dir/$APP_NAME" ]]; then
    echo "Bundle not found or not executable: $bundle_dir/$APP_NAME" >&2
    exit 1
  fi
}

install_icon() {
  local dest_dir="$1"
  mkdir -p "$dest_dir"
  if [[ -f "$ICON_SRC" ]]; then
    cp "$ICON_SRC" "$dest_dir/$APP_NAME.png"
  else
    echo "WARNING: icon not found at $ICON_SRC" >&2
  fi
}

write_launcher_wrapper() {
  local dest="$1"
  cat >"$dest" <<'WRAPPER'
#!/bin/sh
exec /opt/flaxtter/flaxtter "$@"
WRAPPER
  chmod 755 "$dest"
}
