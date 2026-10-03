#!/usr/bin/env bash
set -euo pipefail
scheme=${1:?usage: bootstrap.sh rootless|roothide}
: "${THEOS:?Set THEOS to an empty output directory}"
case "$scheme" in
 rootless) repo=https://github.com/theos/theos.git;rev=dd5c14bb9d91311e221d51b5bfb8c9e5948156db ;;
 roothide) repo=https://github.com/roothide/theos.git;rev=88506b2c22e9e07dd4ed055f23c9e398a117a2c7 ;;
 *) exit 2 ;;
esac
git clone "$repo" "$THEOS"
git -C "$THEOS" checkout "$rev"
git -C "$THEOS" submodule update --init --recursive
# Use the runner's official Xcode SDK, never a downloaded proprietary SDK archive.
sdk=$(xcrun --sdk iphoneos --show-sdk-path)
ln -s "$sdk" "$THEOS/sdks/$(basename "$sdk")"
git -C "$THEOS" rev-parse HEAD
