// Per-peer capability state machine (v0.3 Stage 0c wave 3A).
//
// Spec: docs/specs/native_transport_v1_2026-05-13.md §5.2, §5.7, §6.2, §15.9.
//
// One [PeerCapabilityState] per BLE peer (keyed by the platform peer-id
// surfaced through the BLE event channel). The registry is fed by two
// inputs:
//
//   • `onPeerReadyForHello(peerId)` — fired by the native plugin after
//     MTU negotiation AND service discovery complete (§5.2 §15.2). Starts
//     the 5-second fallback timer.
//
//   • `onHelloAccepted(peerId, payload)` — fired by the
//     ProtocolHelloService after an envelope of EVENT_TYPE_PROTOCOL_HELLO
//     has been accepted by EnvelopeDispatcherV2 (signature already
//     verified). The payload is run through ProtocolHelloValidator and
//     the resulting profile (or drop) updates state.
//
// Disconnects evict per-peer state. The registry exposes a broadcast
// stream of state changes so other subsystems (TX path, dev trace UI)
// can react without polling.

import 'dart:async';
import 'dart:typed_data';

import 'package:ignirelay_app/app/mesh/capability_profile.dart';
import 'package:ignirelay_app/app/mesh/mesh_constants.dart';
import 'package:ignirelay_app/app/proto/event_envelope_v2.dart';
import 'package:ignirelay_app/app/services/protocol_hello_validator.dart';

enum PeerCapabilityStatus {
  /// HELLO trigger fired; 5s fallback timer is running. Outbound TX should
  /// hold non-HELLO envelopes until status leaves `pending`.
  pending,

  /// Valid HELLO received and profile assigned.
  active,

  /// Timer fired without a HELLO. Profile defaults to phoneV1Legacy (§6.1.1).
  legacyFallback,

  /// HELLO arrived but validator rejected it. The connection MUST be torn
  /// down per §5.7 (caller's responsibility); profile defaults to
  /// phoneV1Legacy as defensive fallback.
  failed,
}

class PeerCapabilityState {
  final String peerId;
  final PeerCapabilityStatus status;
  final CapabilityProfile profile;

  /// Set iff status == active.
  final ProtocolHelloData? hello;

  /// Set iff status == failed (one of ProtocolHelloValidator's drop codes).
  final String? failureReason;

  /// Free-text companion to failureReason; mainly for trace logs.
  final String? failureDetail;

  /// When the HELLO trigger fired for this peer.
  final DateTime? helloReadyAt;

  /// When the status was last updated.
  final DateTime statusAt;

  const PeerCapabilityState({
    required this.peerId,
    required this.status,
    required this.profile,
    required this.statusAt,
    this.hello,
    this.failureReason,
    this.failureDetail,
    this.helloReadyAt,
  });

  PeerCapabilityState copyWith({
    PeerCapabilityStatus? status,
    CapabilityProfile? profile,
    ProtocolHelloData? hello,
    String? failureReason,
    String? failureDetail,
    DateTime? helloReadyAt,
    DateTime? statusAt,
  }) =>
      PeerCapabilityState(
        peerId: peerId,
        status: status ?? this.status,
        profile: profile ?? this.profile,
        hello: hello ?? this.hello,
        failureReason: failureReason ?? this.failureReason,
        failureDetail: failureDetail ?? this.failureDetail,
        helloReadyAt: helloReadyAt ?? this.helloReadyAt,
        statusAt: statusAt ?? this.statusAt,
      );

  /// True if we can route non-HELLO envelopes to this peer right now.
  /// Pending is intentionally NOT ready — we don't yet know what the peer
  /// can accept, so holding briefly is the safe default.
  bool get isReadyForTraffic =>
      status == PeerCapabilityStatus.active ||
      status == PeerCapabilityStatus.legacyFallback;
}

class PeerCapabilityRegistry {
  final Duration helloTimeout;
  final DateTime Function() _now;

  final Map<String, PeerCapabilityState> _states = {};
  final Map<String, Timer> _timers = {};
  final StreamController<PeerCapabilityState> _changes =
      StreamController<PeerCapabilityState>.broadcast();

  PeerCapabilityRegistry({
    Duration? helloTimeout,
    DateTime Function()? now,
  })  : helloTimeout =
            helloTimeout ?? const Duration(milliseconds: kHelloFallbackTimeoutMs),
        _now = now ?? DateTime.now;

  /// Broadcast stream of state transitions. Subscribers MUST be tolerant of
  /// rapid bursts (a single HELLO can produce two events: pending →
  /// active / failed / legacyFallback).
  Stream<PeerCapabilityState> get changes => _changes.stream;

  PeerCapabilityState? stateFor(String peerId) => _states[peerId];

  Iterable<PeerCapabilityState> get allStates => _states.values;

  /// Fired when native MTU + service-discovery is complete. Starts the 5s
  /// timer (§5.2 §15.2). Calling twice for the same peer cancels the prior
  /// timer and re-arms.
  void onPeerReadyForHello(String peerId) {
    _cancelTimer(peerId);
    final now = _now();
    final state = PeerCapabilityState(
      peerId: peerId,
      status: PeerCapabilityStatus.pending,
      profile: CapabilityProfile.phoneV1Legacy,
      helloReadyAt: now,
      statusAt: now,
    );
    _states[peerId] = state;
    _changes.add(state);
    _timers[peerId] = Timer(helloTimeout, () => _onTimeout(peerId));
  }

  /// Fired by ProtocolHelloService when a signature-verified HELLO arrives.
  /// Returns the validation result so the caller can decide whether to
  /// tear down the BLE connection (failed cases per §5.7).
  HelloValidationResult onHelloAccepted(String peerId, Uint8List payload) {
    final result = ProtocolHelloValidator.validate(payload);

    // Tolerate HELLO arriving before the native trigger (rare but possible
    // when the platform packs callbacks tightly).
    final base = _states[peerId] ?? _newPending(peerId);
    _cancelTimer(peerId);

    final PeerCapabilityState next;
    final now = _now();
    if (result.isAccepted) {
      next = base.copyWith(
        status: PeerCapabilityStatus.active,
        profile: result.profile!,
        hello: result.hello,
        statusAt: now,
      );
    } else {
      next = base.copyWith(
        status: PeerCapabilityStatus.failed,
        profile: CapabilityProfile.phoneV1Legacy,
        failureReason: result.dropReason,
        failureDetail: result.detail,
        statusAt: now,
      );
    }
    _states[peerId] = next;
    _changes.add(next);
    return result;
  }

  /// Fired when the BLE connection drops. All per-peer state is evicted;
  /// the next connect will start cleanly with a fresh trigger.
  void onPeerDisconnected(String peerId) {
    _cancelTimer(peerId);
    _states.remove(peerId);
  }

  void _onTimeout(String peerId) {
    final current = _states[peerId];
    if (current == null) return;
    if (current.status != PeerCapabilityStatus.pending) return;
    final next = current.copyWith(
      status: PeerCapabilityStatus.legacyFallback,
      profile: CapabilityProfile.phoneV1Legacy,
      statusAt: _now(),
    );
    _states[peerId] = next;
    _timers.remove(peerId);
    _changes.add(next);
  }

  void _cancelTimer(String peerId) {
    _timers.remove(peerId)?.cancel();
  }

  PeerCapabilityState _newPending(String peerId) {
    final now = _now();
    return PeerCapabilityState(
      peerId: peerId,
      status: PeerCapabilityStatus.pending,
      profile: CapabilityProfile.phoneV1Legacy,
      helloReadyAt: now,
      statusAt: now,
    );
  }

  Future<void> dispose() async {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    _states.clear();
    await _changes.close();
  }
}
