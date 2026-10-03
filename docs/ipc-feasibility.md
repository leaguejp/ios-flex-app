# IPC feasibility experiment

Candidate comparison:

| Candidate | Decision |
|---|---|
| Mach/XPC launchd service | Deferred: sandbox lookup/private entitlement availability has not been demonstrated on both schemes |
| Shared file / Unix domain socket | Rejected: target sandbox and randomized RootHide paths make shared directory access an unproven assumption |
| Darwin notifications + shared payload | Rejected: notifications alone cannot transport structured payload; shared payload retains sandbox/path problem |
| IPv4 loopback TCP | Selected provisionally: path independent, public socket APIs, no private IPC entitlement; authentication and framing implemented |

The small production-transport probe is `tests/ipc_test.m`: separate processes exchange versioned command/response with a nonce/echo. It verifies framing/correlation on macOS. The TestTarget Pair button and Controller **IPC feasibility ping** use the same transport for the iOS sandbox experiment. Do this **before** activating analysis/hooks.

Device pass condition: TestTarget is demonstrably sandboxed, pairs via 127.0.0.1, Controller ping returns the exact nonce, IDs/PID/bundle match, both directions survive fragmented/coalesced frames, and reconnection works after target restart. Repeat on ordinary Dopamine and RootHide separately. Capture OS/jailbreak versions, sandbox status, log export and failure NSError if denied. A simulator or system-installed uncontainered Theos app is not sandbox proof. For a genuinely sandboxed fixture, sign/install the same fixture sources through an authorized development provisioning flow (no no-container/network-exception private entitlements); certificates remain outside Git.

Current development environment has no connected iPhone or provisioning material. Device feasibility is **not passed**. Main implementation uses the candidate provisionally; do not present this as demonstrated sandbox compatibility. See validation.md for actual host results.
