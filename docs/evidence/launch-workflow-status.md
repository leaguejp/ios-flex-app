# Launch/capture/return validation status

Recorded 2026-10-04 JST. Source `7da43d3`; [successful run 37179078049](https://github.com/leaguejp/ios-flex-app/actions/runs/37179078049). Both rootless and RootHide jobs **SUCCESS**, including artifact upload.

- Core, production Objective-C runtime/catalog/hook, protocol/IPC and store tests PASS. Existing Simulator hook/patch/restore integration and offline inventory analysis PASS.
- Rootless XCUITest: **1 test, 0 failures**, 29.667 seconds. The real installed-app row and Analyze action were selected; automatic authenticated Agent connection, catalog transfer/persistence, URL return and fixture instance/class method browsing passed. Independent saved JSON asserts complete status, returned=true, foreground=true and Captured Runtime Loaded title.
- Captured test bundle: **2 images, 38 classes, 264 methods**, no errors, not partial. All runtime method provenance remains Runtime Loaded; static inventory tests independently assert Static Only.
- Both downloaded 0.2.0 debs independently reinspected using `scripts/inspect_deb.py`: PASS. Installed-Size 512; package rootless `iphoneos-arm64`, RootHide `iphoneos-arm64e`; all three actual Mach-O CPUs arm64; ar/debian-binary 2.0, gzip, actual ustar; no libFLEX dependency.
- The prior run failed querying a background app's accessibility tree. The successful revision queries system consent UI, runs on the selected Simulator without parallel cloning, coalesces activation-triggered paste reads and defers reading until the activation callback returns. Multiple changes landed together; an isolated causal attribution is not claimed. No test assertion or method-display acceptance check was removed.
- Xcode warnings about not stripping already-signed Apple XCTest frameworks refer to the Simulator test runner's bundled Apple libraries. They do not refer to package binaries or a missing production signature; no stripping/signing bypass was added.
- Physical iPhone 11/iOS 15.5/Dopamine/RootHide injection, sandbox IPC and return routing remain unverified; the Simulator fixture embeds the Agent rather than using jailbreak injection.

[Rootless package report](launch-rootless-package.json), [RootHide package report](launch-roothide-package.json), [methods screenshot](launch-methods.png).

Commands executed: `bash scripts/test-macos.sh`, `bash scripts/build.sh rootless`, `bash scripts/build.sh roothide`, `bash scripts/preview-simulator.sh`; local `python scripts/inspect_deb.py <deb> --architecture <architecture> --scheme <scheme> --output <report>`.

Reinstall the newly built matching deb, fully quit Atlas and the target app to replace the old Agent, then select the target → Analyze app / return to Atlas. Enable target tweak injection. Methods without Objective-C runtime metadata remain unavailable.

rootless SHA-256: `5e75282eb65fbeaef562731942d847fc6721abb59be7866b9d3345682efe58f1`.

roothide SHA-256: `1d24ccaa62d5b087bb1a7756d9e801f8166f42e3ab551ecceaf3fc6dfb02c4cd`.
