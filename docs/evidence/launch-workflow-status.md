# Launch/capture/return validation status

Recorded 2026-10-04 JST. Version **0.2.3**, source `7681af70cd14633a8cb48ae1d01d9ecf65dd3b41`, [run 37181607547](https://github.com/leaguejp/ios-flex-app/actions/runs/37181607547): **both complete jobs SUCCESS**, including artifact uploads.

Automatic analysis now captures in the selected Agent, returns a dedicated JSON/HMAC pasteboard envelope, then saves while Atlas is foreground. It no longer requires a background Controller socket/page/save exchange. The callback contains only request ID; the result has no authentication key. Version, bundle, request, expiry, HMAC, size, provenance/counts and image/class/method associations are checked. Invalid results preserve prior saved state.

- Core/sanitizer, production runtime/catalog/hook, IPC/proof and store tests PASS. New tests cover nested snapshot associations; result tampering/wrong key/bundle/request/expiry/size; blocked storage path; non-JSON and oversized state; retained previous bytes.
- Rootless UI test: **1 test, 0 failures**, 22.198 seconds. Real installed-app selection and Analyze action → Agent local capture → foreground URL return → save/display → instance/class method browser. Evidence JSON: complete, transport=foregroundResult, returned=true, foreground=true, initial result title=Captured Runtime Loaded.
- Latest capture: **2 images, 37 classes, 262 methods**; errors=0, partial=False. Counts may vary with runtime-generated classes. Fixture `- addOne:` and `+ classValue` shown with encoding; unsupported signatures remain browse-only. Screenshot retained.
- Both downloaded debs independently reinspected: PASS. Version 0.2.3 / Installed-Size 516; rootless Debian architecture iphoneos-arm64, RootHide iphoneos-arm64e; all three actual Mach-O CPUs arm64; ar/debian-binary 2.0, gzip, actual ustar; Apple link dependencies, no libFLEX.
- Actual Controller signature contains exactly no-container=true, no-sandbox=true, container-required=false. Agent/TestTarget have no added XML entitlements. Package inspection checks this deployment configuration; it does not prove physical jailbreak entitlement enforcement.
- Xcode's signed Apple XCTest-framework stripping warnings concern Simulator runner libraries, not the packaged binaries. No warning suppression was introduced.
- **Physical iPhone/Dopamine/RootHide validation remains outstanding.** User reported save failure in a target and timeout in TestTarget on 0.2.0. Those exact device causes cannot be established without the updated detailed error/injection status. No claim is made that the physical symptoms are already reproduced or fixed.

[Flex beta56 reference audit](../flex56-comparison.md) explains the evidence and design correction. IDA could not start due to its license; actual alternative ARM64 disassembly was performed. Reference binaries/derived code are not dependencies or committed files.

Executed: `bash scripts/test-macos.sh`, `bash scripts/build.sh rootless`, `bash scripts/build.sh roothide`, `bash scripts/preview-simulator.sh`; local `python scripts/inspect_deb.py <deb> --architecture <architecture> --scheme <scheme> --output <report>`.

Rootless SHA-256: `19a3f802b0dea85b3e69c6e19e6a3ab55acc46c75cb2052f24f177e2f107b908`.
RootHide SHA-256: `810bc38fdc96ffcfb80e1ff9045da5db1110f2dc820967186e2ffd039658b434`.

Install the matching 0.2.3 deb, fully quit Atlas and the target, relaunch. TestTarget displays Agent loaded/NOT LOADED. Approve normal paste permission if presented. A save failure now includes stage, OS domain/code, storage path and JSON bytes. No prior state file is deleted on failed persistence. Controller deployment/container identity changed; preexisting state in another app container may require export/import rather than appearing at the new Foundation Documents path.
