# Runtime Atlas

Independent Theos Controller application + lightweight injected Agent for authorized Objective-C inspection. Unique IDs: package `jp.league.runtimeatlas`, Controller `jp.league.runtimeatlas.controller`, fixture `jp.league.runtimeatlas.fixture`. No FLEX/libFLEX code or link dependency. Target: iPhone 11, iOS 15.5, Dopamine; RootHide has a separate build path.

**Status:** implemented MVP; build and host test results are tracked in [docs/validation.md](docs/validation.md). An iOS sandbox IPC round trip and jailbreak installation must pass the device gate before claiming device readiness. No physical device is connected to the development environment.

## Build

On macOS with Xcode, Python 3, Git and `brew install ldid`:

```sh
export THEOS="$PWD/.tools/theos-rootless"
bash scripts/bootstrap.sh rootless
bash scripts/test-macos.sh
bash scripts/build.sh rootless
# Separate checkout; never reuse a rootless toolchain for RootHide.
export THEOS="$PWD/.tools/theos-roothide"
bash scripts/bootstrap.sh roothide
bash scripts/build.sh roothide
```

GitHub Actions runs both schemes, production Objective-C host tests, sanitizers, deb inspection and artifact upload. Theos revisions are pinned in `scripts/bootstrap.sh`; submodules inherit fixed revisions. Official runner Xcode SDK is used. Xcode version is recorded by CI build log; reproducing bit-identical binaries also requires the same Xcode. Mach-O code is arm64; **Debian** architectures differ: rootless `iphoneos-arm64`, RootHide `iphoneos-arm64e`.

Install the matching artifact via Sileo/Zebra or `dpkg -i` in the appropriate jailbreak shell. Enable TestTarget/application injection in your jailbreak manager, then relaunch the target. The package's maintainer script resolves `uicache` from the active bootstrap PATH and refreshes icons; if unavailable, run the jailbreak's `uicache -a` manually. Controller and Atlas TestTarget appear on the home screen. Do not install the RootHide package into ordinary Dopamine. Only one variant should be installed at a time.

## Use

1. Open Runtime Atlas; choose **Pair**, which copies a fresh 128-bit session token.
2. Open the owned/authorized target. Tap three times with three fingers, paste the token and pair. TestTarget also has an explicit Pair button.
3. Return promptly to Controller. Select the connected process (PID, executable, bundle, Agent status), then **Activate Agent**.
4. Search **Runtime Loaded images → class → method**. Both instance/metaclass methods show selector, raw encoding, parsed types and unsupported reason. Search applies at each image/class/method level.
5. In TestTarget select `LXFixture`, enable a reviewed hook, return to TestTarget and call methods, then inspect **Logs** in Controller. Disable hook and repeat to verify original behavior.
6. **Static Only bundle** scans the target's own bundle/embedded Mach-O files through Agent. Static string pools are partial evidence, not runtime classes. Inspect errors/limitations in saved history.
7. **Export JSON** fetches logs and hook state, saves per-bundle settings/history, and opens the system share sheet. Hook preferences persist but are never automatically reactivated in a new process.

Controller's ordinary background task provides a short OS-controlled grace period. It is **not an always-running broker**. Suspension or loss of connection disables logging/hooks; pair again when necessary. Long background capture needs a separately validated broker and is outside this MVP. Connected Agents form the selectable process list; unpaired processes, SpringBoard, Apple applications and daemons are excluded.

## Hook signature support matrix

Encoding alone cannot identify variadic methods, object ownership or all ABI contracts. Initial hook support is deliberately limited to reviewed declarations in `testtarget/LXFixture.h` in the fixture bundle. Other apps remain fully browsable; extending hook support requires reviewing their declarations, ownership and ABI, then updating the compiled manifest and typed wrappers. A class with a similar name in another bundle is rejected.

| Declaration | arm64 shape (offsets omitted) | Supported |
|---|---|---|
| `- (void)ping` | `v@:` | Yes |
| `- (id)echo:(id)value` (+0, not method family) | `@@:@` | Yes |
| `- (long long)addOne:(long long)value` | `q@:q` | Yes |
| `- (BOOL)invert:(BOOL)value` | `B@:B` | Yes |
| `- (float)scale:(float)value` | `f@:f` | Yes |
| `- (double)doubleValue:(double)value` | `d@:d` | Yes |
| `+ (long long)classValue` | `q@:` | Yes, metaclass |
| Struct/union/array/vector/pointer/block argument, variadic, method family, unknown or unreviewed declaration | any | No, reason shown |

Parser recognizes objects, blocks, Class, SEL, pointers, integer/BOOL/float/double, arrays, structs, unions, qualifiers and bitfields. Recognized does not mean hookable. No remote injection/task_for_pid, arbitrary signature cast, object `description` logging or private IPC entitlement. Original exceptions propagate. Logs contain pointer/class identity for objects, finite scalar values, wall time, thread ID, selector, encoding and monotonic duration; bounded at 1000 events / 1 MiB.

## Limitations

Static parser supports 64-bit thin/fat files, load commands, CPU, UUID, dependencies, encryption errors and Objective-C string pools. It does not resolve class/method associations, chained fixups, Swift metadata, encrypted images or 32-bit images. Unsupported/unknown commands are retained as metadata. The runtime remains authoritative for loaded information. No static evidence can enable hooks.

Third-party IMP conflicts are detected and not blindly overwritten; Objective-C runtime exposes no public atomic IMP compare-and-swap. Concurrent external mutation is a documented limit. Retired trampolines remain alive for in-flight/third-party chains, bounded to 256 generations per process. Hook history is per bundle; live state is only Agent's state, never assumed from persisted settings.

See [architecture](docs/architecture.md), [IPC feasibility](docs/ipc-feasibility.md), [validation](docs/validation.md), and [device procedure](docs/device-validation.md).
