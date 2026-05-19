import 'dart:collection';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ignirelay_app/app/controllers/envelope_dispatcher_v2.dart';
import 'package:ignirelay_app/app/controllers/message_publisher_v2.dart';
import 'package:ignirelay_app/app/db/database_helper.dart';
import 'package:ignirelay_app/app/proto/event_envelope_v2.dart';
import 'package:ignirelay_app/app/services/author_rate_limiter.dart';
import 'package:ignirelay_app/app/services/ble_v2_bridge.dart';
import 'package:ignirelay_app/app/services/envelope_store_v2.dart';
import 'package:ignirelay_app/app/services/event_publisher_v2_facade.dart';
import 'package:ignirelay_app/app/services/mesh_trace_writer.dart';
import 'package:ignirelay_app/app/services/peer_capability_registry.dart';
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

  test('queues when bridge is absent, then drains after attach + active peer',
      () async {
    final registry = PeerCapabilityRegistry(
      helloTimeout: const Duration(seconds: 5),
    );
    final facade = EventPublisherV2Facade(registry: registry);
    addTearDown(() async {
      await facade.dispose();
      await registry.dispose();
    });

    final queued =
        await facade.publishChatMessage(payload: Uint8List.fromList([1]));
    expect(queued.queued, isTrue);
    expect(facade.pendingQueueDepth, 1);

    final bridge = await _makeRecordingBridge(registry);
    facade.attachBridge(bridge);
    await _drainMicrotasks();
    expect(bridge.invocations, isEmpty);
    expect(facade.pendingQueueDepth, 1);

    _markPeerActive(registry, 'AA:BB');
    await _drainMicrotasks();
    expect(bridge.invocations.length, 1);
    expect(bridge.invocations.single.peerId, 'AA:BB');
    expect(bridge.invocations.single.eventType, EventTypeV2.chatMessage);
    expect(facade.pendingQueueDepth, 0);
  });

  test('queues when no active peers, then drains on peer-ready transition',
      () async {
    final registry = PeerCapabilityRegistry(
      helloTimeout: const Duration(seconds: 5),
    );
    final bridge = await _makeRecordingBridge(registry);
    final facade = EventPublisherV2Facade(
      registry: registry,
      bridge: bridge,
    );
    addTearDown(() async {
      await facade.dispose();
      await registry.dispose();
    });

    final queued = await facade.publishStatusUpdate(
      safetyState: SafetyState.safe,
    );
    expect(queued.queued, isTrue);
    expect(facade.pendingQueueDepth, 1);
    expect(bridge.invocations, isEmpty);

    _markPeerActive(registry, 'CC:DD');
    await _drainMicrotasks();
    expect(bridge.invocations.length, 1);
    expect(bridge.invocations.single.peerId, 'CC:DD');
    expect(bridge.invocations.single.eventType, EventTypeV2.statusUpdate);
    expect(facade.pendingQueueDepth, 0);
  });

  test('pending queue cap keeps newest entries (drops oldest FIFO)', () async {
    final registry = PeerCapabilityRegistry(
      helloTimeout: const Duration(seconds: 5),
    );
    final facade = EventPublisherV2Facade(registry: registry);
    addTearDown(() async {
      await facade.dispose();
      await registry.dispose();
    });

    const cap = EventPublisherV2Facade.kMaxPendingEntries;
    const total = cap + 3;
    for (var i = 0; i < total; i++) {
      await facade.publishChatMessage(
        payload: Uint8List.fromList([i % 256]),
      );
    }
    expect(facade.pendingQueueDepth, cap);

    final bridge = await _makeRecordingBridge(registry);
    _markPeerActive(registry, 'EE:FF');
    facade.attachBridge(bridge);
    await _drainMicrotasks();

    expect(bridge.invocations.length, cap);
    expect(bridge.invocations.first.payload.single, (total - cap) % 256);
    expect(bridge.invocations.last.payload.single, (total - 1) % 256);
    expect(facade.pendingQueueDepth, 0);
  });

  test('drain drops stale entries via pending TTL/age guard', () async {
    DateTime fakeNow = DateTime.now();
    final registry = PeerCapabilityRegistry(
      helloTimeout: const Duration(seconds: 5),
    );
    final facade = EventPublisherV2Facade(
      registry: registry,
      now: () => fakeNow,
    );
    addTearDown(() async {
      await facade.dispose();
      await registry.dispose();
    });

    await facade.publishStatusUpdate(
      safetyState: SafetyState.safe,
    );
    expect(facade.pendingQueueDepth, 1);

    fakeNow = fakeNow.add(const Duration(hours: 25));
    final bridge = await _makeRecordingBridge(registry);
    _markPeerActive(registry, 'GG:HH');
    facade.attachBridge(bridge);
    await _drainMicrotasks();

    expect(bridge.invocations, isEmpty,
        reason: 'stale pending entries should be dropped before send');
    expect(facade.pendingQueueDepth, 0);
  });

  test('Outbox_V2 persists queued row with pre-allocated envelope_id',
      () async {
    final db = DatabaseHelper();
    final registry = PeerCapabilityRegistry(
      helloTimeout: const Duration(seconds: 5),
    );
    final expectedEnvelopeId = _filledEnvelopeId(0x2A);
    final facade = EventPublisherV2Facade(
      registry: registry,
      db: db,
      envelopeIdFactory: () => Uint8List.fromList(expectedEnvelopeId),
    );
    addTearDown(() async {
      await facade.dispose();
      await registry.dispose();
    });

    final queued = await facade.publishChatMessage(
      payload: Uint8List.fromList([0x7A]),
    );
    expect(queued.queued, isTrue);

    final rows = await _waitForOutboxRowCount(db, 1);
    expect(rows.single['event_type'], EventTypeV2.chatMessage);
    expect(
      Uint8List.fromList(rows.single['envelope_id'] as List<int>),
      orderedEquals(expectedEnvelopeId),
    );
  });

  test(
      'restart hydrate re-drain reuses persisted envelope_id and clears Outbox_V2 row',
      () async {
    final db = DatabaseHelper();
    final firstRegistry = PeerCapabilityRegistry(
      helloTimeout: const Duration(seconds: 5),
    );
    final persistedEnvelopeId = _filledEnvelopeId(0x33);
    final firstFacade = EventPublisherV2Facade(
      registry: firstRegistry,
      db: db,
      envelopeIdFactory: () => Uint8List.fromList(persistedEnvelopeId),
    );

    final queued = await firstFacade.publishStatusUpdate(
      safetyState: SafetyState.safe,
    );
    expect(queued.queued, isTrue);

    final queuedRows = await _waitForOutboxRowCount(db, 1);
    expect(
      Uint8List.fromList(queuedRows.single['envelope_id'] as List<int>),
      orderedEquals(persistedEnvelopeId),
    );

    await firstFacade.dispose();
    await firstRegistry.dispose();

    final secondRegistry = PeerCapabilityRegistry(
      helloTimeout: const Duration(seconds: 5),
    );
    final bridge = await _makeRecordingBridge(secondRegistry);
    final secondFacade = EventPublisherV2Facade(
      registry: secondRegistry,
      db: db,
      envelopeIdFactory: () => _filledEnvelopeId(0x99),
    );
    addTearDown(() async {
      await secondFacade.dispose();
      await secondRegistry.dispose();
    });

    await secondFacade.hydrationDone;
    expect(secondFacade.pendingQueueDepth, 1);

    secondFacade.attachBridge(bridge);
    _markPeerActive(secondRegistry, 'RM:01');
    await _drainMicrotasks();

    expect(bridge.invocations.length, 1);
    expect(
      bridge.invocations.single.envelopeId,
      isNotNull,
      reason: 'drain must pass persisted envelope_id to bridge sendEnvelope',
    );
    expect(
      bridge.invocations.single.envelopeId!,
      orderedEquals(persistedEnvelopeId),
    );

    await _waitForOutboxRowCount(db, 0);
    expect(secondFacade.pendingQueueDepth, 0);
  });

  test('hydrate prunes stale/expired Outbox_V2 rows and does not send them',
      () async {
    final db = DatabaseHelper();
    final fakeNow = DateTime.fromMillisecondsSinceEpoch(1900000000000);
    await _insertOutboxRow(
      db: db,
      envelopeId: _filledEnvelopeId(0x41),
      eventType: EventTypeV2.chatMessage,
      priority: PriorityV2.normal,
      payload: Uint8List.fromList([1]),
      createdAtHlcMs:
          fakeNow.subtract(const Duration(hours: 26)).millisecondsSinceEpoch,
      expiresAtHlcMs:
          fakeNow.add(const Duration(hours: 1)).millisecondsSinceEpoch,
      enqueuedAtMs:
          fakeNow.subtract(const Duration(hours: 25)).millisecondsSinceEpoch,
      maxHops: 6,
    );
    await _insertOutboxRow(
      db: db,
      envelopeId: _filledEnvelopeId(0x42),
      eventType: EventTypeV2.statusUpdate,
      priority: PriorityV2.status,
      payload: Uint8List.fromList([2]),
      createdAtHlcMs:
          fakeNow.subtract(const Duration(minutes: 2)).millisecondsSinceEpoch,
      expiresAtHlcMs:
          fakeNow.subtract(const Duration(seconds: 1)).millisecondsSinceEpoch,
      enqueuedAtMs:
          fakeNow.subtract(const Duration(minutes: 1)).millisecondsSinceEpoch,
      maxHops: 6,
    );

    final registry = PeerCapabilityRegistry(
      helloTimeout: const Duration(seconds: 5),
    );
    final bridge = await _makeRecordingBridge(registry);
    final facade = EventPublisherV2Facade(
      registry: registry,
      db: db,
      now: () => fakeNow,
    );
    addTearDown(() async {
      await facade.dispose();
      await registry.dispose();
    });

    await facade.hydrationDone;
    expect(facade.pendingQueueDepth, 0);
    await _waitForOutboxRowCount(db, 0);

    facade.attachBridge(bridge);
    _markPeerActive(registry, 'RM:02');
    await _drainMicrotasks();
    expect(bridge.invocations, isEmpty);
  });

  test('publishStatusUpdate applies impliedPriorityFloor', () async {
    final registry = PeerCapabilityRegistry(
      helloTimeout: const Duration(seconds: 5),
    );
    final bridge = await _makeRecordingBridge(registry);
    final facade = EventPublisherV2Facade(
      registry: registry,
      bridge: bridge,
    );
    addTearDown(() async {
      await facade.dispose();
      await registry.dispose();
    });
    _markPeerActive(registry, 'II:JJ');

    await facade.publishStatusUpdate(
      safetyState: SafetyState.safe,
      priority: PriorityV2.normal,
    );
    await facade.publishStatusUpdate(
      safetyState: SafetyState.injured,
      priority: PriorityV2.status,
    );
    await facade.publishStatusUpdate(
      safetyState: SafetyState.safe,
      priority: PriorityV2.status,
      needs: const [
        NeedEntry(
          category: NeedCategory.water,
          severity: NeedSeverity.urgent,
          expiresAtHlc: HlcTimestampV2(msSinceEpoch: 1, counter: 0),
        ),
      ],
    );
    await facade.publishStatusUpdate(
      safetyState: SafetyState.trapped,
      priority: PriorityV2.status,
    );

    expect(bridge.invocations.length, 4);
    expect(bridge.invocations[0].priority, PriorityV2.status,
        reason: 'SAFE should floor at STATUS');
    expect(bridge.invocations[1].priority, PriorityV2.sosYellow,
        reason: 'INJURED should floor at SOS_YELLOW');
    expect(bridge.invocations[2].priority, PriorityV2.sosYellow,
        reason: 'urgent need should floor at SOS_YELLOW');
    expect(bridge.invocations[3].priority, PriorityV2.sosRed,
        reason: 'TRAPPED should floor at SOS_RED');
  });

  test('publishSosStatus routes through status publish and keeps SOS_RED floor',
      () async {
    final registry = PeerCapabilityRegistry(
      helloTimeout: const Duration(seconds: 5),
    );
    final bridge = await _makeRecordingBridge(registry);
    final facade = EventPublisherV2Facade(
      registry: registry,
      bridge: bridge,
    );
    addTearDown(() async {
      await facade.dispose();
      await registry.dispose();
    });
    _markPeerActive(registry, 'KK:LL');

    await facade.publishSosStatus(safetyState: SafetyState.safe);
    await facade.publishSosStatus(safetyState: SafetyState.trapped);

    expect(bridge.invocations.length, 2);
    for (final call in bridge.invocations) {
      expect(call.eventType, EventTypeV2.statusUpdate);
      expect(call.priority, PriorityV2.sosRed);
      final payload = StatusUpdateData.decode(call.payload);
      expect(
        payload.safetyState == SafetyState.safe ||
            payload.safetyState == SafetyState.trapped,
        isTrue,
      );
    }
  });
}

class _SendInvocation {
  final String peerId;
  final Uint8List? envelopeId;
  final int eventType;
  final int priority;
  final Uint8List payload;
  final HlcTimestampV2 createdAtHlc;
  final HlcTimestampV2 expiresAtHlc;
  final int maxHops;

  _SendInvocation({
    required this.peerId,
    required this.envelopeId,
    required this.eventType,
    required this.priority,
    required this.payload,
    required this.createdAtHlc,
    required this.expiresAtHlc,
    required this.maxHops,
  });
}

class _RecordingBleV2Bridge extends BleV2Bridge {
  final List<_SendInvocation> invocations = <_SendInvocation>[];
  final ListQueue<TxOutcome> scriptedOutcomes = ListQueue<TxOutcome>();
  int _nextId = 1;

  _RecordingBleV2Bridge({
    required super.store,
    required super.dispatcher,
    required super.publisher,
    required super.registry,
    required super.selfHelloFactory,
    required super.nativeEventStream,
    required super.writeEventToPeer,
    required super.notifyEventToPeer,
  });

  @override
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
    invocations.add(_SendInvocation(
      peerId: peerId,
      envelopeId:
          envelopeId == null ? null : Uint8List.fromList(envelopeId),
      eventType: eventType,
      priority: priority,
      payload: Uint8List.fromList(payload),
      createdAtHlc: createdAtHlc,
      expiresAtHlc: expiresAtHlc,
      maxHops: maxHops,
    ));
    if (scriptedOutcomes.isNotEmpty) {
      return scriptedOutcomes.removeFirst();
    }
    final id = (_nextId++ % 255) + 1;
    final envelope = EventEnvelopeV2(
      envelopeId: Uint8List.fromList(List<int>.filled(16, id)),
      eventType: eventType,
      priority: priority,
      createdAtHlc: createdAtHlc,
      expiresAtHlc: expiresAtHlc,
      maxHops: maxHops,
      authorKey: Uint8List(32),
      sigAlgo: SigAlgo.ed25519,
      signature: Uint8List(64),
      payload: Uint8List.fromList(payload),
      isExperimental: isExperimental,
    );
    final wire = envelope.encode();
    return TxOutcome.sent(PublishedEnvelope(
      envelope: envelope,
      wireBytes: wire,
      chunks: const <Uint8List>[],
      negotiatedMtu: 247,
      effectivePriority: priority,
    ));
  }
}

Future<_RecordingBleV2Bridge> _makeRecordingBridge(
  PeerCapabilityRegistry registry,
) async {
  final db = DatabaseHelper();
  final store = EnvelopeStoreV2(db);
  final trace = MeshTraceWriter(db);
  final rate = AuthorRateLimiter(capacity: 100, perSecond: 1000);
  final dispatcher = EnvelopeDispatcherV2(
    store: store,
    trace: trace,
    rateLimiter: rate,
  );
  final keyPair = await Ed25519().newKeyPair();
  final authorPublicKey =
      Uint8List.fromList((await keyPair.extractPublicKey()).bytes);
  final publisher = MessagePublisherV2(
    keyPair: keyPair,
    authorPublicKey: authorPublicKey,
    trace: trace,
  );

  return _RecordingBleV2Bridge(
    store: store,
    dispatcher: dispatcher,
    publisher: publisher,
    registry: registry,
    selfHelloFactory: () => const ProtocolHelloData(
      peerKind: PeerKind.phoneV1,
      maxRxEnvelopeBytes: 2048,
      supportsChunking: true,
      supportsIblt: true,
      supportsBloomV2: true,
      minNegotiatedMtu: 247,
      bgState: BgState.foreground,
    ),
    nativeEventStream: const Stream<dynamic>.empty(),
    writeEventToPeer: (_, __) async => true,
    notifyEventToPeer: (_, __) async => true,
  );
}

Uint8List _filledEnvelopeId(int byte) =>
    Uint8List.fromList(List<int>.filled(16, byte));

Future<List<Map<String, Object?>>> _queryOutboxRows(DatabaseHelper db) async {
  final database = await db.database;
  return database.query('Outbox_V2', orderBy: 'id ASC');
}

Future<List<Map<String, Object?>>> _waitForOutboxRowCount(
  DatabaseHelper db,
  int expectedCount,
) async {
  for (var i = 0; i < 20; i++) {
    final rows = await _queryOutboxRows(db);
    if (rows.length == expectedCount) {
      return rows;
    }
    await _drainMicrotasks();
  }
  final rows = await _queryOutboxRows(db);
  expect(rows, hasLength(expectedCount));
  return rows;
}

Future<void> _insertOutboxRow({
  required DatabaseHelper db,
  required Uint8List envelopeId,
  required int eventType,
  required int priority,
  required Uint8List payload,
  required int createdAtHlcMs,
  required int expiresAtHlcMs,
  required int enqueuedAtMs,
  required int maxHops,
}) async {
  final database = await db.database;
  await database.insert('Outbox_V2', {
    'envelope_id': envelopeId,
    'event_type': eventType,
    'priority': priority,
    'payload': payload,
    'created_at_hlc_ms': createdAtHlcMs,
    'created_at_hlc_ctr': 0,
    'expires_at_hlc_ms': expiresAtHlcMs,
    'expires_at_hlc_ctr': 0,
    'max_hops': maxHops,
    'enqueued_at_ms': enqueuedAtMs,
  });
}

void _markPeerActive(PeerCapabilityRegistry registry, String peerId) {
  registry.onPeerReadyForHello(peerId);
  registry.onHelloAccepted(
    peerId,
    const ProtocolHelloData(
      peerKind: PeerKind.phoneV1,
      maxRxEnvelopeBytes: 2048,
      supportsChunking: true,
      supportsIblt: true,
      supportsBloomV2: true,
      minNegotiatedMtu: 247,
      bgState: BgState.foreground,
    ).encode(),
  );
}

Future<void> _drainMicrotasks() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
