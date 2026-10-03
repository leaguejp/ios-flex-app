#!/usr/bin/env bash
set -euo pipefail
mkdir -p artifacts/simulator build/controller-simulator/RuntimeAtlas.app
udid=$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin); print(next(x["udid"] for xs in d["devices"].values() for x in xs if "iPhone" in x["name"]))')
xcrun simctl boot "$udid"
xcrun simctl bootstatus "$udid" -b
LX_FIXTURE_AUTOMATION=1 bash scripts/build-fixture.sh iphonesimulator
sdk=$(xcrun --sdk iphonesimulator --show-sdk-path)
arch=$(uname -m)
app=build/controller-simulator/RuntimeAtlas.app
xcrun --sdk iphonesimulator clang -target "$arch-apple-ios15.0-simulator" -isysroot "$sdk" -std=c11 -Wall -Wextra -Werror -c core/macho.c -o build/controller-simulator/macho.o
xcrun --sdk iphonesimulator clang -target "$arch-apple-ios15.0-simulator" -isysroot "$sdk" -fobjc-arc -fblocks -DLX_CONTROLLER_AUTOMATION=1 -Wall -Wextra -Werror controller/App.m controller/LXApplications.m controller/LXController.m controller/LXStore.m static/LXStaticAnalyzer.m build/controller-simulator/macho.o ui/LXBrowser.m shared/LXProtocol.m shared/LXChannel.m shared/LXAuth.m -framework UIKit -framework Foundation -o "$app/RuntimeAtlas"
cp controller/Resources/* "$app/"
codesign --force --sign - "$app"
xcrun simctl install "$udid" "$app"
xcrun simctl install "$udid" build/fixture-iphonesimulator/AtlasTestTarget.app
clang -fobjc-arc -fblocks -Wall -Wextra -Werror tests/simulator_integration.m controller/LXController.m controller/LXStore.m shared/LXChannel.m shared/LXProtocol.m shared/LXAuth.m -framework Foundation -o build/simulator-integration
LX_SIMULATOR_UDID="$udid" build/simulator-integration | tee artifacts/simulator/integration.txt
xcrun simctl terminate "$udid" jp.league.runtimeatlas.fixture
# Same source, distinct application bundle: verifies UIKit support is not fixture-gated.
cp -R build/fixture-iphonesimulator/AtlasTestTarget.app build/fixture-iphonesimulator/AtlasSecondary.app
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier jp.league.runtimeatlas.fixture.secondary' build/fixture-iphonesimulator/AtlasSecondary.app/Info.plist
codesign --force --sign - build/fixture-iphonesimulator/AtlasSecondary.app
xcrun simctl install "$udid" build/fixture-iphonesimulator/AtlasSecondary.app
LX_SIMULATOR_UDID="$udid" LX_FIXTURE_BUNDLE=jp.league.runtimeatlas.fixture.secondary build/simulator-integration | tee artifacts/simulator/secondary-integration.txt
xcrun simctl terminate "$udid" jp.league.runtimeatlas.fixture.secondary
xcrun simctl launch "$udid" jp.league.runtimeatlas.controller --lx-test-inventory
sleep 3
container=$(xcrun simctl get_app_container "$udid" jp.league.runtimeatlas.controller data)
cp "$container/Documents/inventory-test.json" artifacts/simulator/inventory-test.json
python3 - <<'PY'
import json
with open('artifacts/simulator/inventory-test.json') as stream: result=json.load(stream)
assert any(app['bundle']=='jp.league.runtimeatlas.fixture' for app in result['applications']), result
assert result['static']['images'], result
assert all(image['provenance']=='Static Only' for image in result['static']['images'])
print('Controller inventory / offline bundle analysis PASS: installed fixture selected without an Agent connection')
PY
xcrun simctl io "$udid" screenshot artifacts/simulator/controller.png
xcrun simctl launch "$udid" jp.league.runtimeatlas.fixture
sleep 3
xcrun simctl io "$udid" screenshot artifacts/simulator/fixture.png
xcrun simctl shutdown "$udid"
