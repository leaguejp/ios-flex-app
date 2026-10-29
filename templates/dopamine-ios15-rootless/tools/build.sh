#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${THEOS:?Run tools/bootstrap.sh first or select a configured Theos}"
mkdir -p artifacts
python3 tools/validate.py
make clean
make package 2>&1 | tee artifacts/build.log
python3 tools/validate.py --deb packages/com.example.dopaminetemplate_0.1.0_iphoneos-arm64.deb --report artifacts/package-report.json
