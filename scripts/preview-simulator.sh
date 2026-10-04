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
xcrun --sdk iphonesimulator clang -target "$arch-apple-ios15.0-simulator" -isysroot "$sdk" -fobjc-arc -fblocks -DLX_CONTROLLER_AUTOMATION=1 -Wall -Wextra -Werror controller/App.m controller/LXApplications.m controller/LXController.m controller/LXStore.m static/LXStaticAnalyzer.m shared/LXTypes.m core/encoding.c build/controller-simulator/macho.o ui/LXBrowser.m shared/LXProtocol.m shared/LXChannel.m shared/LXAuth.m shared/LXLaunch.m -framework UIKit -framework Foundation -o "$app/RuntimeAtlas"
cp controller/Resources/* "$app/"
codesign --force --sign - "$app"
xcrun simctl install "$udid" "$app"
xcrun simctl install "$udid" build/fixture-iphonesimulator/AtlasTestTarget.app
clang -fobjc-arc -fblocks -Wall -Wextra -Werror tests/simulator_integration.m shared/LXTypes.m core/encoding.c controller/LXController.m controller/LXStore.m shared/LXChannel.m shared/LXProtocol.m shared/LXAuth.m shared/LXLaunch.m -framework Foundation -o build/simulator-integration
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
classes=[cls for image in result['static']['images'] for cls in image.get('classes',[])]
fixture=next(cls for cls in classes if cls['name']=='LXFixture')
methods=fixture['methods']
assert any(m['selector']=='addOne:' and m['supported'] and not m['classMethod'] for m in methods), methods
assert any(m['selector']=='classValue' and m['supported'] and m['classMethod'] for m in methods), methods
assert any(not m['supported'] and m['unsupportedReason'] for m in methods), methods
assert all(m['provenance']=='Static Only' and m['requiresRuntimeValidation'] for m in methods)
print('Controller inventory / offline class and method analysis PASS: fixture instance/class signatures and unsupported reasons without an Agent connection')
PY
xcrun simctl io "$udid" screenshot artifacts/simulator/controller.png
xcrun simctl launch "$udid" jp.league.runtimeatlas.fixture
sleep 3
xcrun simctl io "$udid" screenshot artifacts/simulator/fixture.png
# Standard XCUITest selects the real Analyze action and approves modern OS paste prompts.
xcrun simctl terminate "$udid" jp.league.runtimeatlas.controller
python3 scripts/create-ui-test-project.py
xcodebuild -project build/LaunchWorkflow.xcodeproj -scheme AtlasLaunchUITests -destination "id=$udid" -derivedDataPath build/ui-derived -resultBundlePath artifacts/simulator/ui-launch.xcresult test CODE_SIGNING_ALLOWED=NO 2>&1 | tee artifacts/simulator/ui-launch.txt
python3 - "$container/Documents/launch-analysis-test.json" <<'PY'
import json,sys,time,subprocess
from pathlib import Path
file=Path(sys.argv[1]);deadline=time.monotonic()+35
while time.monotonic()<deadline:
    if file.exists():
        result=json.loads(file.read_text())
        Path('artifacts/simulator/launch-analysis-progress.json').write_text(json.dumps(result,indent=2))
        if result['analysis']['status']=='failed': raise AssertionError(result['analysis'])
        if result['returned'] and result['foreground'] and result['visibleTitle']=='Captured Runtime Loaded': break
    time.sleep(.2)
else:
    print('Last launch state:',result.get('analysis') if 'result' in locals() else 'No Controller job evidence')
    raise AssertionError('Launch/capture/return did not complete')
assert result['analysis']['status']=='complete'
assert result['catalog']['metadata']['methodCount']>0
fixture=next(c for i in result['catalog']['images'] for c in i['classes'] if c['name']=='LXFixture')
assert any(m['selector']=='addOne:' and m['encoding'] and not m['classMethod'] for m in fixture['methods'])
assert any(m['selector']=='classValue' and m['classMethod'] for m in fixture['methods'])
assert all(m['provenance']=='Runtime Loaded' for m in fixture['methods'])
print('Launch/capture/return PASS: real Analyze UI action -> selected Agent auto-auth -> runtime instance/class methods persisted -> URL return -> saved results visible; standard OS paste permission interaction, no manual token entry')
PY
cp "$container/Documents/launch-analysis-test.json" artifacts/simulator/launch-analysis-test.json
xcrun simctl io "$udid" screenshot artifacts/simulator/captured-runtime.png
xcrun simctl shutdown "$udid"
