#!/usr/bin/env bash
# Package a Flutter Linux release bundle as .deb, .rpm, .AppImage, and .tar.gz.
#
# Usage:
#   ./packaging/linux/package.sh <x86_64|arm64> <bundle-dir> <output-dir>
#   FORMATS=deb,rpm ./packaging/linux/package.sh x86_64 build/linux/x64/release/bundle dist/linux
#
# FORMATS (comma-separated, default: deb,rpm,appimage,tar.gz):
#   deb | rpm | appimage | tar.gz
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ARCH="${1:?Usage: package.sh <x86_64|arm64> <bundle-dir> <output-dir>}"
BUNDLE_DIR="${2:?}"
OUTPUT_DIR="${3:?}"

FORMATS="${FORMATS:-deb,rpm,appimage,tar.gz}"
IFS=',' read -r -a FORMAT_LIST <<<"$FORMATS"

want_format() {
  local needle="$1"
  local fmt
  for fmt in "${FORMAT_LIST[@]}"; do
    if [[ "$fmt" == "$needle" ]]; then
      return 0
    fi
  done
  return 1
}

mkdir -p "$OUTPUT_DIR"

for fmt in "${FORMAT_LIST[@]}"; do
  case "$fmt" in
    deb|rpm|appimage|tar.gz) ;;
    *)
      echo "Unknown format: $fmt (use deb, rpm, appimage, tar.gz)" >&2
      exit 1
      ;;
  esac
done

if want_format deb; then
  bash "$SCRIPT_DIR/mkdeb.sh" "$ARCH" "$BUNDLE_DIR" "$OUTPUT_DIR"
fi

if want_format rpm; then
  bash "$SCRIPT_DIR/mkrpm.sh" "$ARCH" "$BUNDLE_DIR" "$OUTPUT_DIR"
fi

if want_format appimage; then
  bash "$SCRIPT_DIR/mkappimage.sh" "$ARCH" "$BUNDLE_DIR" "$OUTPUT_DIR"
fi

if want_format tar.gz; then
  bash "$SCRIPT_DIR/mktargz.sh" "$ARCH" "$BUNDLE_DIR" "$OUTPUT_DIR"
fi
