# Android to Android 0D Preflight

Date: 2026-05-19
Scope: v0.3 Stage 0d Android-pair preflight only. This is not the full 0d gate; iOS and Android-to-iOS remain blocked until macOS/Xcode and iOS device validation are available.

## Purpose

Verify that the Stage 0c Android source-wired path can run on two real Android phones before opening Stage 1 UI work:

- PROTOCOL_HELLO capability negotiation.
- v2 chunked envelope delivery through BLE.
- Outbox_V2 restart-safe pending queue.
- MTU clamp debug hook.
- Adapter idle/recovery debug hook.
- Kotlin wire-conformance instrumentation consumer.

## Devices

Minimum for this preflight:

- Device A: Pixel 7 or equivalent Android phone.
- Device B: second Android phone.
- USB debugging enabled on both.
- Bluetooth enabled on both.
- Location/Bluetooth permissions granted to the app on both.
- Battery optimization exemption accepted if prompted.

Record before testing:

| Field | Device A | Device B |
|---|---|---|
| `adb serial` |  |  |
| Model |  |  |
| Android version |  |  |
| App build / commit |  |  |

## Host Commands

Use the bundled Android platform tools:

```powershell
$adb = "C:\Users\radio\Android\Sdk\platform-tools\adb.exe"
& $adb devices -l
```

Build/install debug APK from `resqmesh_app`:

```powershell
flutter build apk --debug --no-pub
& $adb -s <DEVICE_A> install -r build\app\outputs\flutter-apk\app-debug.apk
& $adb -s <DEVICE_B> install -r build\app\outputs\flutter-apk\app-debug.apk
```

Clear logs immediately before each scenario:

```powershell
& $adb -s <DEVICE_A> logcat -c
& $adb -s <DEVICE_B> logcat -c
```

Useful log capture filters:

```powershell
& $adb -s <DEVICE_A> logcat -v time IgniRelay:D BLE:D flutter:I AndroidRuntime:E *:S
& $adb -s <DEVICE_B> logcat -v time IgniRelay:D BLE:D flutter:I AndroidRuntime:E *:S
```

Run Android instrumentation wire conformance on at least one attached device:

```powershell
cd resqmesh_app\android
.\gradlew.bat :app:connectedDebugAndroidTest
```

Expected: `WireConformanceInstrumentationTest` passes. Report path is under `resqmesh_app/android/app/build/reports/androidTests/connected/`.

## Scenario Matrix

This preflight uses two phones, so it cannot validate 3-hop SOS p95. It validates the Android pair source path before the full 0d pool.

| # | Scenario | Steps | Pass |
|---|---|---|---|
| A1 | Cold discovery + HELLO | Launch app on both phones. Start BLE/mesh mode if not automatic. Wait 30s. | Both phones discover peer; logs show `peer_ready_for_hello` and HELLO accepted/active state. |
| A2 | STATUS_UPDATE v2 publish | On A publish SAFE, then INJURED, then SAFE. | B final state/log is SAFE; no `priority-mismatch`; INJURED emits at SOS_YELLOW floor on sender path. |
| A3 | SOS_RED/urgent status | On A publish trapped/SOS status. | B receives signed v2 envelope; latency under 60s; no `signature-invalid`, `unknown-protocol-version`, or `max-hops-overcommit`. |
| A4 | Chunked payload | Send an ALERT/HAZARD-sized payload near 800B if a dev trigger exists. | Logs show multiple chunks and successful reassembly; no `reassembly-timeout` or `reassembly-envelope-id-mismatch`. |
| A5 | Outbox restart persistence | Put B out of range or turn BT off. Publish chat/status on A. Force-stop A app, relaunch, then bring B back. | A hydrates `Outbox_V2`; pending item drains; receiver sees the same `envelope_id` once, not duplicate logical events. |
| A6 | MTU clamp | Use debug hook to clamp peer MTU to 185, then repeat A2/A3. Clear clamp and repeat at 247 if possible. | Sends use the clamped MTU; oversized single-notify is rejected/chunked, not truncated. |
| A7 | Reconnect | Disconnect/turn BT off on B for 30s, then restore. | Rediscovery within 60s; HELLO returns active; queued traffic drains. |
| A8 | Adapter idle recovery | Trigger `debugForceAdapterIdle` for 6 minutes. | Logs show `adapter_native_soft_restart` and Dart `adapter_soft_recover`/fresh ticks within 60s after suppression ends; no crash. |
| A9 | Kotlin conformance | Run `connectedDebugAndroidTest`. | `WireConformanceInstrumentationTest` passes. |

## 2026-05-21 Two-Phone Execution Plan

This run is intended to extract as much BLE evidence as possible while the two Android devices are physically available. It is still an Android-pair preflight, not the full 0d gate.

### Actual Devices

| Field | Device A | Device B |
|---|---|---|
| `adb serial` | `94067a07` | `LNZ5TKY5NRNVQ4K7` |
| Model | Xiaomi `25102PCBEG` | Xiaomi `2311DRK48G` |
| Android version | 16 / SDK 36 | 15 / SDK 35 |
| App branch | `V0.2.5` | `V0.2.5` |

### Today Priority Order

1. **Smoke the host path**: `adb devices`, `logcat`, runtime permissions, Bluetooth enabled, app foreground, `IgniRelayForegroundService` foreground.
2. **Build and install the exact APK** from the current workspace.
3. **Cold BLE discovery**: clear logs, relaunch both apps, wait 60-90 seconds, verify `FOUND`, `NORDIC CONNECTED`, `GATT_MTU`, `peer_ready_for_hello`, and debug panel `connected peers`.
4. **IBLT/Bloom sync health**: verify IBLT does not throw platform exceptions; if IBLT is unavailable, verify Bloom fallback completes with `NOTIFY_END`.
5. **Wire conformance on devices**: run `:app:connectedDebugAndroidTest` on both attached phones and preserve XML result counts.
6. **Event transfer**: if the build exposes a debug publish trigger, publish one minimal `STATUS_UPDATE` or `SOS_RED` on A and verify B receives it. If no trigger exists, record this as tooling unavailable and add a follow-up to expose an adb-callable 0d publish trigger.
7. **Low-MTU behavior**: if `debugForceTargetMtu` is callable from an exposed app path, clamp to 185 and repeat event transfer. Otherwise record as tooling unavailable.
8. **Reconnect**: toggle Bluetooth on B or force-stop/relaunch B, then verify rediscovery and sync after cooldown.
9. **Collect artifacts**: save app-pid logcat for both devices, screenshots/debug panels, instrumentation XML, and a concise result table.

### Known Findings To Verify In This Run

- Android `notifyCharacteristicChanged` rejects BLE characteristic values above 512 B even when MTU=517. Single-notify payload cap must therefore be `min(MTU - 3, 512)`, not only `MTU - 3`.
- IBLT response is 513 B (`control` 1 B + `watermark` 8 B + IBLT 504 B), so until chunked IBLT exists it must explicitly fall back to Bloom instead of entering the Android platform notify path.
- Bloom payload packets are larger than a single notify and may be rejected by the single-notify path; the current pass criterion is correctness via fallback / end marker, not IBLT bandwidth efficiency.
- `Invalid wire payload` from the legacy `MeshEventHandler` can appear when v2 chunks also reach the legacy receive path. Treat it as a warning unless v2 dispatcher/projector fails to accept/display an actual v2 event.

### Result Table Template

| Scenario | Result | Evidence |
|---|---|---|
| Host/device permissions |  |  |
| APK build/install |  |  |
| Cold discovery |  |  |
| GATT connect + MTU |  |  |
| PROTOCOL_HELLO / peer ready |  |  |
| IBLT no platform exception |  |  |
| Bloom fallback |  |  |
| Event A to B |  |  |
| Reconnect |  |  |
| Instrumentation conformance |  |  |

## Required Evidence

For each failed scenario, save:

- Device A logcat.
- Device B logcat.
- Exact app commit hash.
- Scenario id.
- Whether failure is functional, timing, crash, or tooling.

Minimum log markers to search:

```text
peer_ready_for_hello
PROTOCOL_HELLO
adapter_health_tick
adapter_native_soft_restart
adapter_soft_recover
notify_push_error
signature-invalid
dedupe-hit
reassembly-timeout
reassembly-envelope-id-mismatch
```

## Exit Criteria

Android-pair preflight passes when:

- A1, A2, A3, A5, A7, A8, A9 pass.
- A4 and A6 pass if the current build exposes the required dev trigger; otherwise record as "tooling unavailable" and keep full 0d blocked until the trigger exists.
- No app crash, ANR, silent truncation, or signature regression appears in logs.

Full Stage 0d remains blocked until:

- Android-to-Android preflight is green.
- iOS `xcodebuild` + `IBLTParityTests` + `WireConformanceTests` are green.
- iOS-to-iOS and Android-to-iOS real-device rows are executed.
- 3-hop SOS timing is executed with a larger device pool.
