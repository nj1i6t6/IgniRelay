import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:ignirelay_app/app/mesh/mesh_event_handler.dart';

void main() {
  group('Wire Codec — Protobuf roundtrip', () {
    test('eventId + payload survive encode/decode', () {
      const id = 'aaaa1111-0000-0000-0000-000000000001';
      final payload = [1, 2, 3, 4, 5];

      final wire = MeshEventHandler.encodeWirePayload(id, payload);
      final wp = MeshEventHandler.decodeWirePayload(wire);

      expect(wp, isNotNull);
      expect(wp!.eventId, equals(id));
      expect(wp.payload, equals(payload));
    });

    test('urgency 0–3 roundtrip', () {
      for (final urg in [0, 1, 2, 3]) {
        final wire = MeshEventHandler.encodeWirePayload(
          'urgency-test-$urg',
          [],
          urgency: urg,
        );
        final wp = MeshEventHandler.decodeWirePayload(wire);
        expect(wp!.urgency, equals(urg), reason: 'urgency=$urg');
      }
    });

    test('event types 0–7 roundtrip', () {
      for (final t in [0, 1, 2, 3, 4, 5, 6, 7]) {
        final wire = MeshEventHandler.encodeWirePayload(
          'type-test-$t',
          [],
          eventType: t,
        );
        final wp = MeshEventHandler.decodeWirePayload(wire);
        expect(wp!.eventType, equals(t), reason: 'eventType=$t');
      }
    });

    test('event types 8–13 roundtrip (Bug 1 fix: MATCH_CONFIRM→CHAT_MESSAGE)', () {
      for (final t in [8, 9, 10, 11, 12, 13]) {
        final wire = MeshEventHandler.encodeWirePayload(
          'type-ext-test-$t',
          [0xAB, 0xCD],
          eventType: t,
        );
        final wp = MeshEventHandler.decodeWirePayload(wire);
        expect(wp, isNotNull, reason: 'eventType=$t should decode');
        expect(wp!.eventType, equals(t), reason: 'eventType=$t');
      }
    });

    test('CHAT_MESSAGE (type=13) preserves payload content', () {
      final chatPayload = [123, 34, 114, 111, 111, 109, 34, 125]; // {"room"}
      final wire = MeshEventHandler.encodeWirePayload(
        'chat-msg-test-001',
        chatPayload,
        eventType: 13,
        urgency: 0,
      );
      final wp = MeshEventHandler.decodeWirePayload(wire);
      expect(wp, isNotNull);
      expect(wp!.eventType, equals(13));
      expect(wp.payload, equals(chatPayload));
    });

    test('HLC timestamp + counter roundtrip', () {
      const ts = 1700000000000;
      const ctr = 99;
      final wire = MeshEventHandler.encodeWirePayload(
        'hlc-test-001',
        [],
        hlcTimestamp: ts,
        hlcCounter: ctr,
      );
      final wp = MeshEventHandler.decodeWirePayload(wire);
      expect(wp!.hlcTimestamp, equals(ts));
      expect(wp.hlcCounter, equals(ctr));
    });

    test('received + origin coordinates roundtrip', () {
      final wire = MeshEventHandler.encodeWirePayload(
        'geo-test-001',
        [],
        lat: 25.034,
        lng: 121.564,
        originLat: 25.035,
        originLng: 121.565,
      );
      final wp = MeshEventHandler.decodeWirePayload(wire);
      expect(wp!.lat, closeTo(25.034, 1e-4));
      expect(wp.lng, closeTo(121.564, 1e-4));
      expect(wp.originLat, closeTo(25.035, 1e-4));
      expect(wp.originLng, closeTo(121.565, 1e-4));
    });

    test('no-coord encode: all 4 geo fields decode as null (skip zone routing)', () {
      // 不帶座標編碼 → proto3 預設 0.0 → decode 全部轉為 null
      // 接收端判斷 originLat == null 即跳過地理圍欄，事件正常傳播
      final wire = MeshEventHandler.encodeWirePayload('no-geo-001', []);
      final wp = MeshEventHandler.decodeWirePayload(wire);
      expect(wp!.lat, isNull,
          reason: 'no receivedLat encoded → must decode as null');
      expect(wp.lng, isNull);
      expect(wp.originLat, isNull,
          reason: 'no originLat encoded → must decode as null');
      expect(wp.originLng, isNull);
    });

    test('senderPubKey and signature roundtrip', () {
      final pubKey = List<int>.generate(32, (i) => i);
      final sig = List<int>.generate(64, (i) => i);
      final wire = MeshEventHandler.encodeWirePayload(
        'sig-test-001',
        [7, 8, 9],
        senderPubKey: pubKey,
        signature: sig,
      );
      final wp = MeshEventHandler.decodeWirePayload(wire);
      expect(wp!.senderPubKey, equals(pubKey));
      expect(wp.signature, equals(sig));
    });

    test('TTL roundtrip', () {
      final wire = MeshEventHandler.encodeWirePayload(
        'ttl-test-001',
        [],
        ttl: 5,
      );
      final wp = MeshEventHandler.decodeWirePayload(wire);
      expect(wp!.ttl, equals(5));
    });

    test('binary payload (all 256 byte values) roundtrip', () {
      final payload = List<int>.generate(256, (i) => i);
      final wire = MeshEventHandler.encodeWirePayload('bin-test-001', payload);
      final wp = MeshEventHandler.decodeWirePayload(wire);
      expect(wp!.payload, equals(payload));
    });

    test('large payload (1 KB) roundtrip', () {
      final payload = List<int>.generate(1024, (i) => i % 256);
      final wire = MeshEventHandler.encodeWirePayload('large-test-001', payload);
      final wp = MeshEventHandler.decodeWirePayload(wire);
      expect(wp!.payload, equals(payload));
    });

    test('encode→decode is deterministic (same input → same output)', () {
      final wire1 = MeshEventHandler.encodeWirePayload(
        'det-001', [1, 2, 3], urgency: 2, eventType: 4,
      );
      final wire2 = MeshEventHandler.encodeWirePayload(
        'det-001', [1, 2, 3], urgency: 2, eventType: 4,
      );
      expect(wire1, equals(wire2));
    });
  });

  group('Wire Codec — Legacy pipe fallback', () {
    test('valid pipe format: eventId|payload bytes decoded correctly', () {
      const eventId = 'legacy-event-001';
      final payloadBytes = [10, 20, 30];
      final bytes = [...utf8.encode(eventId), 0x7C, ...payloadBytes];

      final wp = MeshEventHandler.decodeWirePayload(bytes);
      expect(wp, isNotNull);
      expect(wp!.eventId, equals(eventId));
      expect(wp.payload, equals(payloadBytes));
    });

    test('legacy format: urgency defaults to 0', () {
      final bytes = [...utf8.encode('legacy-urg-001'), 0x7C, 0x01];
      final wp = MeshEventHandler.decodeWirePayload(bytes);
      expect(wp!.urgency, equals(0));
    });

    test('legacy format: empty payload after pipe is accepted', () {
      final bytes = [...utf8.encode('legacy-empty-001'), 0x7C];
      final wp = MeshEventHandler.decodeWirePayload(bytes);
      expect(wp, isNotNull);
      expect(wp!.eventId, equals('legacy-empty-001'));
      expect(wp.payload, isEmpty);
    });

    test('empty bytes → null', () {
      expect(MeshEventHandler.decodeWirePayload([]), isNull);
    });

    test('garbage bytes does not throw', () {
      final garbage = List<int>.generate(20, (i) => 255 - i);
      expect(
        () => MeshEventHandler.decodeWirePayload(garbage),
        returnsNormally,
      );
    });

    test('all-zero bytes does not throw', () {
      expect(
        () => MeshEventHandler.decodeWirePayload(List<int>.filled(16, 0)),
        returnsNormally,
      );
    });

    test('single byte does not throw', () {
      expect(() => MeshEventHandler.decodeWirePayload([0x01]), returnsNormally);
    });
  });
}
