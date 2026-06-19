#!/usr/bin/env bash
# Build a .deb from a Flutter Linux release bundle.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
packaging_linux_common_init "$SCRIPT_DIR"

ARCH="${1:?Usage: mkdeb.sh <x86_64|arm64> <bundle-dir> <output-dir>}"
BUNDLE_DIR="${2:?}"
OUTPUT_DIR="${3:?}"

ensure_bundle "$BUNDLE_DIR"
DEB_ARCH="$(arch_to_deb "$ARCH")"
mkdir -p "$OUTPUT_DIR"

STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

PKG_ROOT="$STAGING/deb"
mkdir -p \
  "$PKG_ROOT/DEBIAN" \
  "$PKG_ROOT$INSTALL_PREFIX" \
  "$PKG_ROOT/usr/bin" \
  "$PKG_ROOT/usr/share/applications" \
  "$PKG_ROOT/usr/share/icons/hicolor/256x256/apps"

cp -a "$BUNDLE_DIR/." "$PKG_ROOT$INSTALL_PREFIX/"
write_launcher_wrapper "$PKG_ROOT/usr/bin/$APP_NAME"
cp "$DESKTOP_SRC" "$PKG_ROOT/usr/share/applications/$APP_NAME.desktop"
install_icon "$PKG_ROOT/usr/share/icons/hicolor/256x256/apps"

INSTALLED_SIZE="$(du -sk "$PKG_ROOT$INSTALL_PREFIX" | awk '{print $1}')"

cat >"$PKG_ROOT/DEBIAN/control" <<EOF
Package: $APP_NAME
Version: ${VERSION_NAME}-${BUILD_NUMBER}
Section: net
Priority: optional
Architecture: $DEB_ARCH
Maintainer: Flaxtter <https://github.com/regu/flaxtter>
Installed-Size: $INSTALLED_SIZE
Depends: libwebkit2gtk-4.1-0, libsoup-3.0-0, libgtk-3-0, libmpv2
Description: A Twitter/X client for Linux
 Flaxtter is a third-party Twitter/X client. It signs in through a WebView
 cookie session and talks to X using a custom API layer.
EOF

DEB_NAME="${APP_NAME}_${VERSION_NAME}-${BUILD_NUMBER}_${DEB_ARCH}.deb"
dpkg-deb --build --root-owner-group "$PKG_ROOT" "$OUTPUT_DIR/$DEB_NAME"
echo "Created $OUTPUT_DIR/$DEB_NAME"
