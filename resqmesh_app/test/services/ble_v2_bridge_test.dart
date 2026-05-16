// v0.3 Stage 0c wave 3B — BleV2Bridge end-to-end.
//
// Covers the wiring contract spelled out in the wave 3B scope:
//   - native `peer_ready_for_hello` event triggers ProtocolHelloService
//   - outbound HELLO chunks land in the correct native sink (write vs notify)
//     based on the peer's BLE role
//   - inbound chunk bytes route through Dart Reassembler into
//     EnvelopeDispatcherV2 with the right peerId
//   - capability gating: pending peer / failed peer / no-chunking peer
//     produce the spec drop_reasons
//   - peer disconnect evicts per-peer state
//
// ignore_for_file: prefer_const_constructors

import 'dart:async';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ignirelay_app/app/controllers/envelope_dispatcher_v2.dart';
import 'package:ignirelay_app/app/controllers/message_publisher_v2.dart';
import 'package:ignirelay_app/app/db/database_helper.dart';
import 'package:ignirelay_app/app/mesh/capability_profile.dart';
import 'package:ignirelay_app/app/mesh/mesh_constants.dart';
import 'package:ignirelay_app/app/proto/event_envelope_v2.dart';
import 'package:ignirelay_app/app/services/author_rate_limiter.dart';
import 'package:ignirelay_app/app/services/ble_v2_bridge.dart';
import 'package:ignirelay_app/app/services/envelope_store_v2.dart';
import 'package:ignirelay_app/app/services/mesh_trace_writer.dart';
import 'package:ignirelay_app/app/services/peer_capability_registry.dart';
import 'package:ignirelay_app/app/services/protocol_hello_validator.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    DatabaseHelper.testDatabasePathOverride = inMemoryDatabasePath;
  });

  setUp(() async {
    await DatabaseHelper().resetForTest();
  });

  group('BleV2Bridge', () {
    test('peer_ready_for_hello triggers HELLO send via write path (central)',
        () async {
      final h = await _makeHarness();
      h.events.add({
        'type': 'peer_ready_for_hello',
        'device': 'AA:BB',
        'mtu': 247,
        'role': 'central',
      });
      // Wait for HelloService.onPeerReadyForHello to run and dispatch chunks.
      await _drainMicrotasks();
      expect(h.writes.length, 1, reason: 'one HELLO chunk via write path');
      expect(h.writes.first.peerId, 'AA:BB');
      expect(h.notifies, isEmpty, reason: 'central-role MUST use write');
      // Bridge should remember the peer role + MTU.
      expect(h.bridge.mtuFor('AA:BB'), 247);
      expect(h.bridge.roleFor('AA:BB'), 'central');
      await h.dispose();
    });

    test('peripheral-role HELLO goes via notify path', () async {
      final h = await _makeHarness();
      h.events.add({
        'type': 'peer_ready_for_hello',
        'device': 'CC:DD',
        'mtu': 247,
        'role': 'peripheral',
      });
      await _drainMicrotasks();
      expect(h.notifies.length, 1);
      expect(h.notifies.first.peerId, 'CC:DD');
      expect(h.writes, isEmpty);
      await h.dispose();
    });

    test('inbound chunks reassemble and reach dispatcher with peerId',
        () async {
      final h = await _makeHarness();
      // Peer publishes its own envelope and emits each chunk into the bridge.
      final peerHello = ProtocolHelloData(
        peerKind: PeerKind.phoneV1,
        maxRxEnvelopeBytes: 2048,
        supportsChunking: true,
        minNegotiatedMtu: 247,
      );
      final published = await h.peerPublisher.send(
        eventType: EventTypeV2.protocolHello,
        priority: PriorityV2.normal,
        payload: peerHello.encode(),
        createdAtHlc: HlcTimestampV2(msSinceEpoch: 1000, counter: 0),
        expiresAtHlc: HlcTimestampV2(msSinceEpoch: 60000, counter: 0),
        maxHops: 1,
        negotiatedMtu: 247,
      );
      // Tell bridge the peer is ready so the registry has a pending entry.
      h.events.add({
        'type': 'peer_ready_for_hello',
        'device': 'AA:BB',
        'mtu': 247,
        'role': 'central',
      });
      await _drainMicrotasks();
      // Now feed each chunk as an inbound nordic_data event.
      for (final c in published.chunks) {
        h.events.add({
          'type': 'nordic_data',
          'device': 'AA:BB',
          'data': c.toList(),
        });
      }
      // Let the reassembler + dispatcher do their work.
      await _drainMicrotasks();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      // Peer should now be 'active' with PhoneV1 profile via the HELLO route.
      final state = h.registry.stateFor('AA:BB')!;
      expect(state.status, PeerCapabilityStatus.active);
      expect(state.profile, CapabilityProfile.phoneV1);
      await h.dispose();
    });

    test('sendEnvelope rejects peer-not-ready while HELLO pending', () async {
      final h = await _makeHarness(helloTimeout: const Duration(seconds: 30));
      h.events.add({
        'type': 'peer_ready_for_hello',
        'device': 'EE:FF',
        'mtu': 247,
        'role': 'central',
      });
      await _drainMicrotasks();
      final outcome = await h.bridge.sendEnvelope(
        peerId: 'EE:FF',
        eventType: EventTypeV2.statusUpdate,
        priority: PriorityV2.status,
        payload: Uint8List.fromList([1, 2, 3]),
        createdAtHlc: HlcTimestampV2(msSinceEpoch: 1000, counter: 0),
        expiresAtHlc: HlcTimestampV2(msSinceEpoch: 60000, counter: 0),
        maxHops: 6,
      );
      expect(outcome.sent, false);
      expect(outcome.dropReason, 'peer-not-ready');
      await h.dispose();
    });

    test('sendEnvelope rejects peer-hello-failed after self-declared legacy',
        () async {
      final h = await _makeHarness();
      h.events.add({
        'type': 'peer_ready_for_hello',
        'device': 'GG:HH',
        'mtu': 247,
        'role': 'central',
      });
      await _drainMicrotasks();
      // Peer self-declares LEGACY → bridge routes via dispatcher to registry → failed.
      final badHello = ProtocolHelloData(
        peerKind: PeerKind.phoneV1Legacy,
        maxRxEnvelopeBytes: 164,
        minNegotiatedMtu: 185,
      );
      final published = await h.peerPublisher.send(
        eventType: EventTypeV2.protocolHello,
        priority: PriorityV2.normal,
        payload: badHello.encode(),
        createdAtHlc: HlcTimestampV2(msSinceEpoch: 1000, counter: 0),
        expiresAtHlc: HlcTimestampV2(msSinceEpoch: 60000, counter: 0),
        maxHops: 1,
        negotiatedMtu: 247,
      );
      for (final c in published.chunks) {
        h.events.add({
          'type': 'nordic_data',
          'device': 'GG:HH',
          'data': c.toList(),
        });
      }
      await _drainMicrotasks();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(h.registry.stateFor('GG:HH')?.status,
          PeerCapabilityStatus.failed);
      expect(h.registry.stateFor('GG:HH')?.failureReason,
          ProtocolHelloValidator.dropSelfDeclaredLegacy);
      // Now sendEnvelope must refuse.
      final outcome = await h.bridge.sendEnvelope(
        peerId: 'GG:HH',
        eventType: EventTypeV2.statusUpdate,
        priority: PriorityV2.status,
        payload: Uint8List.fromList([1]),
        createdAtHlc: HlcTimestampV2(msSinceEpoch: 1, counter: 0),
        expiresAtHlc: HlcTimestampV2(msSinceEpoch: 60000, counter: 0),
        maxHops: 6,
      );
      expect(outcome.sent, false);
      expect(outcome.dropReason, 'peer-hello-failed');
      await h.dispose();
    });

    test('sendEnvelope rejects peer-no-chunking when BleNodeV1 + multi-chunk',
        () async {
      // Force the peer to BleNodeV1 (supportsChunking=false) and feed an
      // envelope that needs >1 chunk at the negotiated MTU.
      final h = await _makeHarness();
      h.events.add({
        'type': 'peer_ready_for_hello',
        'device': 'II:JJ',
        'mtu': 185,
        'role': 'central',
      });
      await _drainMicrotasks();
      // Peer declares BleNodeV1.
      final bleHello = ProtocolHelloData(
        peerKind: PeerKind.bleNodeV1,
        maxRxEnvelopeBytes: 226,
        supportsChunking: false,
        supportsIblt: true,
        supportsBloomV2: true,
        minNegotiatedMtu: 247,
      );
      final pubHello = await h.peerPublisher.send(
        eventType: EventTypeV2.protocolHello,
        priority: PriorityV2.normal,
        payload: bleHello.encode(),
        createdAtHlc: HlcTimestampV2(msSinceEpoch: 1000, counter: 0),
        expiresAtHlc: HlcTimestampV2(msSinceEpoch: 60000, counter: 0),
        maxHops: 1,
        negotiatedMtu: 247,
      );
      for (final c in pubHello.chunks) {
        h.events.add({
          'type': 'nordic_data',
          'device': 'II:JJ',
          'data': c.toList(),
        });
      }
      await _drainMicrotasks();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(h.registry.stateFor('II:JJ')?.profile,
          CapabilityProfile.bleNodeV1);

      // Envelope size sweet spot at MTU=185: fits SOS_RED 240B budget but
      // > 164B single-notify cap (185 - 3 ATT - 18 chunk header). A ~50B
      // payload puts the encoded envelope around ~210B → 2 chunks.
      h.writes.clear();
      final outcome = await h.bridge.sendEnvelope(
        peerId: 'II:JJ',
        eventType: EventTypeV2.statusUpdate,
        priority: PriorityV2.sosRed,
        payload: Uint8List(50),
        createdAtHlc: HlcTimestampV2(msSinceEpoch: 1000, counter: 0),
        expiresAtHlc: HlcTimestampV2(msSinceEpoch: 60000, counter: 0),
        maxHops: 6,
      );
      expect(outcome.sent, false);
      expect(outcome.dropReason, 'peer-no-chunking');
      expect(h.writes, isEmpty,
          reason: 'no chunk should hit the wire after a no-chunking reject');
      await h.dispose();
    });

    test('sendEnvelope succeeds for active PhoneV1 peer, chunks via write',
        () async {
      final h = await _makeHarness();
      h.events.add({
        'type': 'peer_ready_for_hello',
        'device': 'KK:LL',
        'mtu': 247,
        'role': 'central',
      });
      await _drainMicrotasks();
      final peerHello = ProtocolHelloData(
        peerKind: PeerKind.phoneV1,
        maxRxEnvelopeBytes: 2048,
        supportsChunking: true,
        minNegotiatedMtu: 247,
      );
      final pubHello = await h.peerPublisher.send(
        eventType: EventTypeV2.protocolHello,
        priority: PriorityV2.normal,
        payload: peerHello.encode(),
        createdAtHlc: HlcTimestampV2(msSinceEpoch: 1000, counter: 0),
        expiresAtHlc: HlcTimestampV2(msSinceEpoch: 60000, counter: 0),
        maxHops: 1,
        negotiatedMtu: 247,
      );
      for (final c in pubHello.chunks) {
        h.events.add({
          'type': 'nordic_data',
          'device': 'KK:LL',
          'data': c.toList(),
        });
      }
      await _drainMicrotasks();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      h.writes.clear();
      final outcome = await h.bridge.sendEnvelope(
        peerId: 'KK:LL',
        eventType: EventTypeV2.statusUpdate,
        priority: PriorityV2.status,
        payload: Uint8List.fromList([7, 7, 7]),
        createdAtHlc: HlcTimestampV2(msSinceEpoch: 2000, counter: 0),
        expiresAtHlc: HlcTimestampV2(msSinceEpoch: 60000, counter: 0),
        maxHops: 6,
      );
      expect(outcome.sent, true);
      expect(outcome.published, isNotNull);
      expect(h.writes.length, outcome.published!.chunks.length);
      // Reassembled bytes must round-trip back to the original envelope.
      final all = <int>[];
      for (final w in h.writes) {
        // Strip chunk header (envelope_id 16 + chunk_index 1 + total_chunks 1).
        all.addAll(w.bytes.sublist(kChunkHeaderSize));
      }
      final env = EventEnvelopeV2.decode(Uint8List.fromList(all));
      expect(env.payload, [7, 7, 7]);
      expect(env.priority, PriorityV2.status);
      await h.dispose();
    });

    test('ble_peer disconnect evicts registry + peer MTU + role', () async {
      final h = await _makeHarness();
      h.events.add({
        'type': 'peer_ready_for_hello',
        'device': 'MM:NN',
        'mtu': 247,
        'role': 'central',
      });
      await _drainMicrotasks();
      expect(h.bridge.mtuFor('MM:NN'), 247);
      expect(h.registry.stateFor('MM:NN'), isNotNull);

      h.events.add({
        'type': 'ble_peer',
        'device': 'MM:NN',
        'state': 'disconnected',
      });
      await _drainMicrotasks();
      expect(h.bridge.mtuFor('MM:NN'), isNull);
      expect(h.bridge.roleFor('MM:NN'), isNull);
      expect(h.registry.stateFor('MM:NN'), isNull);
      await h.dispose();
    });

    test('gatt_mtu updates per-peer MTU map', () async {
      final h = await _makeHarness();
      h.events.add({
        'type': 'gatt_mtu',
        'device': 'OO:PP',
        'mtu': 185,
      });
      await _drainMicrotasks();
      expect(h.bridge.mtuFor('OO:PP'), 185);
      h.events.add({
        'type': 'gatt_mtu',
        'device': 'OO:PP',
        'mtu': 247,
      });
      await _drainMicrotasks();
      expect(h.bridge.mtuFor('OO:PP'), 247);
      await h.dispose();
    });

    test('write callback returning false surfaces native-write-failed',
        () async {
      final h = await _makeHarness(writeAlwaysFails: true);
      h.events.add({
        'type': 'peer_ready_for_hello',
        'device': 'QQ:RR',
        'mtu': 247,
        'role': 'central',
      });
      await _drainMicrotasks();
      // Bring peer to active so sendEnvelope is allowed.
      final peerHello = ProtocolHelloData(
        peerKind: PeerKind.phoneV1,
        maxRxEnvelopeBytes: 2048,
        supportsChunking: true,
        minNegotiatedMtu: 247,
      );
      final pubHello = await h.peerPublisher.send(
        eventType: EventTypeV2.protocolHello,
        priority: PriorityV2.normal,
        payload: peerHello.encode(),
        createdAtHlc: HlcTimestampV2(msSinceEpoch: 1000, counter: 0),
        expiresAtHlc: HlcTimestampV2(msSinceEpoch: 60000, counter: 0),
        maxHops: 1,
        negotiatedMtu: 247,
      );
      for (final c in pubHello.chunks) {
        h.events.add({
          'type': 'nordic_data',
          'device': 'QQ:RR',
          'data': c.toList(),
        });
      }
      await _drainMicrotasks();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final outcome = await h.bridge.sendEnvelope(
        peerId: 'QQ:RR',
        eventType: EventTypeV2.statusUpdate,
        priority: PriorityV2.status,
        payload: Uint8List(0),
        createdAtHlc: HlcTimestampV2(msSinceEpoch: 2, counter: 0),
        expiresAtHlc: HlcTimestampV2(msSinceEpoch: 60000, counter: 0),
        maxHops: 6,
      );
      expect(outcome.sent, false);
      expect(outcome.dropReason, 'native-write-failed');
      await h.dispose();
    });
  });
}

class _CapturedTx {
  final String peerId;
  final Uint8List bytes;
  _CapturedTx(this.peerId, this.bytes);
}

class _Harness {
  final BleV2Bridge bridge;
  final EnvelopeDispatcherV2 dispatcher;
  final PeerCapabilityRegistry registry;
  final MessagePublisherV2 peerPublisher;
  final StreamController<dynamic> events;
  final List<_CapturedTx> writes;
  final List<_CapturedTx> notifies;

  _Harness({
    required this.bridge,
    required this.dispatcher,
    required this.registry,
    required this.peerPublisher,
    required this.events,
    required this.writes,
    required this.notifies,
  });

  Future<void> dispose() async {
    await bridge.stop();
    await dispatcher.dispose();
    await registry.dispose();
    await events.close();
  }
}

Future<_Harness> _makeHarness({
  Duration helloTimeout = const Duration(milliseconds: 200),
  bool writeAlwaysFails = false,
}) async {
  final dbHelper = DatabaseHelper();
  final store = EnvelopeStoreV2(dbHelper);
  final trace = MeshTraceWriter(dbHelper);
  final rate = AuthorRateLimiter(capacity: 100, perSecond: 1000);
  final dispatcher = EnvelopeDispatcherV2(
    store: store,
    trace: trace,
    rateLimiter: rate,
  );
  final selfKey = await Ed25519().newKeyPair();
  final selfPub =
      Uint8List.fromList((await selfKey.extractPublicKey()).bytes);
  final selfPublisher = MessagePublisherV2(
    keyPair: selfKey,
    authorPublicKey: selfPub,
    trace: trace,
  );
  final peerKey = await Ed25519().newKeyPair();
  final peerPub =
      Uint8List.fromList((await peerKey.extractPublicKey()).bytes);
  final peerPublisher = MessagePublisherV2(
    keyPair: peerKey,
    authorPublicKey: peerPub,
    trace: trace,
  );
  final registry = PeerCapabilityRegistry(helloTimeout: helloTimeout);
  final events = StreamController<dynamic>.broadcast();
  final writes = <_CapturedTx>[];
  final notifies = <_CapturedTx>[];

  final bridge = BleV2Bridge(
    store: store,
    dispatcher: dispatcher,
    publisher: selfPublisher,
    registry: registry,
    selfHelloFactory: () => ProtocolHelloData(
      peerKind: PeerKind.phoneV1,
      maxRxEnvelopeBytes: 2048,
      supportsChunking: true,
      supportsIblt: true,
      supportsBloomV2: true,
      minNegotiatedMtu: 247,
      bgState: BgState.foreground,
    ),
    nativeEventStream: events.stream,
    writeEventToPeer: (id, b) async {
      writes.add(_CapturedTx(id, b));
      return !writeAlwaysFails;
    },
    notifyEventToPeer: (id, b) async {
      notifies.add(_CapturedTx(id, b));
      return true;
    },
  );
  bridge.start();
  return _Harness(
    bridge: bridge,
    dispatcher: dispatcher,
    registry: registry,
    peerPublisher: peerPublisher,
    events: events,
    writes: writes,
    notifies: notifies,
  );
}

/// Lets the event-loop drain pending microtasks (broadcast stream listeners
/// fire asynchronously).
Future<void> _drainMicrotasks() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
