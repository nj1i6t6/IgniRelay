// V2InboundProjector — verifies accepted EventEnvelope v2 (receive path) is
// projected into the v1 Event_Logs read-model and reaches EventStream.
//
// Pipeline exercised: MessagePublisherV2 signs → EnvelopeDispatcherV2 accepts
// → V2InboundProjector translates → MeshEventHandler.ingestVerifiedEvent
// persists + projects → EventStream emits a typed event.
// ignore_for_file: prefer_const_constructors

import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ignirelay_app/app/controllers/envelope_dispatcher_v2.dart';
import 'package:ignirelay_app/app/controllers/event_stream.dart';
import 'package:ignirelay_app/app/controllers/message_publisher_v2.dart';
import 'package:ignirelay_app/app/db/database_helper.dart';
import 'package:ignirelay_app/app/mesh/event_types.dart';
import 'package:ignirelay_app/app/mesh/mesh_event_handler.dart';
import 'package:ignirelay_app/app/proto/event_envelope_v2.dart';
import 'package:ignirelay_app/app/services/author_rate_limiter.dart';
import 'package:ignirelay_app/app/services/event_decoder.dart';
import 'package:ignirelay_app/app/services/event_store.dart';
import 'package:ignirelay_app/app/services/envelope_store_v2.dart';
import 'package:ignirelay_app/app/services/mesh_trace_writer.dart';
import 'package:ignirelay_app/app/services/v2_inbound_projector.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Harness {
  final EnvelopeDispatcherV2 dispatcher;
  final MessagePublisherV2 publisher;
  final V2InboundProjector projector;
  _Harness(this.dispatcher, this.publisher, this.projector);
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    DatabaseHelper.testDatabasePathOverride = inMemoryDatabasePath;
  });

  setUp(() async {
    await DatabaseHelper().resetForTest();
  });

  Future<_Harness> makeHarness() async {
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
    final pub = await keyPair.extractPublicKey();
    final publisher = MessagePublisherV2(
      keyPair: keyPair,
      authorPublicKey: Uint8List.fromList(pub.bytes),
      trace: trace,
    );
    final projector = V2InboundProjector(
      outcomes: dispatcher.outcomes,
      handler: MeshEventHandler(),
    )..start();
    return _Harness(dispatcher, publisher, projector);
  }

  test('hazard envelope projects to Event_Logs + Hazards_State + EventStream',
      () async {
    final h = await makeHarness();
    final eventStream = EventStream(
      handler: MeshEventHandler(),
      decoder: EventDecoder(),
      store: EventStore(databaseHelper: DatabaseHelper()),
    )..start();
    final hazardFuture = eventStream.hazardEvents.first;

    final shim = utf8.encode(jsonEncode({
      'type': 'FLOOD',
      'severity': 3,
      'lat': 25.04,
      'lng': 121.56,
      'radius_m': 300.0,
      'description': '淹水',
      'schema': 'hazard_marker_v0_3_json_shim',
    }));
    final published = await h.publisher.send(
      eventType: EventTypeV2.hazardMarker,
      priority: PriorityV2.alert,
      payload: Uint8List.fromList(shim),
      createdAtHlc: HlcTimestampV2(msSinceEpoch: 1000, counter: 0),
      expiresAtHlc: HlcTimestampV2(msSinceEpoch: 2000, counter: 0),
      maxHops: 10,
      negotiatedMtu: 247,
    );

    final projectedId = h.projector.projectedEventIds.first;
    final outcome = await h.dispatcher
        .onReceiveEnvelopeBytes(published.wireBytes, peerId: 'AA:BB:CC');
    expect(outcome, isA<DispatchAccepted>());

    final eventId = await projectedId.timeout(const Duration(seconds: 2));
    final db = await DatabaseHelper().database;

    final logs = await db.query('Event_Logs',
        where: 'event_id = ?', whereArgs: [eventId]);
    expect(logs.length, 1);
    expect(logs.first['event_type'], EventType.hazardMarker);

    final hazards = await db.query('Hazards_State');
    expect(hazards.length, 1);
    expect(hazards.first['type'], 'FLOOD');
    expect(hazards.first['severity'], 3);

    final hazardEvent = await hazardFuture.timeout(const Duration(seconds: 2));
    expect(hazardEvent.type, 'FLOOD');
    expect(hazardEvent.severity, 3);
    expect(hazardEvent.lat, 25.04);

    await eventStream.dispose();
    await h.projector.dispose();
    await h.dispatcher.dispose();
  });

  test('SOS-class status update projects to a v1 SOS alert', () async {
    final h = await makeHarness();
    final eventStream = EventStream(
      handler: MeshEventHandler(),
      decoder: EventDecoder(),
      store: EventStore(databaseHelper: DatabaseHelper()),
    )..start();
    final sosFuture = eventStream.sosAlerts.first;

    final payload = StatusUpdateData(safetyState: SafetyState.trapped).encode();
    final published = await h.publisher.send(
      eventType: EventTypeV2.statusUpdate,
      priority: PriorityV2.sosRed,
      payload: payload,
      createdAtHlc: HlcTimestampV2(msSinceEpoch: 1000, counter: 0),
      expiresAtHlc: HlcTimestampV2(msSinceEpoch: 2000, counter: 0),
      maxHops: 6,
      negotiatedMtu: 247,
    );

    final projectedId = h.projector.projectedEventIds.first;
    final outcome = await h.dispatcher
        .onReceiveEnvelopeBytes(published.wireBytes, peerId: 'AA:BB:CC');
    expect(outcome, isA<DispatchAccepted>());

    final eventId = await projectedId.timeout(const Duration(seconds: 2));
    final db = await DatabaseHelper().database;
    final logs = await db.query('Event_Logs',
        where: 'event_id = ?', whereArgs: [eventId]);
    expect(logs.length, 1);
    expect(logs.first['event_type'], EventType.requestBroadcast);
    expect(logs.first['urgency'], 3);

    final sos = await sosFuture.timeout(const Duration(seconds: 2));
    expect(sos.urgency, 3);
    expect(sos.description, '受困');

    await eventStream.dispose();
    await h.projector.dispose();
    await h.dispatcher.dispose();
  });

  test('v2 projection rows are read-model only — excluded from v1 outbound',
      () async {
    final handler = MeshEventHandler();
    // A normal v1 event (no v2- prefix) and a v2 projection row.
    await handler.ingestVerifiedEvent(
      eventId: 'v1only-abc',
      eventType: EventType.hazardMarker,
      urgency: 0,
      payload: const [1],
    );
    await handler.ingestVerifiedEvent(
      eventId: '${MeshEventHandler.v2ProjectionIdPrefix}deadbeefcafe',
      eventType: EventType.hazardMarker,
      urgency: 0,
      payload: const [1],
    );

    // v1 outbound / IBLT set must NOT contain the v2 projection row.
    final outboundIds = await handler.getLocalEventIds();
    expect(outboundIds, contains('v1only-abc'));
    expect(
      outboundIds,
      isNot(contains('${MeshEventHandler.v2ProjectionIdPrefix}deadbeefcafe')),
    );

    // ...but the UI read-model (EventStore) MUST still see it.
    final store = EventStore(databaseHelper: DatabaseHelper());
    final recent = await store.queryRecent(limit: 50);
    final recentIds = recent.map((r) => r['event_id'] as String).toSet();
    expect(
      recentIds,
      contains('${MeshEventHandler.v2ProjectionIdPrefix}deadbeefcafe'),
    );
  });

  test('non-SOS status (SAFE) is not projected into the read-model', () async {
    final h = await makeHarness();
    final payload = StatusUpdateData(safetyState: SafetyState.safe).encode();
    // SAFE implies PriorityV2.status; matrix accepts STATUS_UPDATE at status.
    final published = await h.publisher.send(
      eventType: EventTypeV2.statusUpdate,
      priority: PriorityV2.status,
      payload: payload,
      createdAtHlc: HlcTimestampV2(msSinceEpoch: 1000, counter: 0),
      expiresAtHlc: HlcTimestampV2(msSinceEpoch: 2000, counter: 0),
      maxHops: 6,
      negotiatedMtu: 247,
    );
    final outcome = await h.dispatcher
        .onReceiveEnvelopeBytes(published.wireBytes, peerId: 'AA:BB:CC');
    expect(outcome, isA<DispatchAccepted>());

    // Give the async projector a chance to run, then assert nothing landed.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final db = await DatabaseHelper().database;
    final logs = await db.query('Event_Logs');
    expect(logs, isEmpty);

    await h.projector.dispose();
    await h.dispatcher.dispose();
  });
}
