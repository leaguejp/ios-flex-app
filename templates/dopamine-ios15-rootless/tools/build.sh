#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${THEOS:?Run tools/bootstrap.sh first or select a configured Theos}"
mkdir -p artifacts
python3 tools/validate.py
make clean
make package 2>&1 | tee artifacts/build.log
package_id=$(sed -n 's/^Package: //p' control)
version=$(sed -n 's/^Version: //p' control)
python3 tools/validate.py --deb "packages/${package_id}_${version}_iphoneos-arm64.deb" --report artifacts/package-report.json
