# Launch/capture/return validation status

Recorded 2026-10-04 JST. Repository made public at the user's explicit request; standard `macos-15` jobs now execute successfully. The former billing startup blocker is resolved.

- [Run 37177875072](https://github.com/leaguejp/ios-flex-app/actions/runs/37177875072), source `905da29c227da7c2e10ea6eccd792a757335fb78`: both latest 0.2.0 app/Agent packages built; host core/runtime/catalog/hook/IPC/store tests and package inspection passed. RootHide job succeeded. Rootless existing Simulator integration passed, but the new XCUITest driver failed compilation because of an incorrect descendant-query selector.
- Corrected the selector in `f0baaec9ad3627c3791f4109eb3b068f271fbb8e`. [Run 37178118408](https://github.com/leaguejp/ios-flex-app/actions/runs/37178118408): both package builds and host tests passed; RootHide job succeeded; UI runner compiled, launched Atlas, selected the fixture and tapped Analyze. The target-app accessibility query timed out (`Failed to get matching snapshots`). The test failed; the prolonged run was canceled to collect diagnostics. Launch/capture/return is **not verified end to end**. This failure does not establish the exact cause on a physical device.
- Downloaded both packages from run 37177875072 and independently reran `scripts/inspect_deb.py`: PASS. The selector-only follow-up does not change either packaged application.
- Version 0.2.0; Installed-Size 512; Debian rootless architecture `iphoneos-arm64`, RootHide `iphoneos-arm64e`; all three actual Mach-O CPUs `arm64`; ar/debian-binary 2.0, gzip, actual ustar. No libFLEX dependency.
- Physical iPhone/Dopamine/RootHide injection, sandbox IPC, paste permission and return routing remain unverified. An installed deb or successful package build does not prove the cross-app analysis workflow works.

[Rootless package report](launch-rootless-package.json), [RootHide package report](launch-roothide-package.json).

Commands executed in CI: `bash scripts/test-macos.sh`, `bash scripts/build.sh rootless`, `bash scripts/build.sh roothide`, `bash scripts/preview-simulator.sh`. Local downloaded-package checks used `python scripts/inspect_deb.py <deb> --architecture <scheme architecture> --scheme <scheme> --output <report>`.

Install the matching deb, fully quit Atlas and the target app to replace an already-loaded old Agent, then select the target → Analyze app / return to Atlas. Tweak injection must be enabled. Swift-only/native methods without Objective-C metadata remain unavailable.
