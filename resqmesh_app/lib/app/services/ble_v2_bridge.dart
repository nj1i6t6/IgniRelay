// BleV2Bridge — Dart-side glue between native BLE events and the v0.3
// EventEnvelope v2 trusted pipeline (Stage 0c wave 3B).
//
// Spec: docs/specs/native_transport_v1_2026-05-13.md §3, §4, §5.
//
// Responsibilities (one place, easy to wire from main.dart):
//   • Subscribes to the native EventChannel and demuxes by `type` field.
//   • `peer_ready_for_hello` → ProtocolHelloService.onPeerReadyForHello
//   • `ble_data` / `nordic_data` → per-peer Reassembler → EnvelopeDispatcherV2
//   • `ble_peer` (state != connected) → ProtocolHelloService.onPeerDisconnected
//   • `gatt_mtu` → tracks per-peer MTU so outbound send picks the right size
//   • Acts as the HelloChunkTransport for ProtocolHelloService so HELLO bytes
//     are actually written to the wire.
//   • Provides [sendEnvelope] — capability-aware outbound; rejects sends to
//     peers whose profile cannot reassemble multi-chunk envelopes
//     (`peer-no-chunking`) and to peers that have not finished HELLO yet
//     (`peer-not-ready`) or whose HELLO failed (`peer-hello-failed`).
//
// Wiring is closure-based so unit tests can substitute fake transports and a
// synthetic event stream without bringing in the platform channel.

import 'dart:async';
import 'dart:typed_data';

import 'package:ignirelay_app/app/controllers/envelope_dispatcher_v2.dart';
import 'package:ignirelay_app/app/controllers/message_publisher_v2.dart';
import 'package:ignirelay_app/app/mesh/capability_profile.dart';
import 'package:ignirelay_app/app/mesh/reassembler.dart';
import 'package:ignirelay_app/app/proto/event_envelope_v2.dart';
import 'package:ignirelay_app/app/services/envelope_store_v2.dart';
import 'package:ignirelay_app/app/services/peer_capability_registry.dart';
import 'package:ignirelay_app/app/services/protocol_hello_service.dart';

/// Per-chunk write/notify callback. The bridge picks one based on the BLE
/// role recorded for each peer (`central` vs `peripheral`).
typedef NativeChunkSink = Future<bool> Function(
    String deviceId, Uint8List chunkBytes);

/// Outcome of a [BleV2Bridge.sendEnvelope] call.
class TxOutcome {
  final bool sent;

  /// The signed/encoded envelope (chunks etc.) — present iff `sent`.
  final PublishedEnvelope? published;

  /// One of the spec drop_reason codes (envelope_v2_spec §15.2 + extensions)
  /// — present iff `!sent`.
  final String? dropReason;

  /// Free-text detail for trace logs / dev console.
  final String? detail;

  const TxOutcome._({
    required this.sent,
    this.published,
    this.dropReason,
    this.detail,
  });

  factory TxOutcome.sent(PublishedEnvelope published) =>
      TxOutcome._(sent: true, published: published);

  factory TxOutcome.rejected(String reason, [String detail = '']) =>
      TxOutcome._(sent: false, dropReason: reason, detail: detail);
}

class BleV2Bridge {
  final EnvelopeStoreV2 store;
  final EnvelopeDispatcherV2 dispatcher;
  final MessagePublisherV2 publisher;
  final PeerCapabilityRegistry registry;
  final ProtocolHelloData Function() selfHelloFactory;

  /// Native EventChannel broadcast stream (`NativeBridge.nativeEventStream`
  /// in production; a fake StreamController in tests).
  final Stream<dynamic> nativeEventStream;

  /// Central-role writes (we are the central; peer is the GATT server).
  final NativeChunkSink writeEventToPeer;

  /// Peripheral-role notifies (we are the GATT server; peer is the central
  /// subscribed to EVENT_CHAR).
  final NativeChunkSink notifyEventToPeer;

  /// Conservative MTU used when the per-peer upcall has not arrived yet.
  /// 247 is the §7 baseline for "common modern phone"; will be overwritten
  /// by the first `gatt_mtu` / `peer_ready_for_hello` event.
  static const int _defaultMtu = 247;

  late final ProtocolHelloService helloService;

  final Map<String, Reassembler> _reassemblers = {};
  final Map<String, int> _peerMtu = {};

  /// 'central' if we initiated the connection (peer is the GATT server, use
  /// nordicWriteEvent); 'peripheral' if peer subscribed to our notify (use
  /// notifyEventChunk).
  final Map<String, String> _peerRole = {};

  StreamSubscription<dynamic>? _eventSub;
  bool _started = false;

  BleV2Bridge({
    required this.store,
    required this.dispatcher,
    required this.publisher,
    required this.registry,
    required this.selfHelloFactory,
    required this.nativeEventStream,
    required this.writeEventToPeer,
    required this.notifyEventToPeer,
  }) {
    helloService = ProtocolHelloService(
      publisher: publisher,
      registry: registry,
      sendChunks: _sendHelloChunks,
      selfHelloFactory: selfHelloFactory,
    );
  }

  /// Begin consuming native events. Idempotent.
  void start() {
    if (_started) return;
    _started = true;
    helloService.attachDispatcher(dispatcher);
    _eventSub = nativeEventStream.listen(_onNativeEvent);
  }

  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    await _eventSub?.cancel();
    _eventSub = null;
    await helloService.dispose();
  }

  /// Visible-for-test peer MTU lookup.
  int? mtuFor(String peerId) => _peerMtu[peerId];

  /// Visible-for-test peer role lookup ('central' | 'peripheral' | null).
  String? roleFor(String peerId) => _peerRole[peerId];

  // ── Native event demux ──────────────────────────────────────────────

  void _onNativeEvent(dynamic event) {
    if (event is! Map) return;
    final m = Map<String, dynamic>.from(event);
    final type = m['type'];
    if (type is! String) return;

    switch (type) {
      case 'peer_ready_for_hello':
        _onPeerReady(m);
        break;
      case 'gatt_mtu':
        _onMtu(m);
        break;
      case 'ble_data':
      case 'nordic_data':
        _onInboundBytes(m);
        break;
      case 'ble_peer':
        _onBlePeer(m);
        break;
    }
  }

  void _onPeerReady(Map<String, dynamic> m) {
    final peer = m['device'];
    if (peer is! String || peer.isEmpty) return;
    final mtu = (m['mtu'] as int?) ?? _defaultMtu;
    final role = (m['role'] as String?) ?? 'central';
    _peerMtu[peer] = mtu;
    _peerRole[peer] = role;
    // Fire-and-forget; HelloService writes the HELLO via _sendHelloChunks.
    unawaited(helloService.onPeerReadyForHello(peer, mtu));
  }

  void _onMtu(Map<String, dynamic> m) {
    final peer = m['device'];
    final mtu = m['mtu'];
    if (peer is String && peer.isNotEmpty && mtu is int) {
      _peerMtu[peer] = mtu;
    }
  }

  void _onInboundBytes(Map<String, dynamic> m) {
    final peer = m['device'];
    if (peer is! String || peer.isEmpty) return;
    final raw = m['data'];
    Uint8List bytes;
    if (raw is Uint8List) {
      bytes = raw;
    } else if (raw is List) {
      bytes = Uint8List.fromList(List<int>.from(raw));
    } else {
      return;
    }
    final reass = _reassemblers.putIfAbsent(
      peer,
      () => Reassembler(
        isAlreadyDispatched: (_) => false,
        isTombstoned: (_) => false,
      ),
    );
    final complete = reass.onChunk(bytes);
    if (complete == null) return;
    unawaited(
      dispatcher.onReceiveEnvelopeBytes(complete, peerId: peer),
    );
  }

  void _onBlePeer(Map<String, dynamic> m) {
    final peer = m['device'];
    final state = m['state'];
    if (peer is! String || peer.isEmpty) return;
    if (state == 'connected') return;
    _peerMtu.remove(peer);
    _peerRole.remove(peer);
    _reassemblers.remove(peer);
    helloService.onPeerDisconnected(peer);
  }

  // ── Outbound ────────────────────────────────────────────────────────

  /// Build, sign, and chunk-deliver an envelope to `peerId`. Honors the
  /// peer's capability profile (see [CapabilityProfileCatalog]).
  ///
  /// `envelopeId` (v0.3 Stage 0c wave 3F-r3) — caller MAY pre-allocate a
  /// 16-byte UUIDv7 to make the envelope id stable across restart-driven
  /// re-sends from `Outbox_V2`. When `null`, [MessagePublisherV2.send]
  /// generates a fresh UUIDv7 per call (the historical behavior — fine
  /// for immediate non-persisted publishes). Stability of the envelope id
  /// is what makes receiver-side dedup idempotent across the queue → disk
  /// → process-restart → re-drain window; see
  /// `event_publisher_v2_facade.dart` PERSISTENCE block.
  Future<TxOutcome> sendEnvelope({
    required String peerId,
    required int eventType,
    required int priority,
    required Uint8List payload,
    required HlcTimestampV2 createdAtHlc,
    required HlcTimestampV2 expiresAtHlc,
    required int maxHops,
    Uint8List? envelopeId,
    bool isExperimental = false,
  }) async {
    final state = registry.stateFor(peerId);
    if (state == null) {
      return TxOutcome.rejected('peer-not-ready', 'no registry entry');
    }
    switch (state.status) {
      case PeerCapabilityStatus.pending:
        return TxOutcome.rejected(
          'peer-not-ready',
          'HELLO handshake still in progress',
        );
      case PeerCapabilityStatus.failed:
        return TxOutcome.rejected(
          'peer-hello-failed',
          state.failureReason ?? 'HELLO validation failed',
        );
      case PeerCapabilityStatus.active:
      case PeerCapabilityStatus.legacyFallback:
        break;
    }

    final mtu = _peerMtu[peerId] ?? _defaultMtu;

    PublishedEnvelope published;
    try {
      published = await publisher.send(
        eventType: eventType,
        priority: priority,
        payload: payload,
        createdAtHlc: createdAtHlc,
        expiresAtHlc: expiresAtHlc,
        maxHops: maxHops,
        negotiatedMtu: mtu,
        envelopeId: envelopeId,
        isExperimental: isExperimental,
      );
    } on PublishRejected catch (e) {
      return TxOutcome.rejected(e.dropReason, e.detail);
    }

    final spec = CapabilityProfileCatalog.specOf(state.profile);
    if (!spec.supportsChunking && published.chunks.length > 1) {
      return TxOutcome.rejected(
        'peer-no-chunking',
        'profile=${state.profile.name} chunks=${published.chunks.length}',
      );
    }

    final sink = _sinkFor(peerId);
    for (final chunk in published.chunks) {
      final ok = await sink(peerId, chunk);
      if (!ok) {
        return TxOutcome.rejected(
          'native-write-failed',
          'chunk index in flight; remaining chunks abandoned',
        );
      }
    }
    return TxOutcome.sent(published);
  }

  // ── Internal ────────────────────────────────────────────────────────

  Future<bool> _sendHelloChunks(
      String peerId, List<Uint8List> chunks, int negotiatedMtu) async {
    final sink = _sinkFor(peerId);
    for (final c in chunks) {
      final ok = await sink(peerId, c);
      if (!ok) return false;
    }
    return true;
  }

  NativeChunkSink _sinkFor(String peerId) {
    final role = _peerRole[peerId] ?? 'central';
    return role == 'peripheral' ? notifyEventToPeer : writeEventToPeer;
  }
}
