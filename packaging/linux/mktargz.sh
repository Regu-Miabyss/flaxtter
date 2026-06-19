#!/usr/bin/env bash
# Build a relocatable .tar.gz from a Flutter Linux release bundle.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"
packaging_linux_common_init "$SCRIPT_DIR"

ARCH="${1:?Usage: mktargz.sh <x86_64|arm64> <bundle-dir> <output-dir>}"
BUNDLE_DIR="${2:?}"
OUTPUT_DIR="${3:?}"

ensure_bundle "$BUNDLE_DIR"
mkdir -p "$OUTPUT_DIR"

TAR_NAME="${APP_NAME}-${VERSION_NAME}+${BUILD_NUMBER}-linux-${ARCH}.tar.gz"
tar -C "$BUNDLE_DIR" -czf "$OUTPUT_DIR/$TAR_NAME" .
echo "Created $OUTPUT_DIR/$TAR_NAME"
