// v0.3 Stage 0c wave 3A — PROTOCOL_HELLO state machine + validator + service.
//
// Covers spec native_transport_v1 §5.2, §5.7, §6.2, §15.9:
//   - Valid HELLO transitions to active(profile)
//   - 5 s timeout transitions to legacyFallback(PhoneV1-legacy)
//   - Malformed payload transitions to failed
//   - Explicit PHONE_V1_LEGACY transitions to failed (hello-self-declared-legacy)
//   - Service round-trip via real publisher + dispatcher
//
// ignore_for_file: prefer_const_constructors

import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ignirelay_app/app/controllers/envelope_dispatcher_v2.dart';
import 'package:ignirelay_app/app/controllers/message_publisher_v2.dart';
import 'package:ignirelay_app/app/db/database_helper.dart';
import 'package:ignirelay_app/app/mesh/capability_profile.dart';
import 'package:ignirelay_app/app/mesh/reassembler.dart';
import 'package:ignirelay_app/app/proto/event_envelope_v2.dart';
import 'package:ignirelay_app/app/services/author_rate_limiter.dart';
import 'package:ignirelay_app/app/services/envelope_store_v2.dart';
import 'package:ignirelay_app/app/services/mesh_trace_writer.dart';
import 'package:ignirelay_app/app/services/peer_capability_registry.dart';
import 'package:ignirelay_app/app/services/protocol_hello_service.dart';
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

  // ── 1. Validator (pure) ───────────────────────────────────────────────

  group('ProtocolHelloValidator', () {
    test('valid PhoneV1 HELLO is accepted with PhoneV1 profile', () {
      final hello = ProtocolHelloData(
        peerKind: PeerKind.phoneV1,
        maxRxEnvelopeBytes: 2048,
        supportsIblt: true,
        supportsBloomV2: true,
        supportsChunking: true,
        minNegotiatedMtu: 247,
      );
      final result = ProtocolHelloValidator.validate(hello.encode());
      expect(result.isAccepted, true);
      expect(result.profile, CapabilityProfile.phoneV1);
      expect(result.hello?.peerKind, PeerKind.phoneV1);
    });

    test('BleNodeV1 and Tier0Mule map to their profiles', () {
      for (final pair in const [
        (PeerKind.bleNodeV1, CapabilityProfile.bleNodeV1),
        (PeerKind.tier0Mule, CapabilityProfile.tier0Mule),
      ]) {
        final hello = ProtocolHelloData(
          peerKind: pair.$1,
          maxRxEnvelopeBytes: 2048,
          minNegotiatedMtu: 247,
        );
        final result = ProtocolHelloValidator.validate(hello.encode());
        expect(result.isAccepted, true, reason: 'kind=${pair.$1}');
        expect(result.profile, pair.$2);
      }
    });

    test('explicit PHONE_V1_LEGACY drops with hello-self-declared-legacy', () {
      final hello = ProtocolHelloData(
        peerKind: PeerKind.phoneV1Legacy,
        maxRxEnvelopeBytes: 164,
        minNegotiatedMtu: 185,
      );
      final result = ProtocolHelloValidator.validate(hello.encode());
      expect(result.isAccepted, false);
      expect(result.dropReason, ProtocolHelloValidator.dropSelfDeclaredLegacy);
    });

    test('UNSPECIFIED peer_kind drops with hello-payload-invalid', () {
      final hello = ProtocolHelloData(
        peerKind: PeerKind.unspecified,
        maxRxEnvelopeBytes: 0,
        minNegotiatedMtu: 0,
      );
      final result = ProtocolHelloValidator.validate(hello.encode());
      expect(result.isAccepted, false);
      expect(result.dropReason, ProtocolHelloValidator.dropPayloadInvalid);
    });

    test('protocol_version != 2 drops with hello-protocol-version-incompatible',
        () {
      final hello = ProtocolHelloData(
        protocolVersion: 1,
        peerKind: PeerKind.phoneV1,
        maxRxEnvelopeBytes: 2048,
        minNegotiatedMtu: 247,
      );
      final result = ProtocolHelloValidator.validate(hello.encode());
      expect(result.isAccepted, false);
      expect(
          result.dropReason, ProtocolHelloValidator.dropProtocolIncompatible);
    });

    test('unknown peer_kind value drops with hello-payload-invalid', () {
      // 99 is not in PeerKind enum; encode manually-shaped HELLO using a
      // forward-compat value the decoder will surface as-is.
      final hello = ProtocolHelloData(
        peerKind: 99,
        maxRxEnvelopeBytes: 2048,
        minNegotiatedMtu: 247,
      );
      final result = ProtocolHelloValidator.validate(hello.encode());
      expect(result.isAccepted, false);
      expect(result.dropReason, ProtocolHelloValidator.dropPayloadInvalid);
    });

    test('garbage bytes drop with hello-payload-invalid', () {
      // proto3 decoder tolerates many shapes; force a true parse error by
      // emitting a varint tag with no body (length-delimited field truncation).
      final result = ProtocolHelloValidator.validate(
        Uint8List.fromList([0x0A, 0xFF, 0xFF]),
      );
      expect(result.isAccepted, false);
      expect(result.dropReason, ProtocolHelloValidator.dropPayloadInvalid);
    });
  });

  // ── 2. PeerCapabilityRegistry state machine ──────────────────────────

  group('PeerCapabilityRegistry', () {
    test('initial pending state on onPeerReadyForHello', () {
      final reg = PeerCapabilityRegistry(
        helloTimeout: const Duration(seconds: 5),
      );
      reg.onPeerReadyForHello('AA:BB');
      final s = reg.stateFor('AA:BB')!;
      expect(s.status, PeerCapabilityStatus.pending);
      expect(s.profile, CapabilityProfile.phoneV1Legacy);
      expect(s.isReadyForTraffic, false);
    });

    test('timeout transitions to legacyFallback (PhoneV1-legacy)', () async {
      final reg = PeerCapabilityRegistry(
        helloTimeout: const Duration(milliseconds: 30),
      );
      reg.onPeerReadyForHello('AA:BB');

      // Wait past timer.
      await Future<void>.delayed(const Duration(milliseconds: 80));

      final s = reg.stateFor('AA:BB')!;
      expect(s.status, PeerCapabilityStatus.legacyFallback);
      expect(s.profile, CapabilityProfile.phoneV1Legacy);
      expect(s.isReadyForTraffic, true);
    });

    test('valid HELLO before timeout cancels timer and sets active', () async {
      final reg = PeerCapabilityRegistry(
        helloTimeout: const Duration(milliseconds: 200),
      );
      reg.onPeerReadyForHello('AA:BB');
      final hello = ProtocolHelloData(
        peerKind: PeerKind.phoneV1,
        maxRxEnvelopeBytes: 2048,
        minNegotiatedMtu: 247,
        supportsChunking: true,
      );
      final result = reg.onHelloAccepted('AA:BB', hello.encode());
      expect(result.isAccepted, true);
      final s = reg.stateFor('AA:BB')!;
      expect(s.status, PeerCapabilityStatus.active);
      expect(s.profile, CapabilityProfile.phoneV1);
      expect(s.hello?.peerKind, PeerKind.phoneV1);

      // Even if we wait past the original timeout, status stays active.
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(reg.stateFor('AA:BB')!.status, PeerCapabilityStatus.active);
    });

    test('invalid HELLO (self-declared legacy) transitions to failed', () {
      final reg = PeerCapabilityRegistry(
        helloTimeout: const Duration(seconds: 5),
      );
      reg.onPeerReadyForHello('CC:DD');
      final hello = ProtocolHelloData(
        peerKind: PeerKind.phoneV1Legacy,
        maxRxEnvelopeBytes: 164,
        minNegotiatedMtu: 185,
      );
      final result = reg.onHelloAccepted('CC:DD', hello.encode());
      expect(result.isAccepted, false);
      expect(
          result.dropReason, ProtocolHelloValidator.dropSelfDeclaredLegacy);
      final s = reg.stateFor('CC:DD')!;
      expect(s.status, PeerCapabilityStatus.failed);
      expect(s.failureReason,
          ProtocolHelloValidator.dropSelfDeclaredLegacy);
      expect(s.profile, CapabilityProfile.phoneV1Legacy);
    });

    test('disconnect evicts state', () {
      final reg = PeerCapabilityRegistry(
        helloTimeout: const Duration(seconds: 5),
      );
      reg.onPeerReadyForHello('EE:FF');
      expect(reg.stateFor('EE:FF'), isNotNull);
      reg.onPeerDisconnected('EE:FF');
      expect(reg.stateFor('EE:FF'), isNull);
    });

    test('re-arming onPeerReadyForHello cancels prior timer', () async {
      final reg = PeerCapabilityRegistry(
        helloTimeout: const Duration(milliseconds: 30),
      );
      reg.onPeerReadyForHello('GG:HH');
      // Re-arm with same key — second call should reset state and timer.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      reg.onPeerReadyForHello('GG:HH');
      // First timer (which started ~10ms ago) would have fired at 30ms;
      // the second timer (just started) fires at 40ms total. Check at 60ms
      // that we're in legacyFallback (proves the timer fired, not skipped).
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(reg.stateFor('GG:HH')?.status,
          PeerCapabilityStatus.legacyFallback);
    });

    test('changes stream emits on every transition', () async {
      final reg = PeerCapabilityRegistry(
        helloTimeout: const Duration(milliseconds: 30),
      );
      final transitions = <PeerCapabilityStatus>[];
      final sub = reg.changes.listen((s) => transitions.add(s.status));
      reg.onPeerReadyForHello('II:JJ');
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await sub.cancel();
      expect(transitions, [
        PeerCapabilityStatus.pending,
        PeerCapabilityStatus.legacyFallback,
      ]);
    });
  });

  // ── 3. buildSelfHello guards ─────────────────────────────────────────

  group('buildSelfHello', () {
    test('rejects PHONE_V1_LEGACY self-advertisement', () {
      expect(
        () => buildSelfHello(
          peerKind: PeerKind.phoneV1Legacy,
          maxRxEnvelopeBytes: 164,
          supportsIblt: false,
          supportsBloomV2: false,
          supportsChunking: false,
          minNegotiatedMtu: 185,
          bgState: BgState.foreground,
        ),
        throwsArgumentError,
      );
    });

    test('rejects UNSPECIFIED peer kind', () {
      expect(
        () => buildSelfHello(
          peerKind: PeerKind.unspecified,
          maxRxEnvelopeBytes: 0,
          supportsIblt: false,
          supportsBloomV2: false,
          supportsChunking: false,
          minNegotiatedMtu: 23,
          bgState: BgState.foreground,
        ),
        throwsArgumentError,
      );
    });

    test('builds a PhoneV1 HELLO with declared fields', () {
      final hello = buildSelfHello(
        peerKind: PeerKind.phoneV1,
        maxRxEnvelopeBytes: 2048,
        supportsIblt: true,
        supportsBloomV2: true,
        supportsChunking: true,
        minNegotiatedMtu: 247,
        bgState: BgState.foreground,
        capabilities: ['shelter_status'],
      );
      expect(hello.peerKind, PeerKind.phoneV1);
      expect(hello.supportsChunking, true);
      expect(hello.minNegotiatedMtu, 247);
      expect(hello.capabilities, ['shelter_status']);
    });
  });

  // ── 4. ProtocolHelloService end-to-end ────────────────────────────────

  group('ProtocolHelloService', () {
    Future<_HelloHarness> makeHarness({
      Duration helloTimeout = const Duration(milliseconds: 200),
      bool enableMaxHopsOvercommit = false,
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
      );
      final selfKey = await Ed25519().newKeyPair();
      final selfPub =
          Uint8List.fromList((await selfKey.extractPublicKey()).bytes);
      final publisher = MessagePublisherV2(
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

      final registry =
          PeerCapabilityRegistry(helloTimeout: helloTimeout);
      final sent = <_SentChunkBatch>[];
      final service = ProtocolHelloService(
        publisher: publisher,
        registry: registry,
        sendChunks: (peerId, chunks, mtu) async {
          sent.add(_SentChunkBatch(peerId, chunks, mtu));
          return true;
        },
        selfHelloFactory: () => ProtocolHelloData(
          peerKind: PeerKind.phoneV1,
          maxRxEnvelopeBytes: 2048,
          supportsIblt: true,
          supportsBloomV2: true,
          supportsChunking: true,
          minNegotiatedMtu: 247,
          bgState: BgState.foreground,
        ),
      );
      service.attachDispatcher(dispatcher);
      return _HelloHarness(
        db, store, trace, rate, dispatcher, peerPublisher, registry, service,
        sent,
      );
    }

    test('onPeerReadyForHello sends our HELLO via transport', () async {
      final h = await makeHarness();
      await h.service.onPeerReadyForHello('AA:BB', 247);
      expect(h.sentChunks.length, 1);
      expect(h.sentChunks.first.peerId, 'AA:BB');
      expect(h.sentChunks.first.mtu, 247);
      // 240B HELLO fits in one chunk on MTU=247 (cap = 226 B; HELLO < 100B).
      expect(h.sentChunks.first.chunks.length, 1);
      await h.dispose();
    });

    test('outgoing HELLO uses maxHops=0', () async {
      final h = await makeHarness();
      await h.service.onPeerReadyForHello('AA:BB', 247);
      final sent = h.sentChunks.single.chunks;
      final reassembler = Reassembler(
        isAlreadyDispatched: (_) => false,
        isTombstoned: (_) => false,
      );
      Uint8List? wire;
      for (final chunk in sent) {
        wire = reassembler.onChunk(chunk);
      }
      expect(wire, isNotNull);
      final env = EventEnvelopeV2.decode(wire!);
      expect(env.eventType, EventTypeV2.protocolHello);
      expect(env.maxHops, 0);
      await h.dispose();
    });

    test('valid peer HELLO via dispatcher → registry active(PhoneV1)',
        () async {
      final h = await makeHarness();
      await h.service.onPeerReadyForHello('AA:BB', 247);

      // Peer publishes its HELLO under PhoneV1.
      final peerHello = ProtocolHelloData(
        peerKind: PeerKind.phoneV1,
        maxRxEnvelopeBytes: 2048,
        supportsIblt: true,
        supportsBloomV2: true,
        supportsChunking: true,
        minNegotiatedMtu: 247,
      );
      final published = await h.peerPublisher.send(
        eventType: EventTypeV2.protocolHello,
        priority: PriorityV2.normal,
        payload: peerHello.encode(),
        createdAtHlc: HlcTimestampV2(msSinceEpoch: 1000, counter: 0),
        expiresAtHlc: HlcTimestampV2(msSinceEpoch: 60000, counter: 0),
        maxHops: 0,
        negotiatedMtu: 247,
      );

      // Receive via dispatcher (it emits onto outcomes → service routes to
      // registry).
      final outcome = await h.dispatcher.onReceiveEnvelopeBytes(
        published.wireBytes,
        peerId: 'AA:BB',
      );
      expect(outcome, isA<DispatchAccepted>());

      // Give the broadcast stream a microtask to flush.
      await Future<void>.delayed(const Duration(milliseconds: 5));

      final state = h.registry.stateFor('AA:BB')!;
      expect(state.status, PeerCapabilityStatus.active);
      expect(state.profile, CapabilityProfile.phoneV1);
      await h.dispose();
    });

    test('peer never sends HELLO → 5 s fallback (legacy)', () async {
      final h = await makeHarness(
        helloTimeout: const Duration(milliseconds: 40),
      );
      await h.service.onPeerReadyForHello('AA:BB', 247);
      await Future<void>.delayed(const Duration(milliseconds: 90));
      final state = h.registry.stateFor('AA:BB')!;
      expect(state.status, PeerCapabilityStatus.legacyFallback);
      expect(state.profile, CapabilityProfile.phoneV1Legacy);
      await h.dispose();
    });

    test('peer self-declares LEGACY → failed (drop connection signal)',
        () async {
      final h = await makeHarness();
      await h.service.onPeerReadyForHello('CC:DD', 247);
      final peerHello = ProtocolHelloData(
        peerKind: PeerKind.phoneV1Legacy,
        maxRxEnvelopeBytes: 164,
        minNegotiatedMtu: 185,
      );
      final published = await h.peerPublisher.send(
        eventType: EventTypeV2.protocolHello,
        priority: PriorityV2.normal,
        payload: peerHello.encode(),
        createdAtHlc: HlcTimestampV2(msSinceEpoch: 1000, counter: 0),
        expiresAtHlc: HlcTimestampV2(msSinceEpoch: 60000, counter: 0),
        maxHops: 0,
        negotiatedMtu: 247,
      );
      await h.dispatcher.onReceiveEnvelopeBytes(
        published.wireBytes,
        peerId: 'CC:DD',
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));

      final state = h.registry.stateFor('CC:DD')!;
      expect(state.status, PeerCapabilityStatus.failed);
      expect(state.failureReason,
          ProtocolHelloValidator.dropSelfDeclaredLegacy);
      await h.dispose();
    });

    test('HELLO at non-NORMAL priority is dropped by matrix BEFORE state machine',
        () async {
      final h = await makeHarness();
      await h.service.onPeerReadyForHello('EE:FF', 247);
      // Spec §6 says PROTOCOL_HELLO must be NORMAL; sending at SOS_RED is a
      // priority abuse — the publisher itself rejects at send time.
      expect(
        () => h.peerPublisher.send(
          eventType: EventTypeV2.protocolHello,
          priority: PriorityV2.sosRed,
          payload: ProtocolHelloData(
            peerKind: PeerKind.phoneV1,
            maxRxEnvelopeBytes: 2048,
            minNegotiatedMtu: 247,
          ).encode(),
          createdAtHlc: HlcTimestampV2(msSinceEpoch: 1, counter: 0),
          expiresAtHlc: HlcTimestampV2(msSinceEpoch: 60000, counter: 0),
          maxHops: 0,
          negotiatedMtu: 247,
        ),
        throwsA(isA<PublishRejected>()),
      );
      await h.dispose();
    });

    test('strict dispatcher accepts valid HELLO when maxHops=0', () async {
      final h = await makeHarness(enableMaxHopsOvercommit: true);
      await h.service.onPeerReadyForHello('AA:BB', 247);

      final peerHello = ProtocolHelloData(
        peerKind: PeerKind.phoneV1,
        maxRxEnvelopeBytes: 2048,
        supportsIblt: true,
        supportsBloomV2: true,
        supportsChunking: true,
        minNegotiatedMtu: 247,
      );
      final published = await h.peerPublisher.send(
        eventType: EventTypeV2.protocolHello,
        priority: PriorityV2.normal,
        payload: peerHello.encode(),
        createdAtHlc: HlcTimestampV2(msSinceEpoch: 1000, counter: 0),
        expiresAtHlc: HlcTimestampV2(msSinceEpoch: 60000, counter: 0),
        maxHops: 0,
        negotiatedMtu: 247,
      );

      final outcome = await h.dispatcher.onReceiveEnvelopeBytes(
        published.wireBytes,
        peerId: 'AA:BB',
      );
      expect(outcome, isA<DispatchAccepted>());
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(h.registry.stateFor('AA:BB')?.status, PeerCapabilityStatus.active);
      await h.dispose();
    });
  });
}

class _SentChunkBatch {
  final String peerId;
  final List<Uint8List> chunks;
  final int mtu;
  _SentChunkBatch(this.peerId, this.chunks, this.mtu);
}

class _HelloHarness {
  final DatabaseHelper db;
  final EnvelopeStoreV2 store;
  final MeshTraceWriter trace;
  final AuthorRateLimiter rate;
  final EnvelopeDispatcherV2 dispatcher;
  final MessagePublisherV2 peerPublisher;
  final PeerCapabilityRegistry registry;
  final ProtocolHelloService service;
  final List<_SentChunkBatch> sentChunks;

  _HelloHarness(
    this.db,
    this.store,
    this.trace,
    this.rate,
    this.dispatcher,
    this.peerPublisher,
    this.registry,
    this.service,
    this.sentChunks,
  );

  Future<void> dispose() async {
    await service.dispose();
    await registry.dispose();
    await dispatcher.dispose();
  }
}
