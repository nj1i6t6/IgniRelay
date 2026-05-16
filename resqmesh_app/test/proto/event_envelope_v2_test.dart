// v0.3 Stage 0c — round-trip tests for the hand-written EventEnvelopeV2 wire codec.
//
// Spec: docs/specs/envelope_v2_spec_2026-05-13.md §3, §5.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ignirelay_app/app/proto/event_envelope_v2.dart';
import 'package:ignirelay_app/app/proto/proto_wire.dart';

void main() {
  group('HlcTimestampV2', () {
    test('round-trips encode/decode', () {
      final h = HlcTimestampV2(msSinceEpoch: 1747350000000, counter: 42);
      final out = HlcTimestampV2.decode(h.encode());
      expect(out.msSinceEpoch, h.msSinceEpoch);
      expect(out.counter, h.counter);
    });

    test('zero defaults survive proto3 omission', () {
      final h = HlcTimestampV2.zero;
      final bytes = h.encode();
      expect(bytes.length, 0, reason: 'all defaults → empty wire bytes');
      final out = HlcTimestampV2.decode(bytes);
      expect(out.msSinceEpoch, 0);
      expect(out.counter, 0);
    });

    test('compareTo orders by ms then counter', () {
      final earlier = HlcTimestampV2(msSinceEpoch: 100, counter: 5);
      final later = HlcTimestampV2(msSinceEpoch: 100, counter: 6);
      final muchLater = HlcTimestampV2(msSinceEpoch: 101, counter: 0);
      expect(earlier.compareTo(later), lessThan(0));
      expect(later.compareTo(muchLater), lessThan(0));
      expect(later.compareTo(later), 0);
    });
  });

  group('EventEnvelopeV2', () {
    EventEnvelopeV2 _sample({int eventType = EventTypeV2.statusUpdate}) {
      return EventEnvelopeV2(
        envelopeId: Uint8List.fromList(List.generate(16, (i) => i)),
        eventType: eventType,
        priority: PriorityV2.sosRed,
        createdAtHlc: HlcTimestampV2(msSinceEpoch: 1747350000000, counter: 0),
        expiresAtHlc: HlcTimestampV2(msSinceEpoch: 1747350720000, counter: 0),
        maxHops: 6,
        authorKey: Uint8List.fromList(List.generate(32, (i) => 0x80 | i)),
        signature: Uint8List.fromList(List.generate(64, (i) => i)),
        payload: Uint8List.fromList([1, 2, 3, 4, 5]),
      );
    }

    test('encodes + decodes bit-identically', () {
      final orig = _sample();
      final bytes = orig.encode();
      final out = EventEnvelopeV2.decode(bytes);
      expect(out.protocolVersion, 2);
      expect(out.envelopeId, orig.envelopeId);
      expect(out.eventType, orig.eventType);
      expect(out.priority, orig.priority);
      expect(out.createdAtHlc.msSinceEpoch, orig.createdAtHlc.msSinceEpoch);
      expect(out.expiresAtHlc.msSinceEpoch, orig.expiresAtHlc.msSinceEpoch);
      expect(out.maxHops, orig.maxHops);
      expect(out.authorKey, orig.authorKey);
      expect(out.sigAlgo, orig.sigAlgo);
      expect(out.signature, orig.signature);
      expect(out.payload, orig.payload);
      expect(out.lastRelayId, '');
      expect(out.isExperimental, false);
    });

    test('rejects when envelope_id is missing or wrong size', () {
      // Build a manual proto wire stream that omits envelope_id.
      final w = ProtoWriter();
      w.writeUint32(1, 2);
      w.writeEnum(3, EventTypeV2.statusUpdate);
      w.writeEnum(4, PriorityV2.sosRed);
      // missing envelope_id at tag 2 entirely
      expect(() => EventEnvelopeV2.decode(w.toBytes()),
          throwsA(isA<ProtoDecodeException>()));
    });

    test('rejects when author_key is wrong size', () {
      final orig = _sample();
      final tampered = EventEnvelopeV2(
        envelopeId: orig.envelopeId,
        eventType: orig.eventType,
        priority: orig.priority,
        createdAtHlc: orig.createdAtHlc,
        expiresAtHlc: orig.expiresAtHlc,
        maxHops: orig.maxHops,
        authorKey: Uint8List(31), // wrong
        signature: orig.signature,
        payload: orig.payload,
      );
      expect(() => EventEnvelopeV2.decode(tampered.encode()),
          throwsA(isA<ProtoDecodeException>()));
    });

    test('skips unknown fields (forward compat)', () {
      final w = ProtoWriter();
      w.writeUint32(1, 2);
      w.writeBytes(2, List.generate(16, (i) => i));
      w.writeEnum(3, EventTypeV2.statusUpdate);
      w.writeEnum(4, PriorityV2.sosRed);
      w.writeMessage(5, HlcTimestampV2(msSinceEpoch: 1, counter: 0).encode());
      w.writeMessage(6, HlcTimestampV2(msSinceEpoch: 2, counter: 0).encode());
      w.writeUint32(7, 6);
      w.writeBytes(8, List.generate(32, (i) => i));
      w.writeUint32(9, 1);
      w.writeBytes(10, List.generate(64, (i) => i));
      w.writeBytes(11, [1, 2, 3]);
      // unknown tag 99 (varint)
      w.writeUint32(99, 12345);
      // unknown tag 100 (length-delimited)
      w.writeBytes(100, [9, 8, 7]);
      final out = EventEnvelopeV2.decode(w.toBytes());
      expect(out.payload, [1, 2, 3]);
    });

    test('isExperimental defaults to false on wire (proto3 omission)', () {
      final orig = _sample();
      // false → not on wire → default decode == false.
      final bytes = orig.encode();
      final out = EventEnvelopeV2.decode(bytes);
      expect(out.isExperimental, false);
    });

    test('isExperimental round-trips when true', () {
      final orig = EventEnvelopeV2(
        envelopeId: Uint8List.fromList(List.generate(16, (i) => i)),
        eventType: 1500,
        priority: PriorityV2.normal,
        createdAtHlc: HlcTimestampV2(msSinceEpoch: 1, counter: 0),
        expiresAtHlc: HlcTimestampV2(msSinceEpoch: 2, counter: 0),
        maxHops: 1,
        authorKey: Uint8List(32),
        signature: Uint8List(64),
        payload: Uint8List(0),
        isExperimental: true,
      );
      final out = EventEnvelopeV2.decode(orig.encode());
      expect(out.isExperimental, true);
      expect(out.eventType, 1500);
    });
  });

  group('StatusUpdateData', () {
    test('snapshot round-trips', () {
      final s = StatusUpdateData(
        safetyState: SafetyState.injured,
        needs: const [
          NeedEntry(
            category: NeedCategory.water,
            severity: NeedSeverity.urgent,
            expiresAtHlc: HlcTimestampV2(msSinceEpoch: 100, counter: 1),
          ),
        ],
      );
      final out = StatusUpdateData.decode(s.encode());
      expect(out.safetyState, SafetyState.injured);
      expect(out.needs.length, 1);
      expect(out.needs.first.category, NeedCategory.water);
      expect(out.needs.first.severity, NeedSeverity.urgent);
      expect(out.needs.first.expiresAtHlc.msSinceEpoch, 100);
    });

    test('impliedPriorityFloor: TRAPPED → SOS_RED', () {
      final s = StatusUpdateData(safetyState: SafetyState.trapped);
      expect(s.impliedPriorityFloor(), PriorityV2.sosRed);
    });

    test('impliedPriorityFloor: SAFE + URGENT need → SOS_YELLOW', () {
      final s = StatusUpdateData(
        safetyState: SafetyState.safe,
        needs: const [
          NeedEntry(
            category: NeedCategory.water,
            severity: NeedSeverity.urgent,
            expiresAtHlc: HlcTimestampV2.zero,
          ),
        ],
      );
      expect(s.impliedPriorityFloor(), PriorityV2.sosYellow);
    });

    test('impliedPriorityFloor: SAFE + non-urgent → STATUS', () {
      final s = StatusUpdateData(
        safetyState: SafetyState.safe,
        needs: const [
          NeedEntry(
            category: NeedCategory.water,
            severity: NeedSeverity.want,
            expiresAtHlc: HlcTimestampV2.zero,
          ),
        ],
      );
      expect(s.impliedPriorityFloor(), PriorityV2.status);
    });
  });

  group('ProtocolHelloData', () {
    test('round-trips a PhoneV1 hello', () {
      final h = ProtocolHelloData(
        peerKind: PeerKind.phoneV1,
        maxRxEnvelopeBytes: 2048,
        supportsIblt: true,
        supportsBloomV2: true,
        supportsChunking: true,
        minNegotiatedMtu: 247,
        capabilities: const ['shelter_status', 'battery_share'],
        bgState: BgState.foreground,
      );
      final out = ProtocolHelloData.decode(h.encode());
      expect(out.peerKind, PeerKind.phoneV1);
      expect(out.maxRxEnvelopeBytes, 2048);
      expect(out.supportsIblt, true);
      expect(out.supportsChunking, true);
      expect(out.minNegotiatedMtu, 247);
      expect(out.capabilities, ['shelter_status', 'battery_share']);
      expect(out.bgState, BgState.foreground);
    });
  });
}
// ignore_for_file: prefer_const_constructors, prefer_const_declarations, no_leading_underscores_for_local_identifiers
