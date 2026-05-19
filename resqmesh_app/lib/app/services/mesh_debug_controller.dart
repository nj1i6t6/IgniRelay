// MeshDebugController — Dart-side facade for the v0.3 0d-gate debug hooks
// (Stage 0c wave 3E).
//
// Spec: docs/specs/native_transport_v1_2026-05-13.md §7.4 (force MTU) +
// §8.5 (force adapter idle for 6 minutes).
//
// This controller is the SINGLE PUBLIC API the dev-mode trace screen + 0d
// gate test runner consume. It wraps NativeBridge.debugForceTargetMtu /
// debugForceAdapterIdle so callers do not depend on the platform channel
// directly; and so future implementations (Wi-Fi Direct radio, simulator)
// can substitute the controller without changing call sites.
//
// RELEASE-BUILD POLICY (Stage 0c wave 3F — important, do not "fix"):
//
// The native handlers (`MainActivity.kt` debugForceTargetMtu /
// debugForceAdapterIdle; `BlePlugin.swift` same cases) are DELIBERATELY
// UNGATED on BuildConfig.DEBUG / DEBUG-flagged Info.plist. This is
// intentional so the 0d acceptance gate can drive RELEASE-mode binaries
// (the gate exercises what users install, not what developers build).
//
// The impact of either hook is BOUNDED by construction:
//   • debugForceTargetMtu — only CLAMPS the negotiated MTU value the
//     upper layers see (min(actual, override)); a clamp can never raise
//     MTU. Wire format is unchanged.
//   • debugForceAdapterIdle — only SUPPRESSES the diagnostic
//     `adapter_health_tick` emissions; no production code path reads
//     them. Signature verification, capability negotiation, and the
//     dispatcher's drop-reason ladder are all untouched.
//
// Neither hook can be used to forge envelopes, bypass signature checks,
// or exceed envelope-size budgets. If a future hook needs hard gating,
// add an explicit `BuildConfig.DEBUG`-checked branch in the native
// handler AND document the gating decision both here and in the spec
// (`docs/specs/native_transport_v1_2026-05-13.md` §7.4 / §8.5).
//
// CURRENT NATIVE WIRING STATUS — Android source-wired; Dart gates green; device preflight pending. iOS code-wired-only (Stage 0c wave 3F-r3):
//
//   The §7.4 + §8.5 debug surfaces have code on both platforms. Android
//   is source-complete on both sides of the channel and the Dart-side
//   gates (`flutter analyze`, `flutter test`, layer / parity / corpus
//   checks) all pass — "source-wired" in this header is the precise
//   claim, NOT "hardware-verified". The Android↔Android 0d real-device
//   gate (scenarios #1–#11 of the roadmap §3.5 brief) is the next
//   preflight step and has not yet been run. iOS surfaces exist in
//   source but additionally await macOS `xcodebuild` + `XCTest` +
//   device smoke before the iOS↔iOS / Android↔iOS gate rows are
//   runnable at all.
//
//   - Android: SOURCE-WIRED, GATES GREEN, PREFLIGHT PENDING.
//     `debugForceTargetMtu` clamps the
//     MTU stored in `IgniRelayForegroundService.deviceMtuMap`
//     (peripheral side) and the value reported from
//     `NordicMeshManager.connect` (central side); `debugForceAdapterIdle`
//     sets `IgniRelayForegroundService.adapterIdleSuppressedUntilMs` so
//     `emitAdapterTick` silently drops emissions until the window
//     expires. See MainActivity's method-channel dispatch + the
//     companion-level helpers.
//   - iOS: CODE WIRED, NOT VERIFIED. `BlePlugin.swift` carries the
//     parallel implementation — `debugForceTargetMtu` writes
//     `debugMtuOverrideByDevice`; the clamp is applied at
//     `peripheralManager.didSubscribeTo` (peripheral-role MTU stash),
//     `PeripheralDelegate.didDiscoverCharacteristicsFor` (central-role
//     MTU stash), AND `notifyEventChunk` (oversize rejection threshold).
//     `debugForceAdapterIdle` writes `adapterIdleSuppressedUntilMs`,
//     which gates `emitAdapterTick` the same way Android does.
//     STATUS QUALIFIER: no macOS xcodebuild / XCTest run yet (the dev
//     host is Windows). Behavior is "should-work-by-construction"; do
//     NOT count toward Stage 0c sign-off until macOS / CI confirms.

import 'package:flutter/foundation.dart';

import 'package:ignirelay_app/app/services/mesh_trace_writer.dart';
import 'package:ignirelay_app/platform/native_bridge.dart';

class MeshDebugController {
  final MeshTraceWriter _trace;

  MeshDebugController({required MeshTraceWriter trace}) : _trace = trace;

  /// Clamp the next MTU negotiation for [deviceId] to [targetMtu]. Pass
  /// `null` to clear an active override. The 0d gate uses this to exercise
  /// MTU=185, 247, 512 on the same hardware pair (spec §7.4).
  ///
  /// Returns `true` on success, `false` if the native side rejected
  /// (out-of-range MTU, debug hook not built into this binary, plugin
  /// missing on this platform). Also writes a trace row regardless of
  /// outcome so the QA agent can correlate test events.
  Future<bool> forceTargetMtu({
    required String deviceId,
    required int? targetMtu,
  }) async {
    final ok = await NativeBridge.debugForceTargetMtu(
      deviceId: deviceId,
      targetMtu: targetMtu,
    );
    await _trace.writeSystemEvent(
      category: 'mesh_debug',
      action: 'force_target_mtu',
      detail: 'device=$deviceId mtu=${targetMtu ?? "clear"} ok=$ok',
    );
    return ok;
  }

  /// Tell the native AdapterHealthMonitor to suppress scan + advertise
  /// emissions for [duration]. Used by the 0d gate scenario #11
  /// ("force adapter idle for 6 minutes; mesh recovers within 60 seconds
  /// of soft restart" — spec §8.5).
  ///
  /// Returns `true` on success. Also writes a trace row so the QA agent
  /// can timestamp the start of the idle window for measuring recovery
  /// delay against `adapter_soft_recover` / `adapter_hard_recover` events
  /// from [AdapterHealthMonitor].
  Future<bool> forceAdapterIdle({required Duration duration}) async {
    final ok = await NativeBridge.debugForceAdapterIdle(duration: duration);
    await _trace.writeSystemEvent(
      category: 'mesh_debug',
      action: 'force_adapter_idle',
      detail: 'duration_ms=${duration.inMilliseconds} ok=$ok',
    );
    if (!ok) {
      debugPrint(
        'MeshDebugController.forceAdapterIdle: native hook not wired '
        '(Stage 0c wave 3E followup). 0d gate scenario #11 cannot run.',
      );
    }
    return ok;
  }
}
