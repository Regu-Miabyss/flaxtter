#!/usr/bin/env bash
# Install native packages required to build and package Flaxtter on Linux.
set -euo pipefail

sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  ca-certificates curl \
  clang cmake ninja-build pkg-config \
  libgtk-3-dev libglib2.0-dev \
  libwebkit2gtk-4.1-dev libsoup-3.0-dev \
  libmpv-dev \
  libsecret-1-dev libjsoncpp-dev libepoxy-dev \
  rpm
