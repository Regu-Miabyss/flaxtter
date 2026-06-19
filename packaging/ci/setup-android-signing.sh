#!/usr/bin/env bash
# Write android/key.properties and keystore from GitHub Actions secrets.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ANDROID_DIR="$ROOT_DIR/android"

if [[ -z "${ANDROID_KEYSTORE_BASE64:-}" ]]; then
  echo "ANDROID_KEYSTORE_BASE64 not set; APK will be signed with the debug key." >&2
  exit 0
fi

for var in ANDROID_STORE_PASSWORD ANDROID_KEY_PASSWORD ANDROID_KEY_ALIAS; do
  if [[ -z "${!var:-}" ]]; then
    echo "ERROR: $var is required when ANDROID_KEYSTORE_BASE64 is set." >&2
    exit 1
  fi
done

echo "$ANDROID_KEYSTORE_BASE64" | base64 --decode >"$ANDROID_DIR/upload-keystore.jks"

cat >"$ANDROID_DIR/key.properties" <<EOF
storePassword=${ANDROID_STORE_PASSWORD}
keyPassword=${ANDROID_KEY_PASSWORD}
keyAlias=${ANDROID_KEY_ALIAS}
storeFile=upload-keystore.jks
EOF

echo "Release signing configured."
