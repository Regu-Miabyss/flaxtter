#!/usr/bin/env bash
# Build an .rpm from a Flutter Linux release bundle.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
packaging_linux_common_init "$SCRIPT_DIR"

ARCH="${1:?Usage: mkrpm.sh <x86_64|arm64> <bundle-dir> <output-dir>}"
BUNDLE_DIR="${2:?}"
OUTPUT_DIR="${3:?}"

if ! command -v rpmbuild >/dev/null 2>&1; then
  echo "Skip .rpm: rpmbuild not found (install rpm-build / rpmdevtools)" >&2
  exit 0
fi

ensure_bundle "$BUNDLE_DIR"
RPM_ARCH="$(arch_to_rpm "$ARCH")"
mkdir -p "$OUTPUT_DIR"

STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

RPM_TOP="$STAGING/rpm"
mkdir -p "$RPM_TOP"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
cp -a "$BUNDLE_DIR" "$RPM_TOP/BUILD/bundle"

SPEC_FILE="$RPM_TOP/SPECS/$APP_NAME.spec"
cat >"$SPEC_FILE" <<EOF
Name:           $APP_NAME
Version:        $VERSION_NAME
Release:        $BUILD_NUMBER%{?dist}
Summary:        A Twitter/X client for Linux
License:        MIT
URL:            https://github.com/regu/flaxtter
BuildArch:      $RPM_ARCH
AutoReqProv:    no
Requires:       gtk3, libsoup3, webkit2gtk4.1, mpv-libs

%description
Flaxtter is a third-party Twitter/X client. It signs in through a WebView
cookie session and talks to X using a custom API layer.

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}$INSTALL_PREFIX
mkdir -p %{buildroot}/usr/bin
mkdir -p %{buildroot}/usr/share/applications
mkdir -p %{buildroot}/usr/share/icons/hicolor/256x256/apps
cp -a %{_builddir}/bundle/. %{buildroot}$INSTALL_PREFIX/
cat > %{buildroot}/usr/bin/$APP_NAME << 'WRAPPER'
#!/bin/sh
exec $INSTALL_PREFIX/$APP_NAME "\$@"
WRAPPER
chmod 755 %{buildroot}/usr/bin/$APP_NAME
cp %{_sourcedir}/$APP_NAME.desktop %{buildroot}/usr/share/applications/$APP_NAME.desktop
cp %{_sourcedir}/$APP_NAME.png %{buildroot}/usr/share/icons/hicolor/256x256/apps/$APP_NAME.png

%files
%defattr(-,root,root,-)
$INSTALL_PREFIX
/usr/bin/$APP_NAME
/usr/share/applications/$APP_NAME.desktop
/usr/share/icons/hicolor/256x256/apps/$APP_NAME.png

%changelog
* $(date -R) Flaxtter <$APP_NAME@local> - $VERSION_NAME-$BUILD_NUMBER
- Release $VERSION_NAME build $BUILD_NUMBER for $RPM_ARCH
EOF

cp "$DESKTOP_SRC" "$RPM_TOP/SOURCES/$APP_NAME.desktop"
if [[ -f "$ICON_SRC" ]]; then
  cp "$ICON_SRC" "$RPM_TOP/SOURCES/$APP_NAME.png"
else
  echo "WARNING: icon not found at $ICON_SRC" >&2
  touch "$RPM_TOP/SOURCES/$APP_NAME.png"
fi

rpmbuild -bb \
  --define "_topdir $RPM_TOP" \
  --define "_builddir $RPM_TOP/BUILD" \
  --define "_sourcedir $RPM_TOP/SOURCES" \
  "$SPEC_FILE"

RPM_GLOB="$RPM_TOP/RPMS/$RPM_ARCH/${APP_NAME}-${VERSION_NAME}-${BUILD_NUMBER}*.rpm"
shopt -s nullglob
RPM_FILES=($RPM_GLOB)
shopt -u nullglob

if ((${#RPM_FILES[@]} == 0)); then
  echo "ERROR: rpmbuild finished but no .rpm found under $RPM_TOP/RPMS/$RPM_ARCH" >&2
  exit 1
fi

RPM_NAME="${APP_NAME}-${VERSION_NAME}+${BUILD_NUMBER}-linux-${ARCH}.rpm"
cp "${RPM_FILES[0]}" "$OUTPUT_DIR/$RPM_NAME"
echo "Created $OUTPUT_DIR/$RPM_NAME"
