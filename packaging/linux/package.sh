#!/usr/bin/env bash
# Package a Flutter Linux release bundle as .deb and .tar.gz.
set -euo pipefail

ARCH="${1:?Usage: package.sh <x86_64|arm64> <bundle-dir> <output-dir>}"
BUNDLE_DIR="${2:?}"
OUTPUT_DIR="${3:?}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Read version from pubspec.yaml (e.g. 0.1.0+1 -> 0.1.0, 1)
VERSION="$(grep '^version:' "$ROOT_DIR/pubspec.yaml" | awk '{print $2}')"
VERSION_NAME="${VERSION%%+*}"
BUILD_NUMBER="${VERSION#*+}"
if [[ "$BUILD_NUMBER" == "$VERSION" ]]; then
  BUILD_NUMBER="1"
fi

APP_ID="regu.flaxtter"
APP_NAME="flaxtter"
INSTALL_PREFIX="/opt/flaxtter"
DEB_ARCH=""
FLUTTER_ARCH_DIR=""

case "$ARCH" in
  x86_64)
    DEB_ARCH="amd64"
    FLUTTER_ARCH_DIR="x64"
    ;;
  arm64)
    DEB_ARCH="arm64"
    FLUTTER_ARCH_DIR="arm64"
    ;;
  *)
    echo "Unsupported Linux arch: $ARCH (Flutter desktop supports x86_64 and arm64 only)" >&2
    exit 1
    ;;
esac

if [[ ! -x "$BUNDLE_DIR/$APP_NAME" ]]; then
  echo "Bundle not found or not executable: $BUNDLE_DIR/$APP_NAME" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

# --- .tar.gz (relocatable bundle) ---
TAR_NAME="${APP_NAME}-${VERSION_NAME}+${BUILD_NUMBER}-linux-${ARCH}.tar.gz"
tar -C "$BUNDLE_DIR" -czf "$OUTPUT_DIR/$TAR_NAME" .
echo "Created $OUTPUT_DIR/$TAR_NAME"

# --- .deb ---
PKG_ROOT="$STAGING/deb"
mkdir -p \
  "$PKG_ROOT/DEBIAN" \
  "$PKG_ROOT$INSTALL_PREFIX" \
  "$PKG_ROOT/usr/bin" \
  "$PKG_ROOT/usr/share/applications" \
  "$PKG_ROOT/usr/share/icons/hicolor/256x256/apps"

cp -a "$BUNDLE_DIR/." "$PKG_ROOT$INSTALL_PREFIX/"

cat >"$PKG_ROOT/usr/bin/$APP_NAME" <<'WRAPPER'
#!/bin/sh
exec /opt/flaxtter/flaxtter "$@"
WRAPPER
chmod 755 "$PKG_ROOT/usr/bin/$APP_NAME"

cp "$SCRIPT_DIR/flaxtter.desktop" "$PKG_ROOT/usr/share/applications/$APP_NAME.desktop"

ICON_SRC="$ROOT_DIR/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png"
if [[ -f "$ICON_SRC" ]]; then
  cp "$ICON_SRC" "$PKG_ROOT/usr/share/icons/hicolor/256x256/apps/$APP_NAME.png"
fi

INSTALLED_SIZE="$(du -sk "$PKG_ROOT$INSTALL_PREFIX" | awk '{print $1}')"

cat >"$PKG_ROOT/DEBIAN/control" <<EOF
Package: $APP_NAME
Version: ${VERSION_NAME}-${BUILD_NUMBER}
Section: net
Priority: optional
Architecture: $DEB_ARCH
Maintainer: Flaxtter <https://github.com/regu/flaxtter>
Installed-Size: $INSTALLED_SIZE
Depends: libwebkit2gtk-4.1-0, libsoup-3.0-0, libgtk-3-0
Description: A Twitter/X client for Linux
 Flaxtter is a third-party Twitter/X client. It signs in through a WebView
 cookie session and talks to X using a custom API layer.
EOF

DEB_NAME="${APP_NAME}_${VERSION_NAME}-${BUILD_NUMBER}_${DEB_ARCH}.deb"
dpkg-deb --build --root-owner-group "$PKG_ROOT" "$OUTPUT_DIR/$DEB_NAME"
echo "Created $OUTPUT_DIR/$DEB_NAME"
