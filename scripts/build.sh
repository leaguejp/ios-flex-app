#!/usr/bin/env bash
set -euo pipefail
scheme=${1:?usage: build.sh rootless|roothide}
case "$scheme" in
 rootless) expected=iphoneos-arm64 ;;
 roothide) expected=iphoneos-arm64e ;;
 *) echo 'Unknown package scheme' >&2;exit 2 ;;
esac
: "${THEOS:?Set THEOS to pinned scheme-specific checkout}"
mkdir -p artifacts/"$scheme"
make clean THEOS_PACKAGE_SCHEME="$scheme"
make package THEOS_PACKAGE_SCHEME="$scheme" ARCHS=arm64 THEOS_PLATFORM_DEB_COMPRESSION_TYPE=gzip 2>&1 | tee artifacts/"$scheme"/build.log
found=0
for package in packages/*"$expected".deb; do
 [[ -f "$package" ]] || continue
 cp "$package" artifacts/"$scheme"/
 python3 scripts/inspect_deb.py "$package" --architecture "$expected" --scheme "$scheme" --output artifacts/"$scheme"/package-report.json
 found=1
done
[[ "$found" == 1 ]]
