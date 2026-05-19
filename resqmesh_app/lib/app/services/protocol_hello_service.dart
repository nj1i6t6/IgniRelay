// PROTOCOL_HELLO orchestrator (v0.3 Stage 0c wave 3A).
//
// Spec: docs/specs/native_transport_v1_2026-05-13.md §5.
//
// Ties three pre-existing pieces together:
//
//   • PeerCapabilityRegistry (state machine + 5s fallback timer)
//   • MessagePublisherV2     (build/sign/encode/chunk a PROTOCOL_HELLO envelope)
//   • EnvelopeDispatcherV2   (receive pipeline; we subscribe to outcomes and
//                              route accepted HELLO envelopes to the registry)
//
// The actual byte transmission is delegated to an injected callback so this
// service stays independent of the BLE plugin (wave 3B will wire it to the
// native event_char write path once the chunker is connected end-to-end).

import 'dart:async';
import 'dart:typed_data';

import 'package:ignirelay_app/app/controllers/envelope_dispatcher_v2.dart';
import 'package:ignirelay_app/app/controllers/message_publisher_v2.dart';
import 'package:ignirelay_app/app/proto/event_envelope_v2.dart';
import 'package:ignirelay_app/app/services/peer_capability_registry.dart';

/// Transport callback the service invokes once HELLO chunks are ready. The
/// callback hands the bytes to whatever pushes them on the wire (native BLE
/// write, in-process loopback, or a test stub). Returns true if the send
/// path accepted the bytes (success of the actual notify is observed
/// separately via the BLE event channel).
typedef HelloChunkTransport = Future<bool> Function(
  String peerId,
  List<Uint8List> chunks,
  int negotiatedMtu,
);

/// Optional clock injection so tests can drive HLC values deterministically.
typedef NowMsFn = int Function();

class ProtocolHelloService {
  final MessagePublisherV2 _publisher;
  final PeerCapabilityRegistry _registry;
  final HelloChunkTransport _sendChunks;
  final ProtocolHelloData Function() _selfHelloFactory;
  final NowMsFn _nowMs;

  /// PROTOCOL_HELLO is zero-hop control traffic per spec
  /// envelope_v2_spec §11.4 ("relays MUST NOT propagate it"). The §11.2
  /// default table also pins `maxHopsDefault(protocolHello) == 0`.
  ///
  /// Wave 3E-r3 fix: was `1` in 3E-r2. The production
  /// EnvelopeDispatcherV2 runs with `enableMaxHopsOvercommit: true`
  /// (main.dart), so a received HELLO with `max_hops = 1` exceeds the
  /// cap of 0 and is dropped with `drop_reason = max-hops-overcommit`
  /// — the v0.3 HELLO handshake never completes, the peer never leaves
  /// `pending`, and `EventPublisherV2Facade` never has a ready target
  /// to drain its queue against. Pinning to 0 here is the spec-correct
  /// value; defense in depth in `MeshRouter.shouldForwardPacket` still
  /// blocks HELLO relay regardless.
  static const int _helloMaxHops = 0;

  /// Spec doesn't pin a HELLO TTL; pick 60 s — generous enough to absorb
  /// any clock skew, short enough that a stale HELLO floating in the mesh
  /// cannot re-set a profile minutes later.
  static const int _helloTtlMs = 60 * 1000;

  StreamSubscription<DispatchOutcome>? _dispatcherSub;

  ProtocolHelloService({
    required MessagePublisherV2 publisher,
    required PeerCapabilityRegistry registry,
    required HelloChunkTransport sendChunks,
    required ProtocolHelloData Function() selfHelloFactory,
    NowMsFn? nowMs,
  })  : _publisher = publisher,
        _registry = registry,
        _sendChunks = sendChunks,
        _selfHelloFactory = selfHelloFactory,
        _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  /// Subscribe to dispatcher outcomes so accepted HELLO envelopes update
  /// the registry. Must be called once during app boot.
  void attachDispatcher(EnvelopeDispatcherV2 dispatcher) {
    _dispatcherSub?.cancel();
    _dispatcherSub = dispatcher.outcomes.listen(_onDispatcherOutcome);
  }

  /// Fired by the BLE plugin's `peer_ready_for_hello` event (§5.2): MTU
  /// negotiation AND service discovery have both completed for `peerId`.
  /// Starts the 5 s fallback timer and emits our own HELLO toward the peer.
  ///
  /// Returns a Future that completes when the chunk transport callback
  /// returns; callers may await it for tests, ignore it in production.
  Future<void> onPeerReadyForHello(String peerId, int negotiatedMtu) async {
    _registry.onPeerReadyForHello(peerId);
    PublishedEnvelope published;
    try {
      final now = _nowMs();
      published = await _publisher.send(
        eventType: EventTypeV2.protocolHello,
        priority: PriorityV2.normal,
        payload: _selfHelloFactory().encode(),
        createdAtHlc: HlcTimestampV2(msSinceEpoch: now, counter: 0),
        expiresAtHlc:
            HlcTimestampV2(msSinceEpoch: now + _helloTtlMs, counter: 0),
        maxHops: _helloMaxHops,
        negotiatedMtu: negotiatedMtu,
      );
    } on PublishRejected {
      // Sender-side rejection of our OWN HELLO is a programming bug — the
      // matrix accepts PROTOCOL_HELLO at NORMAL by construction, and the
      // payload always fits the budget. Re-throw so it surfaces during
      // development; production builds will see this go to the crash sink.
      rethrow;
    }
    await _sendChunks(peerId, published.chunks, negotiatedMtu);
  }

  /// Fired when the BLE peer disconnects. Clears the registry entry; the
  /// next reconnect will restart the HELLO handshake cleanly.
  void onPeerDisconnected(String peerId) {
    _registry.onPeerDisconnected(peerId);
  }

  Future<void> dispose() async {
    await _dispatcherSub?.cancel();
    _dispatcherSub = null;
  }

  void _onDispatcherOutcome(DispatchOutcome outcome) {
    if (outcome is! DispatchAccepted) return;
    if (outcome.envelope.eventType != EventTypeV2.protocolHello) return;
    final peerId = outcome.peerId;
    if (peerId == null) return;
    _registry.onHelloAccepted(peerId, outcome.envelope.payload);
  }
}

/// Build a self-describing HELLO. The publisher facade caller plumbs this
/// into [ProtocolHelloService] so the service can stay agnostic to which
/// of our capabilities are runtime-configurable.
ProtocolHelloData buildSelfHello({
  required int peerKind,
  required int maxRxEnvelopeBytes,
  required bool supportsIblt,
  required bool supportsBloomV2,
  required bool supportsChunking,
  required int minNegotiatedMtu,
  required int bgState,
  List<String> capabilities = const <String>[],
}) {
  // Defensive: the receiver drops `PEER_KIND_PHONE_V1_LEGACY` per §15.9,
  // so we must never self-advertise legacy. Caller errors should fail
  // fast rather than silently emit a HELLO that other peers will reject.
  if (peerKind == PeerKind.phoneV1Legacy) {
    throw ArgumentError.value(
      peerKind,
      'peerKind',
      'self HELLO must not declare PHONE_V1_LEGACY (§5.7 §15.9)',
    );
  }
  if (peerKind == PeerKind.unspecified) {
    throw ArgumentError.value(
      peerKind,
      'peerKind',
      'self HELLO must specify a concrete PeerKind',
    );
  }
  return ProtocolHelloData(
    peerKind: peerKind,
    maxRxEnvelopeBytes: maxRxEnvelopeBytes,
    supportsIblt: supportsIblt,
    supportsBloomV2: supportsBloomV2,
    supportsChunking: supportsChunking,
    minNegotiatedMtu: minNegotiatedMtu,
    capabilities: capabilities,
    bgState: bgState,
  );
}
