# Device acceptance checklist (not yet executed)

Record separate evidence for iPhone 11/iOS 15.5/Dopamine and RootHide. Never reuse package validation as device evidence.

1. Install matching deb, run uicache if needed, verify both home-screen applications. Inspect actual Agent loaded path and Mach-O CPU; no libFLEX link.
2. For sandbox IPC gate use a development-signed/containerized TestTarget built from the same fixture sources, with normal app sandbox and no private IPC entitlements. Verify sandbox status, pair, run **IPC feasibility ping**, export exact echo/IDs. A Theos /Applications fixture alone is insufficient sandbox proof.
3. Open TestTarget; pair token, return Controller and activate. Confirm PID, executable, bundle and connected/active status.
4. Browse Runtime Loaded TestTarget image → LXFixture. Capture instance and class methods, selector and encoding. Test image/class/selector search with a large UIKit/framework catalog.
5. Enable all seven reviewed methods. Call TestTarget methods; results must be ping count+1, object identity, integer 42, BOOL true, float 3, double 5, class 42. Export logs with arguments/return/thread/time/duration/encoding. Never call arbitrary description from logger.
6. Disable each; verify identical results and no additional hook logs. Verify runtime IMP restoration using an on-device test harness if available.
7. `point:` struct and `variadic:` must be unhookable, reason visible. Other app methods must remain browse-only until reviewed manifest is explicitly extended.
8. Run Static Only scan. Unloaded embedded files and class-name string hints must remain Static Only; encrypted/invalid files return structured errors.
9. Save/export/relaunch; per-bundle desired state/history retained, no silent hook restoration. Pairing token regenerated only on Controller process restart and never exported.
10. Close/suspend Controller and wait beyond timeout; Agent disables hooks. Test foreign IMP conflict, concurrent calls and event/generation limits using the production test harness.

Capture date, environment, commands, JSON artifacts, actual-vs-expected results and any failure. Do not commit device identifiers, signing material, secrets or private application data.
