# Validation record

Recorded 2026-10-04 JST. Build source revision: `7681af70cd14633a8cb48ae1d01d9ecf65dd3b41`. [Latest source build run 37181607547](https://github.com/leaguejp/ios-flex-app/actions/runs/37181607547): **both complete jobs SUCCESS**. Documentation-only follow-up does not change tested binaries.

## Latest 0.2.3 workflow status: SUCCESS

The revised local capture / authenticated foreground return / persistence UI workflow passed: 37 classes, 262 methods, real Analyze action, URL return and instance/class method display. Store failure diagnostics, returned catalog validation and actual package entitlement checks passed. See [detailed evidence](evidence/launch-workflow-status.md) and [beta56 design audit](flex56-comparison.md). Physical-device causes and deployment behavior remain unverified.

## Environment and commands

Windows PowerShell/Python 3.12.9 workspace and GitHub remote were empty; main initialized. WSL Ubuntu cannot start (`HCS_E_SERVICE_NOT_AVAILABLE`); no local clang/iOS SDK. Present-device query found no iPhone/Apple Mobile device and no idevice/iproxy tools. No remote device endpoint or provisioning was configured. macOS CI performed executable Objective-C tests and iOS build.

CI runner: `macos-15-arm64`, image `20260907.0337.1`; [runner software manifest](https://github.com/actions/runner-images/blob/macos-15-arm64/20260907.0337/images/macos/macos-15-arm64-Readme.md). Official Xcode iPhoneOS SDK via xcrun; minimum deployment target 15.0. Theos rootless revision `dd5c14bb9d91311e221d51b5bfb8c9e5948156db`, RootHide revision `88506b2c22e9e07dd4ed055f23c9e398a117a2c7`, fixed submodule revisions. No proprietary SDK download, signing key or certificate committed.

```sh
python -m unittest discover -s tests -p 'test_*.py' -v
bash scripts/bootstrap.sh rootless   # scheme-specific THEOS
bash scripts/bootstrap.sh roothide  # separate THEOS checkout
bash scripts/test-macos.sh
bash scripts/build.sh rootless
bash scripts/build.sh roothide
bash scripts/preview-simulator.sh   # embedded-fixture Agent + real Controller backend
```

## Results and scope

| Check | Result / evidence |
|---|---|
| Portable encoding parser | PASS: objects/quoted class, block, BOOL, nested pointer/struct/union/array, malformed input and capacity rejection |
| Mach-O bounds/sanitizers | PASS: ASan+UBSan, truncated header/load command, UUID, encryption rejection, unknown-command structured error, 20,000 deterministic malformed inputs |
| Production runtime scanner on host | PASS: loaded dyld images, fixture image classes, instance/class method selector/encoding |
| Production static analyzer | PASS: analyzes built Mach-O files, scalar Static Only provenance retained; collision bug found by test and corrected |
| Production hook engine + LXFixture | PASS: scalar argument/return replacement, BOOL rejection, fractional/out-of-range integer rejection, nonfinite float rejection, object rejection, exact LLONG_MAX return, original exception propagation under a return patch, clearing/disable, all seven typed wrappers, original results/object identity, argument/return/time/thread/type logs, duplicate enable, disable/IMP equality, no new logs after disable, struct/variadic/unreviewed rejection |
| Exceptions / floating edge cases / concurrency | PASS: original exception propagated and logged with null return; NaN/Infinity safely serialized; concurrent calls and 1000-event/1 MiB bound; foreign IMP conflict left intact |
| Protocol / authentication / host IPC | PASS: production framed JSON between separate processes, old version/malformed envelope/namespace rejection, HMAC purpose separation/wrong-key proof rejection; full mutual nonce handshake exercised by Simulator |
| Python package-verifier tests | 4 PASS: actual ustar, GNU rejection, malformed ar, unsigned/wrong-CPU rejection |
| Actual Agent ↔ Controller on iOS Simulator | PASS: scalar patches and process termination/relaunch restoring the saved patch without reissuing activate/hookEnable/patchApply, paired session/PID/bundle, round-trip nonce, activate, runtime image/class/method queries, seven hook enables, fixture originals/logs, hook disable and unchanged behavior, static provenance, per-bundle persistence, export with no token, deactivate |
| Second application bundle | PASS: four SDK-reviewed UIKit profiles, BOOL/CGFloat argument patches, originals/logs/disable, fixture declaration rejection outside its bundle |
| Controller offline inventory/static scan | PASS: installed fixture selected while Agent Offline; direct bundle scan produced Static Only image data |
| UIKit applications | Simulator installation/launch and screenshots PASS; Controller installed-app inventory and fixture screens visually inspected. Interactive drill-down/gestures on physical device remain unverified |
| Both Theos packages | PASS: compile, link, strip/sign, actual deb/ar/compression/tar/control/dependencies inspection; downloaded artifacts independently re-inspected on Windows |

Production C/Objective-C compilation uses `-Wall -Wextra -Werror`. Initial weak-reference compile error was fixed. Static provenance key collision was discovered by expanded production-analyzer test and fixed. Initial package had lzma despite an incorrectly named setting; the correct `THEOS_PLATFORM_DEB_COMPRESSION_TYPE=gzip` produces verified gzip. Pinned Theos added obsolete `-multiply_defined suppress`; source was inspected and only that obsolete option removed, preserving duplicate-symbol errors. Final build logs have no ABI/signing/link/rpath/architecture compiler/linker warnings. Node deprecation notices from GitHub artifact action are not binary-build diagnostics.

Simulator automation entry points (`--lx-test-token`, `fixtureRun`, `fixtureUIKitRun`) are compiled only with `LX_FIXTURE_AUTOMATION` for the embedded Simulator fixture. They are absent from production deb source compilation. Controller inventory/static evidence uses `LX_CONTROLLER_AUTOMATION`, also absent from production builds. Simulator evidence is **not proof of a real iOS app sandbox, ElleKit injection, jailbreak signing acceptance or RootHide installation**.

## Actual deb metadata

| Field | Dopamine rootless | RootHide |
|---|---|---|
| Package | `jp.league.runtimeatlas` | `jp.league.runtimeatlas` |
| Version | `0.2.3` | `0.2.3` |
| Debian architecture | `iphoneos-arm64` | `iphoneos-arm64e` |
| Mach-O CPU (Controller, fixture, Agent) | arm64 | arm64 |
| ar members | debian-binary, control.tar.gz, data.tar.gz | same |
| debian-binary bytes | `2.0\n` | same |
| Compression | gzip, verified from actual bytes | gzip, verified from actual bytes |
| Tar | every header POSIX ustar; no GNU/PAX long headers | same |
| Install layout | Theos rootless prefix | RootHide Applications/Library layout, no fixed rootless prefix |
| Maintainer scripts | executable LF shell scripts, PATH-resolved uicache | same |
| Dependencies | firmware >=15.0, ellekit | same |

[Rootless full package report](evidence/rootless-package.json) and [RootHide full package report](evidence/roothide-package.json) include each binary's dependencies, rpaths, CPU and code-signature command. Link dependencies are Apple system libraries/frameworks; no FLEX/libFLEX or unrelated dynamic parser library. Rootless rpaths are generated by Theos, not literal source filesystem paths. RootHide binaries do not require fixed `/var/jb` rpaths.

Artifacts from tested source:

- rootless: `jp.league.runtimeatlas_0.2.3_iphoneos-arm64.deb`, SHA256 `19a3f802b0dea85b3e69c6e19e6a3ab55acc46c75cb2052f24f177e2f107b908`, artifact ID 11294649329.
- RootHide: `jp.league.runtimeatlas_0.2.3_iphoneos-arm64e.deb`, SHA256 `810bc38fdc96ffcfb80e1ff9045da5db1110f2dc820967186e2ffd039658b434`, artifact ID 11295855187.

Both contain build/package reports and host tests; rootless also contains Simulator evidence. Raw Simulator JSON with local paths and request IDs is not committed. Actual XML signing keys are recorded in the reports; enforcement on a device is still a separate gate.

Independent local reinspection:

```sh
python scripts/inspect_deb.py artifacts/foreground-final-rootless/rootless/jp.league.runtimeatlas_0.2.3_iphoneos-arm64.deb --architecture iphoneos-arm64 --scheme rootless --output artifacts/foreground-final-rootless/rootless/local-package-report.json
python scripts/inspect_deb.py artifacts/foreground-final-roothide/roothide/jp.league.runtimeatlas_0.2.3_iphoneos-arm64e.deb --architecture iphoneos-arm64e --scheme roothide --output artifacts/foreground-final-roothide/roothide/local-package-report.json
# Both PASS; architecture and package identity confirmed.
```

## Unmet / unverified acceptance conditions

The complete physical-device acceptance conditions are **not yet satisfied**. No evidence is claimed for:

- Sandbox IPC feasibility on a development-signed physical fixture, before production activation, on either jailbreak. Build path/procedure is supplied in ipc-feasibility.md; no provisioning or device was available.
- iPhone 11/iOS 15.5 Dopamine or RootHide injection, on-device PAC/ABI execution, signing acceptance, home-screen registration, background timeout/grace scheduling, installed-app inventory/launch, clipboard pairing, saved launch-patch persistence under jailbreak preference redirection, and installation in actual old dpkg.
- Arbitrary owned-app hook declarations: initial supported hooks comprise seven fixture-only declarations and four exact system UIKit declarations. Other applications are browsable; adding hooks requires reviewed nonvariadic/ownership declarations plus compiled exact wrappers.
- Complete static Objective-C metadata reconstruction: categories, bound external references, arm64e authenticated chain formats, multiple-start pages and Swift-only metadata remain unsupported. Decoded classlist/metaclass methods and PTR_64/PTR_64_OFFSET chains are explicitly Static Only.
- Atomic synchronization with independently racing third-party IMP writers; public runtime has no atomic compare-and-swap. Conflicts are detected and conditional restoration attempted, with retained trampolines for in-flight chains.

Offline arbitrary-method patch creation from fully reconstructed class/method metadata is not implemented. Value patching is limited to supported numeric fields of reviewed declarations.

Reproduce the physical tests in [device-validation.md](device-validation.md), record separate rootless and RootHide evidence, and only then claim device readiness.

## Changes verified in this revision

The application-first UI selects installed apps, opens them where LaunchServices permits, and shows process information under Connection details. Pairing keys are prefilled from a user-directed clipboard transfer; manual pairing is a fallback. Static bundle analysis and saved JSON export are available without Agent connection. Interactive value patches replace the supported scalar argument before delegating and may replace the successful return afterward. Explicit per-app launch authorization stores profiles in the host app's own namespaced preferences and restores them after process restart; default off, deactivate revokes it.

Actual final logs contain no compiler `warning:` / `error:`. An intermediate test compile exposed Objective-C dictionary commas inside the assert macro; parentheses corrected it, and the final tests pass. Generated package reports were independently regenerated from downloaded deb bytes on Windows. Core sanitizer tests, production Objective-C tests and Python package tests passed on both CI jobs; four Python package tests also passed locally. Screenshot review confirms the installed-app rows and Refresh action are readable. Interactive UI navigation, launch gesture and clipboard prompts on physical hardware remain unverified.

## Acceptance audit corrections

Host tests additionally PASS for syntactically valid but malformed persisted JSON, capped file reads, malformed Controller response bodies, incorrect provenance and nonadvancing pagination. Fractional protocol version/PID is rejected. Static invalid UTF-8 metadata yields an `invalid_utf8` error while preserving partial valid metadata. These cover concrete exception paths found during source audit.

Logging-only autorelease pools surround temporary log allocations, not the original implementation. Owned scalar-patch snapshots release on normal and exceptional exits; cached encoding descriptions and 256-byte object class-name limits reduce allocation volume. A bare pthread repeatedly calls the real hook with `OBJC_DEBUG_MISSING_POOLS=YES`; PASS with no missing-pool warnings. Image cache invalidation after loading/unloading a permitted C-only test dylib PASS. A dynamically registered image-less class is enumerated via objc_copyClassList under a virtual class group, not fabricated Mach-O information.

UIKit presenter check PASS: actual fixture App Delegate window lookup and pairing gesture registration. The current Simulator creates one connected Scene even without a scene manifest; an initial test incorrectly assumed zero and was corrected. The legacy window helper is checked independently, but actual Scene-free iOS 15.5 interaction remains unverified.

The hardware blocker was rechecked: Windows present-device inventory contains no iPhone/Apple Mobile device, and no SSH endpoint/configuration or development provisioning is provided. [Acceptance audit](acceptance-audit.md) distinguishes source/host/Simulator/package evidence from outstanding physical gates.

## App-first offline patch implementation validation (2026-10-04)

Both final matrix jobs succeeded for the source revision above. Executed `scripts/test-macos.sh`, each scheme's `scripts/build.sh`, and rootless `scripts/preview-simulator.sh`. ASan/UBSan tests PASS for classic class/metaclass pointers, small relative method lists, PTR_64_OFFSET chains, unsupported pointer formats, bound class references, malformed ranges, real thin arm64 fat selection and nested fat rejection. Host Store tests PASS for offline save/reload/export, scalar range rejection and unsupported bundle/method refusal.

Actual embedded Agent/Controller Simulator integration PASS: a Static Only `LXFixture/addOne:` record is saved as a per-app patch, stale encoding is rejected before hook installation, then the saved definition applies and changes values while the original still runs. Existing disable/original/log/launch-restoration tests PASS. Installed-app inventory selects the fixture with no Agent connection and independently decodes its instance/class methods and unsupported reasons. Interactive UIKit navigation itself is compile-checked, but not automated through touch gestures.

Final compiler/linker logs contain no `warning:` or `error:`. Four package-verifier tests also PASS locally on Windows. Downloaded final artifacts are independently checked with:

```sh
python scripts/inspect_deb.py <rootless.deb> --architecture iphoneos-arm64 --scheme rootless --output rootless-report.json
python scripts/inspect_deb.py <roothide.deb> --architecture iphoneos-arm64e --scheme roothide --output roothide-report.json
```

Both packages are version 0.1.0, Installed-Size 444, actual gzip/ustar, three arm64 Mach-Os, expected scheme-specific Debian architectures and Apple system dependencies without libFLEX. Updated full reports and compact test transcripts are in `docs/evidence`. GitHub artifact IDs: rootless 11286956521; RootHide 11286986240. Physical iPhone sandbox feasibility, tweak injection, clipboard pairing and RootHide operation remain unverified. Arbitrary unreviewed application methods remain browse-only; this implementation adds offline authoring within the reviewed support matrix, not complete Flex 3 compatibility.

Final rootless deb SHA256: `8ae77e06969f8a8217ae5250949c87bf39e773049cc4ca539033f94007be421d`.

Final roothide deb SHA256: `2fa91fcb0948f1c7b637508ba75db6ee5bb952f85ccb001a016d1056b20e91b2`.
