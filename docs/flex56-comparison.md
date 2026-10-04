# Flex 3 beta56 reference audit

Date: 2026-10-04. User-requested audit of [DXcool223 repository](https://dxcool223-repo.github.io/repo/). Retrieved `debs/Flex3beta56_Dopamine.deb`, package `Flex3beta`, version `1:3~Beta56`, architecture `iphoneos-arm64`; SHA-256 `12674ffd6663b8dc7a8306dbfeb8d47d8d377329185d4e2b046b57e9d6311513` matches the repository Packages entry. Downloaded code was not executed on a device. Reference binary/databases/disassembly remain ignored local analysis files, not vendored or distributed.

IDA Professional 9.1 is installed but its headless executable exited with “Cannot continue without a valid license”. No license workaround was attempted. Fallback analysis used LIEF 0.17.0 to read the arm64 Mach-O slice/symbols/sections/bindings and Capstone 5.0.6 for actual ARM64 disassembly. This is **not Hex-Rays decompilation**. C/Objective-C-like behavior below is inferred from instructions, resolved selectors/imports and control flow; no reference implementation is copied.

## Observed functions in arm64 Flex.dylib

| Function / address | Observed calls or data | Implication |
|---|---|---|
| `FLClassDetective classesForCurrentExecutable` / 0x9b44 | `_NSGetExecutablePath`, `classesForImage:` | Executable-oriented runtime extraction |
| `FLClassDetective classesForImage:` / 0x9c50 | `dlopen` first with 0x10, fallback 0x2; `objc_getClassList`, `class_getImageName`, `strcmp`, `dlclose` | Enumerates loaded runtime classes and associates an image; fallback can load an image. It is not simply file-only metadata decoding |
| `JBKMessagingCenter setup` / 0x8548 | `CPDistributedMessagingCenter`, `centerNamed:`, RocketBootstrap apply | Private messaging bridge exists |
| `ExtractionHandler applicationHandler` / 0x13008 | NSProcessInfo environment, extraction configuration, foreground indicator | Target-side extraction lifecycle |
| `ExtractionHandler communicateBackDictionary:launchedInForeground:` / 0x137d8 | `UIPasteboard generalPasteboard`, `setValue:forPasteboardType:`, `switchBackToFlex` | Foreground result path carries processed data via pasteboard and then switches back |
| `ExtractionHandler switchBackToFlex` / 0x138c0 | `UIApplication sharedApplication`, URL, `openURL:` | Returns to Controller UI |
| `FLMessagingCenter submitProcessedDictionaryforAppWithBundleIdentifier:attachment:` / 0x1eb94 | Validates app/data fields; calls save method | An additional messaging result path exists; not every result uses one universal transport |
| `FLExtractionManager saveProccessedDictionary:forAppWithIdentifier:` / 0x2253c | method-manager file path, `writeToFile:atomically:`, extraction signal removal | Persisted results shown later |

The tweak filter includes UIKit and SpringBoard. Its executable links AppSupport and dynamically resolves RocketBootstrap. Flex.app's code-signature XML contains no-container/no-sandbox/system-application/platform and numerous other privileges. Atlas 0.2.0 binaries had no XML entitlements. That is a concrete packaging difference, **not proof** of the user's exact filesystem denial. Existing maintained jailbreak app [Zebra's entitlement configuration](https://github.com/wstyres/Zebra/blob/62bc2b8ba33cd6045d3a007163bfdda63b201913/Zebra/Supporting%20Files/iOS.entitlements) and [Theos signing flags](https://github.com/wstyres/Zebra/blob/62bc2b8ba33cd6045d3a007163bfdda63b201913/Makefile) independently show explicit application signing configuration. Atlas adds only its three documented Controller deployment keys; target processes receive no new entitlements.

## Atlas audit and resulting changes

Runtime/dyld enumeration, metaclass enumeration, provenance and reviewed ABI wrappers remain appropriate. However, the old automatic flow depended on a background Controller completing socket authentication, every capture page and disk persistence inside a finite background window. One passing Simulator run did not establish a stable physical lifecycle: the user reports fixture timeout, and a later Simulator run had a valid target ticket while Controller results remained waiting. That evidence does not isolate the precise physical cause.

Atlas 0.2.3 therefore performs local in-process capture, writes a bounded JSON/HMAC result under its own result pasteboard namespace, opens Atlas, and validates/persists only while Atlas is foreground. Version, bundle, request UUID, expiry, HMAC, catalog counts/types/provenance and size are checked. No pickle/NSKeyedUnarchiver or reference code is used. Hook controls still use separately authenticated socket IPC; that physical sandbox feasibility remains outstanding.

Persistence previously discarded directory and write NSError details. It now reports stage/domain/code/storage path/serialized size, retains previous disk bytes on failure, rejects invalid JSON and enforces the existing 16 MiB store limit. New host tests cover blocked parent path, oversize state, invalid JSON and retained state. TestTarget displays whether Agent is loaded, distinguishing missing injection from later analysis failure.

Physical Dopamine/RootHide behavior, entitlement enforcement, paste consent and real target bundle sizes must still be tested. Compile/package inspection cannot establish these. The reference's private bridge and large entitlement list were not adopted merely because they occur in the binary.
