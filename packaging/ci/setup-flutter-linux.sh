#!/usr/bin/env bash
# Install Flutter on Linux (works on x64 and arm64; no prebuilt arm64 SDK tarball required).
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-stable}"
FLUTTER_HOME="${FLUTTER_HOME:-/opt/flutter}"

if [[ -x "$FLUTTER_HOME/bin/flutter" ]]; then
  echo "Reusing Flutter at $FLUTTER_HOME"
else
  echo "Installing Flutter ${FLUTTER_VERSION} into ${FLUTTER_HOME}"
  sudo mkdir -p "$(dirname "$FLUTTER_HOME")"
  if [[ "$FLUTTER_VERSION" == "stable" || "$FLUTTER_VERSION" == "beta" || "$FLUTTER_VERSION" == "master" ]]; then
    sudo git clone --depth 1 --branch "$FLUTTER_VERSION" \
      https://github.com/flutter/flutter.git "$FLUTTER_HOME"
  else
    sudo git clone https://github.com/flutter/flutter.git "$FLUTTER_HOME"
    sudo git -C "$FLUTTER_HOME" fetch --depth 1 origin "refs/tags/${FLUTTER_VERSION}"
    sudo git -C "$FLUTTER_HOME" checkout "$FLUTTER_VERSION"
  fi
  sudo chown -R "$(id -u):$(id -g)" "$FLUTTER_HOME"
fi

echo "$FLUTTER_HOME/bin" >>"${GITHUB_PATH:?GITHUB_PATH must be set}"

flutter config --no-analytics
flutter precache --linux
flutter --version
