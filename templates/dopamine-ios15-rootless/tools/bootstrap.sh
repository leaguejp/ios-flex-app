#!/usr/bin/env bash
set -euo pipefail
: "${THEOS:?Set THEOS to a new output directory}"
revision=dd5c14bb9d91311e221d51b5bfb8c9e5948156db
git clone https://github.com/theos/theos.git "$THEOS"
git -C "$THEOS" checkout "$revision"
git -C "$THEOS" submodule update --init --recursive
xcodebuild -version
xcrun --sdk iphoneos --show-sdk-version
xcrun --sdk iphoneos clang --version
sdk=$(xcrun --sdk iphoneos --show-sdk-path)
ln -s "$sdk" "$THEOS/sdks/$(basename "$sdk")"
git -C "$THEOS" rev-parse HEAD
