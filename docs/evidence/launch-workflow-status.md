# Launch/capture/return validation status

Recorded 2026-10-04 JST. Latest implementation source: `302227345eb53368e133620148bbb131fd631cbb`.

- Implemented: app-specific expiring launch ticket, automatic authenticated Agent connection, in-process runtime catalog, paged transfer, per-app persistence, return URL, captured image/class/method browser, counts/errors and empty-method diagnostics.
- Fixed after a failed Simulator test: acquire background transfer time before opening the target; observe both application and scene activation. Source changes are **not yet build/runtime validated**.
- Previous source `e758f7cc7f9c717b18c5e10c73f94596d81f40dd`, [run 37166155129](https://github.com/leaguejp/ios-flex-app/actions/runs/37166155129): both 0.2.0 packages compiled and inspected. Host catalog, empty-capture diagnostics, existing hook/protocol/store/core tests PASS. Legacy Simulator integration PASS, but the new launch/capture/return test FAILED: Controller remained waiting for the Agent after switching to background. This does not prove the exact cause on the user's device.
- Latest [run 37167009534](https://github.com/leaguejp/ios-flex-app/actions/runs/37167009534): both jobs were rejected **before any build step ran**. GitHub check annotation: “The job was not started because recent account payments have failed or your spending limit needs to be increased. Please check the 'Billing & plans' section in your settings”. No automatic approval/security review was involved.
- Modern iOS programmatic paste requires user approval according to Apple; whether a paste alert caused the observed timeout has not been established. A standard XCUITest driver now selects the real Analyze UI action, handles Allow Paste/Open system dialogs, waits for URL return and drills into fixture instance/class methods. Driver/project generation is added, but **the UI test has not run**.
- Local Windows checks: four Python package tests PASS; generated UI-test scheme XML and both Info plists parse successfully; Git diff whitespace check PASS. These are not iOS compile or runtime evidence.
- Physical iPhone/Dopamine/RootHide capture, sandbox IPC, injection, paste permissions and return routing remain unverified from this workspace.

The compiled 0.2.0 package reports below refer to the previous source, not the latest foreground-transfer fix. Do not treat those artifacts as validated fixes for the failed workflow. Last fully validated release evidence remains the earlier 0.1.0 run.

| Package check | rootless | RootHide |
|---|---|---|
| Version / Installed-Size | 0.2.0 / 512 | 0.2.0 / 512 |
| Debian architecture | iphoneos-arm64 | iphoneos-arm64e |
| All 3 Mach-O CPUs | arm64 | arm64 |
| ar/compression/tar | debian-binary 2.0, gzip, actual ustar | same |
| Independent downloaded-deb reinspection | PASS | PASS |

[Rootless intermediate report](launch-rootless-package.json), [RootHide intermediate report](launch-roothide-package.json).

After GitHub billing is restored, rerun the latest source's Build and validate workflow (or use a Mac with Xcode):

```sh
brew install ldid
export THEOS="$PWD/.tools/theos-rootless"
bash scripts/bootstrap.sh rootless
bash scripts/test-macos.sh
bash scripts/build.sh rootless
bash scripts/preview-simulator.sh
export THEOS="$PWD/.tools/theos-roothide"
bash scripts/bootstrap.sh roothide
bash scripts/build.sh roothide
```

Install only the matching newly validated deb, fully quit Atlas and the target app to replace an already-loaded old Agent, then select the target → Analyze app / return to Atlas. The new workflow requires target tweak injection; it cannot analyze Swift-only/native methods that have no Objective-C metadata.
