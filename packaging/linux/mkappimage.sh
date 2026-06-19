#!/usr/bin/env bash
# Build an AppImage from a Flutter Linux release bundle.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
packaging_linux_common_init "$SCRIPT_DIR"

ARCH="${1:?Usage: mkappimage.sh <x86_64|arm64> <bundle-dir> <output-dir>}"
BUNDLE_DIR="${2:?}"
OUTPUT_DIR="${3:?}"

ensure_bundle "$BUNDLE_DIR"
APPIMAGE_ARCH="$(arch_to_appimage "$ARCH")"
mkdir -p "$OUTPUT_DIR"

TOOLS_DIR="$PACKAGING_LINUX_DIR/.tools"
mkdir -p "$TOOLS_DIR"

resolve_appimagetool() {
  local tool="$TOOLS_DIR/appimagetool-${APPIMAGE_ARCH}.AppImage"
  if [[ -x "$tool" ]]; then
    echo "$tool"
    return 0
  fi

  if command -v appimagetool >/dev/null 2>&1; then
    echo "appimagetool"
    return 0
  fi

  local url="https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-${APPIMAGE_ARCH}.AppImage"
  echo "Downloading appimagetool (${APPIMAGE_ARCH})..." >&2
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$tool"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$tool" "$url"
  else
    echo "ERROR: need curl or wget to download appimagetool" >&2
    exit 1
  fi
  chmod +x "$tool"
  echo "$tool"
}

STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

APP_DIR="$STAGING/${APP_NAME}.AppDir"
mkdir -p "$APP_DIR/usr/bin"
cp -a "$BUNDLE_DIR/." "$APP_DIR/usr/bin/"
cp "$DESKTOP_SRC" "$APP_DIR/$APP_NAME.desktop"
install_icon "$APP_DIR"

cat >"$APP_DIR/AppRun" <<'APPRUN'
#!/bin/sh
APPDIR="$(dirname "$(readlink -f "$0")")"
cd "$APPDIR/usr/bin"
exec "$APPDIR/usr/bin/flaxtter" "$@"
APPRUN
chmod 755 "$APP_DIR/AppRun"

APPIMAGETOOL="$(resolve_appimagetool)"
APPIMAGE_NAME="${APP_NAME}-${VERSION_NAME}+${BUILD_NUMBER}-linux-${ARCH}.AppImage"
APPIMAGE_PATH="$OUTPUT_DIR/$APPIMAGE_NAME"

export ARCH="$APPIMAGE_ARCH"
if [[ "$APPIMAGETOOL" == "appimagetool" ]]; then
  appimagetool "$APP_DIR" "$APPIMAGE_PATH"
else
  # Run the downloaded AppImage without FUSE when possible.
  if "$APPIMAGETOOL" --appimage-extract-and-run "$APP_DIR" "$APPIMAGE_PATH" 2>/dev/null; then
    :
  else
    "$APPIMAGETOOL" "$APP_DIR" "$APPIMAGE_PATH"
  fi
fi

echo "Created $APPIMAGE_PATH"
