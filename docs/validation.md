# Validation record

Development host: Windows PowerShell/Python 3.12.9. Workspace and remote were empty; `main` initialized. WSL Ubuntu cannot start (`HCS_E_SERVICE_NOT_AVAILABLE`); no local clang/iOS SDK. macOS CI is used for Objective-C execution and iOS package build.

Executed locally:

```text
python -m unittest discover -s tests -p 'test_*.py' -v
4 tests PASS: real ustar inspection; GNU tar rejection; malformed ar rejection; unsigned/wrong-CPU Mach-O rejection.
```

CI commands/results and package reports will be recorded after execution. Package inspector reads actual deb/ar members, gzip bytes, every tar header, control architecture, all Mach-O binaries, dependencies, rpaths and code-signature command. Runtime host tests exercise production scanner/hook engine with TestTarget declarations. Host IPC test uses production transport between separate processes.

Not verified: physical iOS sandbox bidirectional IPC; Dopamine/RootHide injection, signing acceptance, home-screen UI, background scheduling, live ABI on iPhone 11, real old-dpkg installation. Static string pools are partial metadata; no chained-fixup/class-method relationship reconstruction. Arbitrary application method hooks deliberately unsupported pending declaration review. These are release/device acceptance limits, not passed tests.
