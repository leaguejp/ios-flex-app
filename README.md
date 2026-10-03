# Runtime Atlas

Independent Theos Controller application + lightweight injected Agent for authorized Objective-C inspection. Unique IDs: package `jp.league.runtimeatlas`, Controller `jp.league.runtimeatlas.controller`, fixture `jp.league.runtimeatlas.fixture`. No FLEX/libFLEX code or link dependency. Target: iPhone 11, iOS 15.5, Dopamine; RootHide has a separate build path.

**Status:** implemented MVP; rootless/RootHide builds, actual deb inspection, host tests and real Agent/Controller integration in iOS Simulator passed. Evidence is in [docs/validation.md](docs/validation.md). Physical iOS sandbox IPC and jailbreak installation must pass the device gate before claiming device readiness. No connected iPhone or development provisioning is available in this environment. Arbitrary-app hooks remain unavailable until their declarations are reviewed; see the support matrix.

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

GitHub Actions runs both schemes, production Objective-C host tests, sanitizers, deb inspection, native Simulator integration and artifact upload. Theos revisions are pinned in `scripts/bootstrap.sh`; submodules inherit fixed revisions. Official runner Xcode SDK is used. Runner image/version and software manifest are recorded in CI setup logs; reproducing bit-identical binaries also requires the same Xcode. Mach-O code is arm64; **Debian** architectures differ: rootless `iphoneos-arm64`, RootHide `iphoneos-arm64e`.

Install the matching artifact via Sileo/Zebra or `dpkg -i` in the appropriate jailbreak shell. Enable TestTarget/application injection in your jailbreak manager, then relaunch the target. The package's maintainer script resolves `uicache` from the active bootstrap PATH and refreshes icons; if unavailable, run the jailbreak's `uicache -a` manually. Controller and Atlas TestTarget appear on the home screen. Do not install the RootHide package into ordinary Dopamine. Only one variant should be installed at a time.

## Use

1. Open Runtime Atlas and select an installed application. **Enable analysis / open app** copies a fresh internal pairing key and opens the target when LaunchServices permits it. Inventory failure falls back to connected Agents.
2. Open the owned/authorized target. Tap three times with three fingers, confirm the prefilled pairing key and pair (paste manually if clipboard access is unavailable). TestTarget also has an explicit Pair button.
3. Return promptly to Controller. Select the same application; PID/executable/Agent status are under **Connection details**. Choose **Activate Agent**.
4. Search **Runtime Loaded images → class → method**. Both instance/metaclass methods show selector, raw encoding, parsed types and unsupported reason. Search applies at each image/class/method level.
5. In TestTarget select `LXFixture`, enable a reviewed hook, return to TestTarget and call methods, then inspect **Logs** in Controller. Disable hook and repeat to verify original behavior.
6. **Static Only bundle** scans the target's own bundle/embedded Mach-O files through Agent. Static string pools are partial evidence, not runtime classes. Inspect errors/limitations in saved history.
7. **Export JSON** fetches logs and hook state, saves per-bundle settings/history, and opens the system share sheet. Logging-only hooks require explicit activation. Saved value patches can restore only with the per-app launch policy described below.

Controller's ordinary background task provides a short OS-controlled grace period. It is **not an always-running broker**. Suspension or loss of connection disables interactive hooks; explicitly authorized launch patches may continue; pair again when necessary. Long background capture needs a separately validated broker and is outside this MVP. Installed applications form the selection list; unpaired apps show Agent Offline. Connection identity is diagnostic detail. SpringBoard, Apple applications and daemons are excluded.

## Hook signature support matrix

Encoding alone cannot identify variadic methods, object ownership or all ABI contracts. Hook support uses reviewed declarations in `testtarget/LXFixture.h` restricted to the fixture bundle, plus four system UIKit declarations available in other paired apps. Exact classes and system image origin are checked; arbitrary overrides remain unsupported. Other apps remain fully browsable; extending hook support requires reviewing their declarations, ownership and ABI, then updating the compiled manifest and typed wrappers. A class with a similar name in another bundle is rejected.

| Declaration | arm64 shape (offsets omitted) | Supported |
|---|---|---|
| `- (void)ping` | `v@:` | Yes |
| `- (id)echo:(id)value` (+0, not method family) | `@@:@` | Yes |
| `- (long long)addOne:(long long)value` | `q@:q` | Yes |
| `- (BOOL)invert:(BOOL)value` | `B@:B` | Yes |
| `- (float)scale:(float)value` | `f@:f` | Yes |
| `- (double)doubleValue:(double)value` | `d@:d` | Yes |
| `+ (long long)classValue` | `q@:` | Yes, metaclass |
| `UIView -setHidden:(BOOL)` | `v@:B` | Yes, system UIKit class |
| `UIView -setAlpha:(CGFloat)` | `v@:d` | Yes, system UIKit class |
| `UIViewController -viewWillAppear:(BOOL)` | `v@:B` | Yes, system UIKit class |
| `UIViewController -viewDidAppear:(BOOL)` | `v@:B` | Yes, system UIKit class |
| Struct/union/array/vector/pointer/block argument, variadic, method family, unknown or unreviewed declaration | any | No, reason shown |

Parser recognizes objects, blocks, Class, SEL, pointers, integer/BOOL/float/double, arrays, structs, unions, qualifiers and bitfields. Recognized does not mean hookable. No remote injection/task_for_pid, arbitrary signature cast, object `description` logging or private IPC entitlement. Original exceptions propagate. Logs contain pointer/class identity for objects, finite scalar values, wall time, thread ID, selector, encoding and monotonic duration; bounded at 1000 events / 1 MiB.

## Limitations

Static parser supports 64-bit thin/fat files, load commands, CPU, UUID, dependencies, encryption errors and Objective-C string pools. It does not resolve class/method associations, chained fixups, Swift metadata, encrypted images or 32-bit images. Known uninterpreted commands are retained as metadata; unknown/future command IDs return structured errors. The runtime remains authoritative for loaded information. No static evidence can enable hooks.

Third-party IMP conflicts are detected and not blindly overwritten; Objective-C runtime exposes no public atomic IMP compare-and-swap. Concurrent external mutation is a documented limit. Retired trampolines remain alive for in-flight/third-party chains, bounded to 256 generations per process. Hook history is per bundle; live state is only Agent's state, never assumed from persisted settings.

See [architecture](docs/architecture.md), [IPC feasibility](docs/ipc-feasibility.md), [validation](docs/validation.md), and [device procedure](docs/device-validation.md).

## App selection and value patches

The Home Screen app now starts with an installed third-party application list (name/bundle ID/Agent state). LaunchServices is an optional private API invoked only after runtime method-signature checks, without private entitlements. Missing API, errors, denied inventory or denied launch retain the paired-Agent/manual-launch path. Device availability is not established by Simulator results. Connected process identity remains diagnostic detail rather than the selection model.

Reviewed UIKit instance methods: `UIView -setHidden:(BOOL)`, `UIView -setAlpha:(CGFloat)` (arm64 double), `UIViewController -viewWillAppear:(BOOL)` and `-viewDidAppear:(BOOL)`. Their signature declarations are compiler-checked against the selected SDK. UIKit wrappers can be enabled in any paired eligible app; they affect the exact system method, not subclass overrides that bypass it.

Method details offer **Create / apply scalar patch**. Supported numeric argument/return fields accept finite BOOL (0/1), signed 64-bit integers, float and double. Argument replacement occurs before calling the saved original; return replacement occurs only after the original returns normally. Exceptions propagate. Void/object fields cannot be replaced. Empty fields preserve values; both empty fields clear the value patch and retain logging. Disabling the hook removes the effect. Patches are saved per bundle and available under **Saved patches**, where explicit selection reapplies the reviewed hook and patch after reconnection. Choose **Enable saved patches on launch** to authorize this app to restore its saved value patches at subsequent launches. They are stored in the target app's own namespaced preferences, so no Controller connection is needed for restoration. With this explicit policy enabled, saved value patches survive IPC disconnect; transient logging-only hooks still end on disconnect. **Disable saved patches on launch** prevents future restoration; disable the hook or deactivate Agent to stop the current effect. Deactivate also revokes the launch policy. Default policy is off. Static class-to-method reconstruction and offline arbitrary-method patch creation remain incomplete.

Pairing authentication remains internal HMAC rather than being removed. Clipboard transfer is a user-directed one-time pairing aid, not silent access to other apps. On iOS versions with clipboard access prompts, manual paste may be necessary. A persistent trusted broker / automatic lifecycle needs real-device IPC validation before adoption.

**Analyze installed bundle** performs bounded static analysis from the installed-app menu without starting the app or connecting an Agent, using the bundle URL returned by LaunchServices. Filesystem denial returns diagnostics and the Agent-side bundle analysis remains available. This shows Mach-O/load-command/Objective-C string-pool information marked Static Only; it does not claim complete class/method reconstruction.

**Runtime Generated classes** is a virtual browser group for registered classes without a Mach-O image. It has no fabricated header/file path in the runtime model. Image add/remove events invalidate caches. Logging also supports plain pthread callers without an existing autorelease pool; the original implementation remains outside the logger's pool.

### Offline app analysis and patch authoring

Select an installed app → **Analyze installed bundle** → image → class → method → **Create / save scalar patch**. This works without a running target or pairing token. Partial arm64 class/metaclass relationships are decoded from classic pointers, relative method lists and supported dyld 64-bit chains. Every static result remains **Static Only**; metadata cannot establish that a class is currently loaded.

Only reviewed declarations are patchable: the fixture's scalar methods support offline authoring; arbitrary third-party methods remain browse-only with an unsupported reason. Existing UIKit reviewed profiles can be edited through runtime browsing. Use **Saved patches / settings** to edit offline definitions. After connecting and activating the target Agent, use **Saved patches → Apply patch**; the Agent rejects changed method encodings. Enable **saved patches on launch** after transfer to restore on later launches. Unsupported authenticated chains/categories/encrypted files produce diagnostics; this is not a complete Flex 3 replacement.
