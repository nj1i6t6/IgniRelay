// AdapterHealthMonitor — Dart-side observability for the v0.3 BLE adapter
// recovery story (Stage 0c wave 3E).
//
// Spec: docs/specs/native_transport_v1_2026-05-13.md §8 (Adapter Recovery
// Story). The full state machine is per-platform (Android in
// IgniRelayForegroundService, iOS in BlePlugin), but the Dart side OWNS:
//
//   • Aggregating native "scan tick", "advertise tick", and "GATT op" pings
//     into a per-platform liveness clock.
//   • Computing `idle_too_long` flags using the spec §8.2 threshold
//     (5 minutes stale + active foreground service + subscribed peers).
//   • Writing trace rows (`adapter_idle_too_long`, `adapter_soft_recover`,
//     `adapter_hard_recover`, `adapter_permanent_error`) so the dev-mode
//     trace screen and 0d gate test runner have a single observation
//     surface independent of which OS made the call.
//   • Surfacing a broadcast Stream<AdapterHealthEvent> for the UI banner
//     described in spec §8.3 step 3 ("Mesh adapter idle for 5+ minutes").
//
// What this class does NOT do:
//   • Actually call stopScan/startScan or stopAdvertising/startAdvertising
//     — that's per-platform native code. This monitor only OBSERVES and
//     LOGS; the recovery actions belong to the native adapter health
//     subsystem.
//   • Implement the §8.4 "Bluetooth toggled off" listener — that goes
//     through the existing NativeBridge.isBluetoothEnabled() polling and
//     the OS-emitted `ble_peer` events on the existing channel.
//
// CURRENT NATIVE WIRING STATUS — Android source-wired; Dart gates green; device preflight pending. iOS code-wired-only (Stage 0c wave 3F-r3):
//
// This monitor is the OBSERVATION half of the §8 recovery story. The
// RECOVERY-ACTION half (soft restart → hard restart → permanent error
// in §8.3) is now implemented natively on both Android and iOS; see
// spec §8.5 implementation-status table for the per-step mapping. The
// native action callers emit DIFFERENT event types from this Dart
// monitor (`adapter_native_soft_restart` / `adapter_native_hard_restart`
// / `adapter_native_permanent_error`) so QA can attribute who acted vs.
// who observed.
//
// This monitor's events (`AdapterIdleTooLong`, `AdapterSoftRecover`,
// `AdapterHardRecover`, `AdapterPermanentError`) remain the OBSERVATION
// signal: they fire when ticks resume after a `flagged` state, regardless
// of whether the recovery was triggered natively or by user-initiated
// reset. The native and Dart sides do NOT need to coordinate state — they
// share the tick stream as the single source of truth.
//
// Spec §8.3 step 1 SCAN BOUNCE on Android is owned by THIS monitor via
// the optional `onIdleDetected` constructor callback (wired in main.dart
// to `NativeBridge.stopNordicScan` + delay + `startNordicScan`). The
// native FS cannot reach `NordicMeshManager` directly because the latter
// is held by `MainActivity`, not the foreground service. iOS's BlePlugin
// owns both managers in one process and bounces both natively, so the
// Dart callback there is redundant-but-harmless.
//
//   • Android (observation): WIRED + SMOKE-TESTABLE.
//     `IgniRelayForegroundService.emitAdapterTick(...)` fires
//     `adapter_health_tick` events into the shared event sink from
//     - NordicMeshManager.onScanResult                  → kind="scan"
//     - IgniRelayForegroundService.adapterHealthTickRunnable
//       (every 30s while isAdvertising)                 → kind="advertise"
//     - IgniRelayForegroundService GATT callbacks
//       (onWrite/Read/MtuChanged/NotificationSent/Conn) → kind="gatt_op"
//     A peripheral GATT subscriber count > 0 also produces a periodic
//     gatt_op tick so the §8.2 5-min staleness gate can self-validate.
//   • Android (recovery action): WIRED + SMOKE-TESTABLE.
//     `IgniRelayForegroundService.adapterRecoveryRunnable` runs at the
//     spec §8.2 60s cadence; on §8.2 bothStale it calls
//     `attemptSoftRestart` (stop+restart advertising) for up to 2 cycles,
//     then escalates to `attemptHardRestart` (stopBlePeripheral +
//     delayed startBlePeripheral) for up to 2 cycles, then emits
//     `adapter_native_permanent_error`. Scan bounce happens in Dart via
//     `onIdleDetected` (see above).
//   • iOS: CODE WIRED, NOT VERIFIED.
//     `BlePlugin.swift` mirrors Android's tick emit sites and recovery
//     state machine. iOS owns both `CBCentralManager` and
//     `CBPeripheralManager` in one process, so `attemptSoftRestart`
//     restarts BOTH scan and advertise; `attemptHardRestart` tears down
//     and recreates the peripheral manager. STATUS QUALIFIER: no macOS
//     xcodebuild / XCTest run has happened yet (the dev host is
//     Windows); behavior is "should-work-by-construction". Do NOT count
//     iOS toward Stage 0c sign-off until macOS / CI confirms.

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'mesh_trace_writer.dart';

/// Tick kinds the monitor consumes off the native event stream.
enum AdapterHealthTick {
  scan,
  advertise,
  gattOp,
}

/// What this monitor surfaces upward (UI banner + 0d test runner).
sealed class AdapterHealthEvent {
  const AdapterHealthEvent();
}

class AdapterIdleTooLong extends AdapterHealthEvent {
  final Duration idleFor;
  final DateTime detectedAt;
  const AdapterIdleTooLong({required this.idleFor, required this.detectedAt});
}

class AdapterSoftRecover extends AdapterHealthEvent {
  /// Time from `AdapterIdleTooLong` to first successful tick after recovery.
  final Duration recoveryDelay;
  const AdapterSoftRecover({required this.recoveryDelay});
}

class AdapterHardRecover extends AdapterHealthEvent {
  final Duration recoveryDelay;
  const AdapterHardRecover({required this.recoveryDelay});
}

class AdapterPermanentError extends AdapterHealthEvent {
  /// Number of consecutive hard-restart attempts that failed (spec §8.3
  /// step 4: "if step 2 fails twice in a row, the adapter is treated as
  /// broken").
  final int consecutiveFailures;
  const AdapterPermanentError({required this.consecutiveFailures});
}

class AdapterHealthMonitor {
  /// Spec §8.2 — flag `idle_too_long` when the last successful tick is
  /// older than this AND a foreground service is active AND subscribed
  /// peers exist. Both other gates are owned by native code; the Dart side
  /// just tracks staleness.
  static const Duration kStaleThreshold = Duration(minutes: 5);

  /// Spec §8.3 step 1 — soft recovery succeeds if a fresh tick arrives
  /// within 10 seconds of the recovery attempt.
  static const Duration kSoftRecoveryWindow = Duration(seconds: 10);

  /// How often the monitor wakes up and re-evaluates staleness. 60s is
  /// the spec §8.2 cadence.
  static const Duration kCheckInterval = Duration(seconds: 60);

  final Stream<dynamic> _nativeEventStream;
  final MeshTraceWriter _trace;
  final DateTime Function() _now;

  /// Optional hook fired the first time we flag `AdapterIdleTooLong`. Used
  /// by main.dart to bounce Nordic scan (the Dart-side half of spec §8.3
  /// step 1 on Android — the native FS owns the advertise bounce, the
  /// Dart monitor owns the scan bounce, because `NordicMeshManager` is
  /// held by `MainActivity`, not the foreground service, so the FS cannot
  /// reach it).
  ///
  /// On iOS the BlePlugin's own native watchdog already bounces BOTH scan
  /// and advertise (it owns both managers in one process), so the Dart
  /// callback here is redundant — but `NativeBridge.startScan/stopScan`
  /// are idempotent on iOS so calling it both ways is harmless. Kept
  /// platform-agnostic in this class; per-platform wiring is main.dart's
  /// concern.
  final Future<void> Function()? _onIdleDetected;

  final _events = StreamController<AdapterHealthEvent>.broadcast();

  /// Per-tick-kind: when did we last see a successful tick. `null` means
  /// "never seen" — startup is intentionally lenient (no immediate
  /// `idle_too_long` if the app just launched).
  final Map<AdapterHealthTick, DateTime?> _lastTickAt = {
    AdapterHealthTick.scan: null,
    AdapterHealthTick.advertise: null,
    AdapterHealthTick.gattOp: null,
  };

  StreamSubscription<dynamic>? _eventSub;
  Timer? _periodic;
  bool _started = false;
  bool _flaggedIdle = false;
  DateTime? _idleDetectedAt;
  int _consecutiveHardRestartFailures = 0;

  Stream<AdapterHealthEvent> get events => _events.stream;

  AdapterHealthMonitor({
    required Stream<dynamic> nativeEventStream,
    required MeshTraceWriter trace,
    DateTime Function()? now,
    Future<void> Function()? onIdleDetected,
  })  : _nativeEventStream = nativeEventStream,
        _trace = trace,
        _now = now ?? DateTime.now,
        _onIdleDetected = onIdleDetected;

  /// Begin consuming native ticks + periodic staleness evaluation.
  /// Idempotent.
  void start() {
    if (_started) return;
    _started = true;
    _eventSub = _nativeEventStream.listen(_onNativeEvent);
    _periodic = Timer.periodic(kCheckInterval, (_) => _evaluateStaleness());
  }

  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    _periodic?.cancel();
    _periodic = null;
    await _eventSub?.cancel();
    _eventSub = null;
  }

  Future<void> dispose() async {
    await stop();
    await _events.close();
  }

  /// Test-only: synchronously inject a tick. Production path uses
  /// [_onNativeEvent] off the native event stream.
  @visibleForTesting
  void debugInjectTick(AdapterHealthTick kind) {
    _lastTickAt[kind] = _now();
    _maybeNoteRecovery();
  }

  /// Test-only: synchronously trigger a staleness evaluation pass.
  @visibleForTesting
  Future<void> debugEvaluateNow() async {
    await _evaluateStaleness();
  }

  void _onNativeEvent(dynamic event) {
    if (event is! Map) return;
    if (event['type'] != 'adapter_health_tick') return;
    final kindStr = event['kind'];
    if (kindStr is! String) return;
    final kind = switch (kindStr) {
      'scan' => AdapterHealthTick.scan,
      'advertise' => AdapterHealthTick.advertise,
      'gatt_op' => AdapterHealthTick.gattOp,
      _ => null,
    };
    if (kind == null) return;
    _lastTickAt[kind] = _now();
    _maybeNoteRecovery();
  }

  void _maybeNoteRecovery() {
    if (!_flaggedIdle) return;
    final detectedAt = _idleDetectedAt;
    if (detectedAt == null) {
      _flaggedIdle = false;
      return;
    }
    final delay = _now().difference(detectedAt);
    // Spec §8.3 step 1: soft recover if a tick arrived within the window.
    if (delay <= kSoftRecoveryWindow) {
      _emit(AdapterSoftRecover(recoveryDelay: delay));
      _writeTrace(
        action: 'adapter_soft_recover',
        detail: 'recovery_ms=${delay.inMilliseconds}',
      );
    } else {
      _emit(AdapterHardRecover(recoveryDelay: delay));
      _writeTrace(
        action: 'adapter_hard_recover',
        detail: 'recovery_ms=${delay.inMilliseconds}',
      );
    }
    _flaggedIdle = false;
    _idleDetectedAt = null;
    _consecutiveHardRestartFailures = 0;
  }

  Future<void> _evaluateStaleness() async {
    final now = _now();
    final scanTick = _lastTickAt[AdapterHealthTick.scan];
    final advertiseTick = _lastTickAt[AdapterHealthTick.advertise];
    // Per spec §8.2: BOTH scan AND advertise must be stale for >5 min
    // before flagging. (gattOp is informational; not part of the gate.)
    final scanStale = scanTick == null
        ? false
        : now.difference(scanTick) > kStaleThreshold;
    final advertiseStale = advertiseTick == null
        ? false
        : now.difference(advertiseTick) > kStaleThreshold;
    final bothStale = scanStale && advertiseStale;

    if (bothStale && !_flaggedIdle) {
      _flaggedIdle = true;
      _idleDetectedAt = now;
      // scanTick + advertiseTick are non-null inside the bothStale branch
      // because the staleness check above defaults a null tick to "not
      // stale". Use the OLDEST of the two as the staleness anchor.
      final idleFor = now.difference(
        scanTick.isBefore(advertiseTick) ? scanTick : advertiseTick,
      );
      _emit(AdapterIdleTooLong(idleFor: idleFor, detectedAt: now));
      _writeTrace(
        action: 'adapter_idle_too_long',
        detail: 'idle_ms=${idleFor.inMilliseconds}',
      );
      // Spec §8.3 step 1 — Dart-owned recovery action. Fire-and-forget;
      // any failure surfaces via trace through the recovery callback's
      // own error handling (see main.dart wiring). We don't await so a
      // slow native call doesn't block the periodic eval loop.
      final cb = _onIdleDetected;
      if (cb != null) {
        unawaited(_safeRunIdleCallback(cb));
      }
    } else if (bothStale && _flaggedIdle) {
      // Still stale after the soft-recovery window. Escalate to permanent
      // error after spec §8.3 step 4 threshold.
      _consecutiveHardRestartFailures += 1;
      if (_consecutiveHardRestartFailures >= 2) {
        _emit(AdapterPermanentError(
          consecutiveFailures: _consecutiveHardRestartFailures,
        ));
        _writeTrace(
          action: 'adapter_permanent_error',
          detail: 'fails=$_consecutiveHardRestartFailures',
        );
        // Stop emitting further events until something recovers.
        _consecutiveHardRestartFailures = 0;
        _flaggedIdle = false;
        _idleDetectedAt = null;
      }
    }
  }

  void _emit(AdapterHealthEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  /// Wraps the `onIdleDetected` callback so its failures never propagate
  /// out of the periodic eval loop. Logs to trace so QA can correlate a
  /// missed scan bounce with the observed idle window.
  Future<void> _safeRunIdleCallback(
      Future<void> Function() callback) async {
    try {
      await callback();
    } catch (e, st) {
      debugPrint(
        '[AdapterHealthMonitor] onIdleDetected callback threw: $e\n$st',
      );
      await _writeTrace(
        action: 'adapter_idle_callback_failed',
        detail: 'error=${e.toString().replaceAll('\n', ' ')}',
      );
    }
  }

  Future<void> _writeTrace({
    required String action,
    required String detail,
  }) async {
    // AdapterHealthMonitor sits outside the per-envelope dispatcher, so
    // the trace row is identified by the SYNTHETIC envelope_id pattern
    // `'AH'` + zero padding — chosen so the row sorts away from real
    // envelopes in dev-mode queries and is impossible to collide with a
    // UUIDv7 (which always has version nibble 0x7).
    try {
      await _trace.writeSystemEvent(
        category: 'adapter_health',
        action: action,
        detail: detail,
      );
    } catch (e) {
      // Trace failure must never crash the monitor.
      debugPrint('AdapterHealthMonitor trace write failed: $e');
    }
  }
}
