#!/usr/bin/env bash
set -euo pipefail
mkdir -p artifacts/simulator build/controller-simulator/RuntimeAtlas.app
udid=$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin); print(next(x["udid"] for xs in d["devices"].values() for x in xs if "iPhone" in x["name"]))')
xcrun simctl boot "$udid"
xcrun simctl bootstatus "$udid" -b
bash scripts/build-fixture.sh iphonesimulator
sdk=$(xcrun --sdk iphonesimulator --show-sdk-path)
arch=$(uname -m)
app=build/controller-simulator/RuntimeAtlas.app
xcrun --sdk iphonesimulator clang -target "$arch-apple-ios15.0-simulator" -isysroot "$sdk" -fobjc-arc -fblocks -Wall -Wextra -Werror controller/App.m controller/LXController.m controller/LXStore.m ui/LXBrowser.m shared/LXProtocol.m shared/LXChannel.m -framework UIKit -framework Foundation -o "$app/RuntimeAtlas"
cp controller/Resources/* "$app/"
codesign --force --sign - "$app"
xcrun simctl install "$udid" "$app"
xcrun simctl install "$udid" build/fixture-iphonesimulator/AtlasTestTarget.app
xcrun simctl launch "$udid" jp.league.runtimeatlas.controller
sleep 3
xcrun simctl io "$udid" screenshot artifacts/simulator/controller.png
xcrun simctl launch "$udid" jp.league.runtimeatlas.fixture
sleep 3
xcrun simctl io "$udid" screenshot artifacts/simulator/fixture.png
xcrun simctl shutdown "$udid"
