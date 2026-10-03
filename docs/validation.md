# Validation record

Recorded 2026-10-04 JST. Build source revision: `c512e8efe4f02eb0a2ca6a3e5e227664b8de421e`. [Final source build run 37136189212](https://github.com/leaguejp/ios-flex-app/actions/runs/37136189212): **both jobs SUCCESS**. Documentation/evidence-only follow-up does not change the tested source.

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
| Production hook engine + LXFixture | PASS: all seven typed wrappers, original results/object identity, argument/return/time/thread/type logs, duplicate enable, disable/IMP equality, no new logs after disable, struct/variadic/unreviewed rejection |
| Exceptions / floating edge cases / concurrency | PASS: original exception propagated and logged with null return; NaN/Infinity safely serialized; concurrent calls and 1000-event/1 MiB bound; foreign IMP conflict left intact |
| Protocol / authentication / host IPC | PASS: production framed JSON between separate processes, old version/malformed envelope/namespace rejection, HMAC purpose separation/wrong-key proof rejection; full mutual nonce handshake exercised by Simulator |
| Python package-verifier tests | 4 PASS: actual ustar, GNU rejection, malformed ar, unsigned/wrong-CPU rejection |
| Actual Agent ↔ Controller on iOS Simulator | PASS: paired session/PID/bundle, round-trip nonce, activate, runtime image/class/method queries, seven hook enables, fixture originals/logs, hook disable and unchanged behavior, static provenance, per-bundle persistence, export with no token, deactivate |
| UIKit applications | Simulator installation/launch and screenshots PASS; Controller empty-state and fixture screens visually inspected. Interactive drill-down/gestures on physical device remain unverified |
| Both Theos packages | PASS: compile, link, strip/sign, actual deb/ar/compression/tar/control/dependencies inspection; downloaded artifacts independently re-inspected on Windows |

Production C/Objective-C compilation uses `-Wall -Wextra -Werror`. Initial weak-reference compile error was fixed. Static provenance key collision was discovered by expanded production-analyzer test and fixed. Initial package had lzma despite an incorrectly named setting; the correct `THEOS_PLATFORM_DEB_COMPRESSION_TYPE=gzip` produces verified gzip. Pinned Theos added obsolete `-multiply_defined suppress`; source was inspected and only that obsolete option removed, preserving duplicate-symbol errors. Final build logs have no ABI/signing/link/rpath/architecture compiler/linker warnings. Node deprecation notices from GitHub artifact action are not binary-build diagnostics.

Simulator automation entry points (`--lx-test-token`, `fixtureRun`) are compiled only with `LX_FIXTURE_AUTOMATION` for the embedded Simulator fixture. They are absent from production deb source compilation. Simulator evidence is **not proof of a real iOS app sandbox, ElleKit injection, jailbreak signing acceptance or RootHide installation**.

## Actual deb metadata

| Field | Dopamine rootless | RootHide |
|---|---|---|
| Package | `jp.league.runtimeatlas` | `jp.league.runtimeatlas` |
| Version | `0.1.0` | `0.1.0` |
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

```text
jp.league.runtimeatlas_0.1.0_iphoneos-arm64.deb
SHA256 b4a0a164f443c20d11157875a776761c76eaa343c4135e21dc654ad7581ea45c

jp.league.runtimeatlas_0.1.0_iphoneos-arm64e.deb
SHA256 b2cd5bc8c8d164ee1eb429c0173fd1c548d6c58c355ff949e639cfe715291144
```

CI artifacts `runtimeatlas-rootless` (ID 11278668746) and `runtimeatlas-roothide` (ID 11278931239) contain deb, build log, package report and host test results; rootless artifact additionally contains Simulator screenshots, integration transcript and JSON export. Generated binaries are artifacts, not committed source. Simulator export contains simulator-local paths, so it was not copied into repository evidence. SHA256 values above refer to downloaded actual deb bytes.

Independent local reinspection:

```sh
python scripts/inspect_deb.py artifacts/verified-rootless/rootless/jp.league.runtimeatlas_0.1.0_iphoneos-arm64.deb --architecture iphoneos-arm64 --scheme rootless --output artifacts/verified-rootless/rootless/local-package-report.json
python scripts/inspect_deb.py artifacts/verified-roothide/roothide/jp.league.runtimeatlas_0.1.0_iphoneos-arm64e.deb --architecture iphoneos-arm64e --scheme roothide --output artifacts/verified-roothide/roothide/local-package-report.json
# Both PASS; architecture and package identity confirmed.
```

## Unmet / unverified acceptance conditions

The complete physical-device acceptance conditions are **not yet satisfied**. No evidence is claimed for:

- Sandbox IPC feasibility on a development-signed physical fixture, before production activation, on either jailbreak. Build path/procedure is supplied in ipc-feasibility.md; no provisioning or device was available.
- iPhone 11/iOS 15.5 Dopamine or RootHide injection, on-device PAC/ABI execution, signing acceptance, home-screen registration, background timeout/grace scheduling and installation in actual old dpkg.
- Arbitrary owned-app hook declarations: initial supported hooks are fixture-only. Other applications are browsable; adding hooks requires reviewed nonvariadic/ownership declarations plus compiled exact wrappers.
- Full static Objective-C class/method relationship reconstruction or modern chained fixups. Partial string pools are explicitly Static Only, with limits/errors.
- Atomic synchronization with independently racing third-party IMP writers; public runtime has no atomic compare-and-swap. Conflicts are detected and conditional restoration attempted, with retained trampolines for in-flight chains.

Reproduce the physical tests in [device-validation.md](device-validation.md), record separate rootless and RootHide evidence, and only then claim device readiness.
