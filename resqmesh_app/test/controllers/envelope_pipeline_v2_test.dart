// v0.3 Stage 0c — end-to-end pipeline test.
//
// Publisher signs an envelope → Dispatcher decodes + verifies → Store records
// it → Trace logs the action. Exercises the full Stage 0c spec pipeline in
// one test process (in-memory sqflite).
// ignore_for_file: prefer_const_constructors

import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ignirelay_app/app/controllers/envelope_dispatcher_v2.dart';
import 'package:ignirelay_app/app/controllers/message_publisher_v2.dart';
import 'package:ignirelay_app/app/db/database_helper.dart';
import 'package:ignirelay_app/app/proto/event_envelope_v2.dart';
import 'package:ignirelay_app/app/services/author_rate_limiter.dart';
import 'package:ignirelay_app/app/services/envelope_store_v2.dart';
import 'package:ignirelay_app/app/services/mesh_trace_writer.dart';
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

  Future<_PipelineHarness> makeHarness({
    bool enableMaxHopsOvercommit = false,
    bool enableClockBasedExpiry = false,
    Future<DateTime> Function()? now,
  }) async {
    final db = DatabaseHelper();
    final store = EnvelopeStoreV2(db);
    final trace = MeshTraceWriter(db);
    final rate = AuthorRateLimiter(capacity: 100, perSecond: 1000);
    final dispatcher = EnvelopeDispatcherV2(
      store: store,
      trace: trace,
      rateLimiter: rate,
      enableMaxHopsOvercommit: enableMaxHopsOvercommit,
      enableClockBasedExpiry: enableClockBasedExpiry,
      now: now,
    );
    final keyPair = await Ed25519().newKeyPair();
    final pub = await keyPair.extractPublicKey();
    final pubBytes = Uint8List.fromList(pub.bytes);
    final publisher = MessagePublisherV2(
      keyPair: keyPair,
      authorPublicKey: pubBytes,
      trace: trace,
    );
    return _PipelineHarness(db, store, trace, rate, dispatcher, publisher, pubBytes);
  }

  group('Publisher → Dispatcher round-trip', () {
    test('SOS_RED status update accepts cleanly', () async {
      final h = await makeHarness();
      final published = await h.publisher.send(
        eventType: EventTypeV2.statusUpdate,
        priority: PriorityV2.sosRed,
        payload: Uint8List.fromList([1, 2, 3]),
        createdAtHlc: HlcTimestampV2(msSinceEpoch: 1000, counter: 0),
        expiresAtHlc: HlcTimestampV2(msSinceEpoch: 2000, counter: 0),
        maxHops: 6,
        negotiatedMtu: 247,
      );
      final outcome = await h.dispatcher.onReceiveEnvelopeBytes(
        published.wireBytes,
        peerId: 'AA:BB:CC',
      );
      expect(outcome, isA<DispatchAccepted>());
      final accepted = outcome as DispatchAccepted;
      expect(accepted.envelope.payload, [1, 2, 3]);
      expect(accepted.envelope.priority, PriorityV2.sosRed);
      expect(accepted.downgraded, false);

      // Stored.
      final db = await h.db.database;
      final rows = await db.query('Envelopes_V2');
      expect(rows.length, 1);
      expect(rows.first['priority'], PriorityV2.sosRed);

      // Traced (sender SENT + receiver RECEIVED).
      final traces = await db.query('Mesh_Trace_Logs', orderBy: 'ts_ms ASC');
      expect(traces.length, 2);
      expect(traces[0]['action'], 0); // SENT
      expect(traces[1]['action'], 1); // RECEIVED
      expect(traces[1]['peer_id'], 'AA:BB:CC');
    });

    test('CHAT_MESSAGE on SOS_RED is rejected at sender', () async {
      final h = await makeHarness();
      expect(
        () => h.publisher.send(
          eventType: EventTypeV2.chatMessage,
          priority: PriorityV2.sosRed,
          payload: Uint8List(0),
          createdAtHlc: HlcTimestampV2(msSinceEpoch: 1, counter: 0),
          expiresAtHlc: HlcTimestampV2(msSinceEpoch: 2, counter: 0),
          maxHops: 6,
          negotiatedMtu: 247,
        ),
        throwsA(isA<PublishRejected>()
            .having((e) => e.dropReason, 'dropReason', 'priority-mismatch')),
      );
    });

    test('over-budget SOS is rejected at sender', () async {
      final h = await makeHarness();
      // 240B SOS budget — push 250B payload to exceed (envelope adds overhead).
      expect(
        () => h.publisher.send(
          eventType: EventTypeV2.statusUpdate,
          priority: PriorityV2.sosRed,
          payload: Uint8List(250),
          createdAtHlc: HlcTimestampV2(msSinceEpoch: 1, counter: 0),
          expiresAtHlc: HlcTimestampV2(msSinceEpoch: 2, counter: 0),
          maxHops: 6,
          negotiatedMtu: 247,
        ),
        throwsA(isA<PublishRejected>().having(
            (e) => e.dropReason, 'dropReason', 'over-budget-sos-rejected')),
      );
    });

    test('signature tampering trips signature-invalid at receiver', () async {
      final h = await makeHarness();
      final published = await h.publisher.send(
        eventType: EventTypeV2.statusUpdate,
        priority: PriorityV2.sosRed,
        payload: Uint8List.fromList([0xAA]),
        createdAtHlc: HlcTimestampV2(msSinceEpoch: 1, counter: 0),
        expiresAtHlc: HlcTimestampV2(msSinceEpoch: 2, counter: 0),
        maxHops: 6,
        negotiatedMtu: 247,
      );
      // Decode → tamper payload → re-encode (signature unchanged → mismatch).
      final tamperedEnv = EventEnvelopeV2.decode(published.wireBytes);
      final tampered = EventEnvelopeV2(
        envelopeId: tamperedEnv.envelopeId,
        eventType: tamperedEnv.eventType,
        priority: tamperedEnv.priority,
        createdAtHlc: tamperedEnv.createdAtHlc,
        expiresAtHlc: tamperedEnv.expiresAtHlc,
        maxHops: tamperedEnv.maxHops,
        authorKey: tamperedEnv.authorKey,
        sigAlgo: tamperedEnv.sigAlgo,
        signature: tamperedEnv.signature,
        payload: Uint8List.fromList([0xBB]), // <-- changed
        lastRelayId: tamperedEnv.lastRelayId,
        isExperimental: tamperedEnv.isExperimental,
      );
      final outcome = await h.dispatcher.onReceiveEnvelopeBytes(tampered.encode());
      expect(outcome, isA<DispatchDropped>());
      expect((outcome as DispatchDropped).dropReason, 'signature-invalid');
    });

    test('STATUS_UPDATE LWW: newer envelope wins', () async {
      final h = await makeHarness();
      // Earlier snapshot.
      final earlier = await h.publisher.send(
        eventType: EventTypeV2.statusUpdate,
        priority: PriorityV2.status,
        payload: Uint8List(0),
        createdAtHlc: HlcTimestampV2(msSinceEpoch: 100, counter: 0),
        expiresAtHlc: HlcTimestampV2(msSinceEpoch: 100000, counter: 0),
        maxHops: 6,
        negotiatedMtu: 247,
      );
      await h.dispatcher.onReceiveEnvelopeBytes(earlier.wireBytes);

      final later = await h.publisher.send(
        eventType: EventTypeV2.statusUpdate,
        priority: PriorityV2.status,
        payload: Uint8List(0),
        createdAtHlc: HlcTimestampV2(msSinceEpoch: 200, counter: 0),
        expiresAtHlc: HlcTimestampV2(msSinceEpoch: 100000, counter: 0),
        maxHops: 6,
        negotiatedMtu: 247,
      );
      final outcome = await h.dispatcher.onReceiveEnvelopeBytes(later.wireBytes);
      expect(outcome, isA<DispatchAccepted>());
      final accepted = outcome as DispatchAccepted;
      expect(accepted.isLwwWinner, true,
          reason: 'newer HLC must take the LWW slot');

      final winner =
          await h.store.currentLwwWinner(eventType: EventTypeV2.statusUpdate, lwwKeyComponent: h.authorKey);
      expect(winner, later.envelope.envelopeId);
    });

    test('rate limiter rejects the second envelope when bucket=1', () async {
      // Build a harness with capacity=1, refill=0 so the second send is rejected.
      final db = DatabaseHelper();
      final store = EnvelopeStoreV2(db);
      final trace = MeshTraceWriter(db);
      final rate = AuthorRateLimiter(capacity: 1, perSecond: 0.0);
      final dispatcher = EnvelopeDispatcherV2(
        store: store,
        trace: trace,
        rateLimiter: rate,
      );
      final keyPair = await Ed25519().newKeyPair();
      final pubBytes = Uint8List.fromList((await keyPair.extractPublicKey()).bytes);
      final publisher = MessagePublisherV2(
        keyPair: keyPair,
        authorPublicKey: pubBytes,
        trace: trace,
      );

      final first = await publisher.send(
        eventType: EventTypeV2.statusUpdate,
        priority: PriorityV2.status,
        payload: Uint8List(0),
        createdAtHlc: HlcTimestampV2(msSinceEpoch: 1, counter: 0),
        expiresAtHlc: HlcTimestampV2(msSinceEpoch: 100000, counter: 0),
        maxHops: 6,
        negotiatedMtu: 247,
      );
      final second = await publisher.send(
        eventType: EventTypeV2.statusUpdate,
        priority: PriorityV2.status,
        payload: Uint8List(0),
        createdAtHlc: HlcTimestampV2(msSinceEpoch: 2, counter: 0),
        expiresAtHlc: HlcTimestampV2(msSinceEpoch: 100000, counter: 0),
        maxHops: 6,
        negotiatedMtu: 247,
      );
      expect(await dispatcher.onReceiveEnvelopeBytes(first.wireBytes), isA<DispatchAccepted>());
      final dropped = await dispatcher.onReceiveEnvelopeBytes(second.wireBytes);
      expect(dropped, isA<DispatchDropped>());
      expect((dropped as DispatchDropped).dropReason, 'author-rate-limited');
    });
  });

  group('strict drop reasons', () {
    Future<void> expectDroppedTrace(
      _PipelineHarness h,
      String reason,
    ) async {
      final db = await h.db.database;
      final rows = await db.query(
        'Mesh_Trace_Logs',
        where: 'action = ? AND drop_reason = ?',
        whereArgs: [TraceAction.dropped, reason],
      );
      expect(rows, isNotEmpty, reason: 'trace should include drop_reason=$reason');
    }

    test('unknown-protocol-version emits DispatchDropped + trace', () async {
      final h = await makeHarness();
      final published = await h.publisher.send(
        eventType: EventTypeV2.statusUpdate,
        priority: PriorityV2.status,
        payload: Uint8List.fromList([1, 2, 3]),
        createdAtHlc: HlcTimestampV2(msSinceEpoch: 1000, counter: 0),
        expiresAtHlc: HlcTimestampV2(msSinceEpoch: 100000, counter: 0),
        maxHops: 6,
        negotiatedMtu: 247,
      );
      final env = EventEnvelopeV2.decode(published.wireBytes);
      final tampered = EventEnvelopeV2(
        protocolVersion: 3,
        envelopeId: env.envelopeId,
        eventType: env.eventType,
        priority: env.priority,
        createdAtHlc: env.createdAtHlc,
        expiresAtHlc: env.expiresAtHlc,
        maxHops: env.maxHops,
        authorKey: env.authorKey,
        sigAlgo: env.sigAlgo,
        signature: env.signature,
        payload: env.payload,
        lastRelayId: env.lastRelayId,
        isExperimental: env.isExperimental,
      );
      final outcome = await h.dispatcher.onReceiveEnvelopeBytes(tampered.encode());
      expect(outcome, isA<DispatchDropped>());
      expect((outcome as DispatchDropped).dropReason, 'unknown-protocol-version');
      await expectDroppedTrace(h, 'unknown-protocol-version');
    });

    test('envelope-expired (logical branch) emits DispatchDropped + trace',
        () async {
      final h = await makeHarness();
      final published = await h.publisher.send(
        eventType: EventTypeV2.statusUpdate,
        priority: PriorityV2.status,
        payload: Uint8List.fromList([1, 2, 3]),
        createdAtHlc: HlcTimestampV2(msSinceEpoch: 2000, counter: 0),
        expiresAtHlc: HlcTimestampV2(msSinceEpoch: 1000, counter: 0),
        maxHops: 6,
        negotiatedMtu: 247,
      );
      final outcome =
          await h.dispatcher.onReceiveEnvelopeBytes(published.wireBytes);
      expect(outcome, isA<DispatchDropped>());
      expect((outcome as DispatchDropped).dropReason, 'envelope-expired');
      await expectDroppedTrace(h, 'envelope-expired');
    });

    test('envelope-expired (clock branch) emits DispatchDropped + trace',
        () async {
      final h = await makeHarness(
        enableClockBasedExpiry: true,
        now: () async => DateTime.fromMillisecondsSinceEpoch(5000),
      );
      final published = await h.publisher.send(
        eventType: EventTypeV2.statusUpdate,
        priority: PriorityV2.status,
        payload: Uint8List.fromList([1, 2, 3]),
        createdAtHlc: HlcTimestampV2(msSinceEpoch: 1000, counter: 0),
        expiresAtHlc: HlcTimestampV2(msSinceEpoch: 2000, counter: 0),
        maxHops: 6,
        negotiatedMtu: 247,
      );
      final outcome =
          await h.dispatcher.onReceiveEnvelopeBytes(published.wireBytes);
      expect(outcome, isA<DispatchDropped>());
      expect((outcome as DispatchDropped).dropReason, 'envelope-expired');
      await expectDroppedTrace(h, 'envelope-expired');
    });

    test('dedupe-hit emits DispatchDropped + trace', () async {
      final h = await makeHarness();
      final published = await h.publisher.send(
        eventType: EventTypeV2.statusUpdate,
        priority: PriorityV2.status,
        payload: Uint8List.fromList([1, 2, 3]),
        createdAtHlc: HlcTimestampV2(msSinceEpoch: 1000, counter: 0),
        expiresAtHlc: HlcTimestampV2(msSinceEpoch: 100000, counter: 0),
        maxHops: 6,
        negotiatedMtu: 247,
      );
      expect(
        await h.dispatcher.onReceiveEnvelopeBytes(published.wireBytes),
        isA<DispatchAccepted>(),
      );
      final dup = await h.dispatcher.onReceiveEnvelopeBytes(published.wireBytes);
      expect(dup, isA<DispatchDropped>());
      expect((dup as DispatchDropped).dropReason, 'dedupe-hit');
      await expectDroppedTrace(h, 'dedupe-hit');
    });

    test('max-hops-overcommit emits DispatchDropped + trace', () async {
      final h = await makeHarness(enableMaxHopsOvercommit: true);
      final published = await h.publisher.send(
        eventType: EventTypeV2.statusUpdate,
        priority: PriorityV2.status,
        payload: Uint8List.fromList([1, 2, 3]),
        createdAtHlc: HlcTimestampV2(msSinceEpoch: 1000, counter: 0),
        expiresAtHlc: HlcTimestampV2(msSinceEpoch: 100000, counter: 0),
        maxHops: 7,
        negotiatedMtu: 247,
      );
      final outcome =
          await h.dispatcher.onReceiveEnvelopeBytes(published.wireBytes);
      expect(outcome, isA<DispatchDropped>());
      expect((outcome as DispatchDropped).dropReason, 'max-hops-overcommit');
      await expectDroppedTrace(h, 'max-hops-overcommit');
    });
  });
}

class _PipelineHarness {
  final DatabaseHelper db;
  final EnvelopeStoreV2 store;
  final MeshTraceWriter trace;
  final AuthorRateLimiter rate;
  final EnvelopeDispatcherV2 dispatcher;
  final MessagePublisherV2 publisher;
  final Uint8List authorKey;
  _PipelineHarness(this.db, this.store, this.trace, this.rate, this.dispatcher,
      this.publisher, this.authorKey);
}
