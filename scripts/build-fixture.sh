#!/usr/bin/env bash
# Normal sandboxed fixture, embeds Agent for development/simulator; no tweak injection required.
set -euo pipefail
sdk=${1:-iphonesimulator}
case "$sdk" in
 iphonesimulator) arch=$(uname -m);target="$arch-apple-ios15.0-simulator" ;;
 iphoneos) arch=arm64;target=arm64-apple-ios15.0 ;;
 *) exit 2 ;;
esac
dest="build/fixture-$sdk";mkdir -p "$dest/AtlasTestTarget.app"
app="$dest/AtlasTestTarget.app"
sysroot=$(xcrun --sdk "$sdk" --show-sdk-path)
common=(-target "$target" -isysroot "$sysroot" -fblocks -Wall -Wextra -Werror)
if [[ "$sdk" == iphonesimulator && "${LX_FIXTURE_AUTOMATION:-0}" == 1 ]]; then common+=(-DLX_FIXTURE_AUTOMATION=1);fi
xcrun --sdk "$sdk" clang "${common[@]}" -fno-objc-arc -c hook/LXHookEngine.m -o "$dest/hook.o"
xcrun --sdk "$sdk" clang "${common[@]}" -std=c11 -c core/encoding.c -o "$dest/encoding.o"
xcrun --sdk "$sdk" clang "${common[@]}" -std=c11 -c core/macho.c -o "$dest/macho.o"
xcrun --sdk "$sdk" clang "${common[@]}" -fobjc-arc testtarget/App.m testtarget/LXFixture.m agent/LXAgent.m runtime/LXScanner.m static/LXStaticAnalyzer.m shared/LXTypes.m shared/LXChannel.m shared/LXProtocol.m "$dest/hook.o" "$dest/encoding.o" "$dest/macho.o" -framework UIKit -framework Foundation -o "$app/AtlasTestTarget"
cp testtarget/Resources/* "$app/"
if [[ "$sdk" == iphoneos ]]; then
 : "${FIXTURE_PROFILE:?Path to development provisioning profile (keep outside Git)}"
 : "${FIXTURE_SIGNING_IDENTITY:?Local development code signing identity}"
 : "${FIXTURE_ENTITLEMENTS:?Path to ordinary application entitlements matching profile, without private sandbox/IPC exceptions}"
 cp "$FIXTURE_PROFILE" "$app/embedded.mobileprovision"
 codesign --force --sign "$FIXTURE_SIGNING_IDENTITY" --entitlements "$FIXTURE_ENTITLEMENTS" "$app"
 mkdir -p "$dest/Payload";cp -R "$app" "$dest/Payload/"
 (cd "$dest" && zip -qr AtlasTestTarget.ipa Payload)
else
 codesign --force --sign - "$app"
fi
echo "$app"
