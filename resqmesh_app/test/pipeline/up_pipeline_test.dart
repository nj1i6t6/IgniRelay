// up_pipeline_test.dart
//
// 測試上行管道：BLE raw bytes → MeshEventHandler → DB + stream
//
// 使用 sqflite_common_ffi (in-memory SQLite) 取代平台 sqflite plugin。
// LocationService().currentLocation 在測試中為 null，
// 因此 originLat = 0 的封包可完全跳過 VillageGeofence zone check。

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ignirelay_app/app/crypto/identity_manager.dart';
import 'package:ignirelay_app/app/crypto/signer.dart';
import 'package:ignirelay_app/app/db/database_helper.dart';
import 'package:ignirelay_app/app/mesh/mesh_event_handler.dart';
import 'package:ignirelay_app/app/proto/mesh_protocol.pb.dart' as pb;

// 每次呼叫回傳唯一 event ID
// Stage 5-fix：counter 保證 in-memory DB 高速執行下 uid 仍唯一。
int _seq = 0;
String _uid(String prefix) =>
    '$prefix-${DateTime.now().microsecondsSinceEpoch}-${++_seq}';

/// Mirrors MeshEventHandler._crc32EventId so tests can target the IBLT
/// fast-path with the exact key hash a real peer would request.
int _crc32(String s) {
  int crc = 0xFFFFFFFF;
  for (final b in s.codeUnits) {
    crc ^= b;
    for (int j = 0; j < 8; j++) {
      crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
    }
  }
  return crc ^ 0xFFFFFFFF;
}

/// 取得本機公鑰 bytes（用於測試簽章）
Future<List<int>> _getLocalPubKey() async {
  final keyPair = await IdentityManager().getOrCreateKeyPair();
  final pubKey = await keyPair.extractPublicKey();
  return pubKey.bytes;
}

/// 建構已簽章的 wire payload（通過 Ed25519 驗證）
Future<Uint8List> _makeSignedWire(
  String id,
  List<int> payload, {
  int urgency = 0,
  int eventType = 0,
  int ttl = 10,
}) async {
  final signature = await Signer.signEvent(
    eventId: id,
    eventType: eventType,
    payload: payload,
  );
  final pubKey = await _getLocalPubKey();
  return Uint8List.fromList(MeshEventHandler.encodeWirePayload(
    id,
    payload,
    urgency: urgency,
    eventType: eventType,
    ttl: ttl,
    signature: signature.toList(),
    senderPubKey: pubKey,
    // originLat/Lng 不設定 → 預設 0 → decoded.originLat = null → 跳過 zone check
  ));
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    DatabaseHelper.testDatabasePathOverride = inMemoryDatabasePath;
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await IdentityManager().initialize();
  });

  setUp(() async {
    await DatabaseHelper().resetForTest();
  });

  final handler = MeshEventHandler();

  // 未簽章版本，僅用於 error resilience / dedup 測試
  Uint8List makeWire(String id, List<int> payload, {int urgency = 0, int eventType = 0}) =>
      Uint8List.fromList(MeshEventHandler.encodeWirePayload(
        id, payload,
        urgency: urgency,
        eventType: eventType,
      ));

  group('Up Pipeline — Normal receive', () {
    test('valid event: stream emits MeshDataReceived', () async {
      final id = _uid('up-stream');
      final payload = [1, 2, 3];
      final wire = await _makeSignedWire(id, payload, urgency: 1);

      MeshDataReceived? received;
      final sub = handler.events.listen((e) => received = e);

      await handler.handleIncomingData(wire, 'device-a');
      await Future.delayed(Duration.zero);

      expect(received, isNotNull);
      expect(received!.sourceNodeId, equals('device-a'));
      expect(received!.data, equals(payload));
      await sub.cancel();
    });

    test('valid event: receivedEventCount increments', () async {
      final id = _uid('up-count');
      final wire = await _makeSignedWire(id, [9]);
      final before = handler.receivedEventCount;

      await handler.handleIncomingData(wire, 'device-b');

      expect(handler.receivedEventCount, equals(before + 1));
    });

    test('valid event: event_id marked as seen after processing', () async {
      final id = _uid('up-seen');
      final wire = await _makeSignedWire(id, []);

      expect(handler.hasSeen(id), isFalse);
      await handler.handleIncomingData(wire, 'device-c');
      expect(handler.hasSeen(id), isTrue);
    });

    test('valid event: persisted in Event_Logs DB', () async {
      final id = _uid('up-db');
      final wire = await _makeSignedWire(id, [42], urgency: 2, eventType: 1);

      await handler.handleIncomingData(wire, 'device-db');

      final db = await DatabaseHelper().database;
      final rows = await db.query(
        'Event_Logs',
        where: 'event_id = ?',
        whereArgs: [id],
      );
      expect(rows.length, equals(1));
      expect(rows[0]['urgency'], equals(2));
      expect(rows[0]['event_type'], equals(1));
    });

    test('TTL stored as TTL-1 (decremented on receive)', () async {
      final id = _uid('up-ttl');
      final wire = await _makeSignedWire(id, [], ttl: 8);

      await handler.handleIncomingData(wire, 'device-ttl');

      final db = await DatabaseHelper().database;
      final rows = await db.query(
        'Event_Logs',
        where: 'event_id = ?',
        whereArgs: [id],
      );
      expect(rows.isNotEmpty, isTrue);
      expect(rows[0]['ttl'], equals(7)); // 8 - 1
    });
  });

  group('Up Pipeline — Deduplication', () {
    test('duplicate event: stream does NOT emit second time', () async {
      final id = _uid('up-dup');
      final wire = await _makeSignedWire(id, [5, 6, 7], urgency: 1);

      // First call
      await handler.handleIncomingData(wire, 'device-x');
      final countAfterFirst = handler.receivedEventCount;

      // Second call — same bytes
      int extraEmits = 0;
      final sub = handler.events.listen((_) => extraEmits++);
      await handler.handleIncomingData(wire, 'device-x');
      await Future.delayed(Duration.zero);

      expect(extraEmits, equals(0));
      expect(handler.receivedEventCount, equals(countAfterFirst));
      await sub.cancel();
    });

    test('same event from different device: still deduplicated', () async {
      final id = _uid('up-dup2');
      final wire = await _makeSignedWire(id, []);

      await handler.handleIncomingData(wire, 'device-1');
      final countAfterFirst = handler.receivedEventCount;

      await handler.handleIncomingData(wire, 'device-2'); // different source
      expect(handler.receivedEventCount, equals(countAfterFirst));
    });
  });

  group('Up Pipeline — Hazard Marker', () {
    test('hazard event: written to Hazards_State table', () async {
      final hazardId = _uid('hzd');
      final eventId = _uid('hzd-evt');

      final hazardProto = pb.HazardData()
        ..hazardId = hazardId
        ..hazardType = 'FIRE'
        ..severity = 3
        ..centerLat = 25.034
        ..centerLng = 121.564
        ..radiusMeters = 300.0;

      final payload = hazardProto.writeToBuffer();
      final pubKey = await _getLocalPubKey();
      final signature = await Signer.signEvent(
        eventId: eventId,
        eventType: 4,
        payload: payload,
      );

      final wire = Uint8List.fromList(MeshEventHandler.encodeWirePayload(
        eventId,
        payload,
        urgency: 2,
        eventType: 4, // hazardMarker
        signature: signature.toList(),
        senderPubKey: pubKey,
      ));

      await handler.handleIncomingData(wire, 'device-hzd');

      final db = await DatabaseHelper().database;
      final rows = await db.query(
        'Hazards_State',
        where: 'hazard_id = ?',
        whereArgs: [hazardId],
      );
      expect(rows.length, equals(1));
      expect(rows[0]['type'], equals('FIRE'));
      expect(rows[0]['severity'], equals(3));
    });
  });

  group('Up Pipeline — Signature Verification', () {
    test('unsigned event: rejected (REJECT no-sig)', () async {
      final id = _uid('up-nosig');
      final wire = makeWire(id, [1, 2, 3]);
      final before = handler.receivedEventCount;

      await handler.handleIncomingData(wire, 'device-nosig');

      // 未簽章的事件不應增加 receivedEventCount
      expect(handler.receivedEventCount, equals(before));
    });

    test('tampered payload: rejected (sig-fail)', () async {
      final id = _uid('up-tamper');
      final originalPayload = [10, 20, 30];
      final signature = await Signer.signEvent(
        eventId: id,
        eventType: 0,
        payload: originalPayload,
      );
      final pubKey = await _getLocalPubKey();

      // 用不同的 payload 但原本的簽章 → 驗證應失敗
      final tamperedWire = Uint8List.fromList(MeshEventHandler.encodeWirePayload(
        id,
        [99, 99, 99], // 篡改的 payload
        signature: signature.toList(),
        senderPubKey: pubKey,
      ));

      final before = handler.receivedEventCount;
      await handler.handleIncomingData(tamperedWire, 'device-tamper');
      expect(handler.receivedEventCount, equals(before));
    });

    test('ttl excluded from signature: wire ttl ≠ sign-time ttl still verifies '
        '(match/negotiation v1 cross-device fix)', () async {
      // Regression for the 0d two-phone finding: match/negotiation events were
      // signed with ttl=5/8 but the v1 transmit path normalizes the wire ttl to
      // 10 (encodeWirePayload default) and relays decrement it per hop. While
      // ttl was part of the signed canonical bytes this flipped the signature →
      // RECV REJECT(sig-fail) → match never reached the peer (Match_Negotiations
      // stayed 0). ttl is now excluded from the signature, so a packet whose
      // wire ttl differs from anything must still verify.
      final id = _uid('up-ttl-indep');
      final payload = [7, 7, 7];
      final pubKey = await _getLocalPubKey();
      final signature = await Signer.signEvent(
        eventId: id,
        eventType: 2, // matchOffer — historically signed with ttl=5
        payload: payload,
      );
      final wire = Uint8List.fromList(MeshEventHandler.encodeWirePayload(
        id,
        payload,
        urgency: 1,
        eventType: 2,
        ttl: 10, // deliberately != any sign-time ttl
        signature: signature.toList(),
        senderPubKey: pubKey,
      ));

      final before = handler.receivedEventCount;
      await handler.handleIncomingData(wire, 'device-ttl');
      expect(handler.receivedEventCount, equals(before + 1));
      final db = await DatabaseHelper().database;
      final rows = await db
          .query('Event_Logs', where: 'event_id = ?', whereArgs: [id]);
      expect(rows.length, equals(1));
      expect(rows.first['event_type'], equals(2));
    });
  });

  group('Up Pipeline — EventType wire enum >14 (matchRequest/handshake)', () {
    // Regression for the 0d two-phone finding: the proto `EventType` enum only
    // defined values 0–14, but event_types.dart uses matchRequest=15,
    // handshakeComplete=16, stationClaim=17, stationResponse=18. encodeWirePayload
    // did `EventType.valueOf(eventType) ?? RESOURCE_REGISTER`, so 15–18 collapsed
    // to wire type=0 → the receiver decoded type=0, sig-fail (type is in the
    // signed canonical bytes) → requester-initiated match and handoff completion
    // never crossed devices. The proto enum now includes 15–18.
    for (final t in const [15, 16, 17, 18]) {
      test('encode/decode preserves event_type=$t (not squashed to 0)', () {
        final wire = MeshEventHandler.encodeWirePayload(
          _uid('enum$t'), const [1, 2, 3],
          urgency: 1, eventType: t,
        );
        final decoded = MeshEventHandler.decodeWirePayload(wire);
        expect(decoded, isNotNull);
        expect(decoded!.eventType, equals(t),
            reason: 'eventType=$t must survive the wire, not fall back to 0');
      });
    }

    test('signed type=15 (matchRequest) is received & stored as 15 (no sig-fail)',
        () async {
      final id = _uid('up-mreq');
      final payload = [4, 5, 6];
      final wire = await _makeSignedWire(id, payload, urgency: 1, eventType: 15);

      final before = handler.receivedEventCount;
      await handler.handleIncomingData(wire, 'device-mreq');
      expect(handler.receivedEventCount, equals(before + 1),
          reason: 'must not be dropped by sig-fail');

      final db = await DatabaseHelper().database;
      final rows = await db
          .query('Event_Logs', where: 'event_id = ?', whereArgs: [id]);
      expect(rows.length, equals(1));
      expect(rows.first['event_type'], equals(15));
    });
  });

  group('Up Pipeline — Error Resilience', () {
    test('empty bytes: does not throw', () async {
      await expectLater(
        handler.handleIncomingData(Uint8List(0), 'device-empty'),
        completes,
      );
    });

    test('garbage bytes: does not throw', () async {
      final garbage = Uint8List.fromList(List.generate(30, (i) => 255 - i));
      await expectLater(
        handler.handleIncomingData(garbage, 'device-garbage'),
        completes,
      );
    });

    test('single null byte: does not throw', () async {
      await expectLater(
        handler.handleIncomingData(Uint8List.fromList([0x00]), 'device-null'),
        completes,
      );
    });
  });

  group('Up Pipeline — Legacy pipe format', () {
    test('legacy format event: rejected without signature', () async {
      // Legacy pipe format 不帶簽章，應被 no-sig 檢查攔截
      final id = _uid('legacy-up');
      final payload = [0x42, 0x43];
      final bytes = Uint8List.fromList([...utf8.encode(id), 0x7C, ...payload]);

      final before = handler.receivedEventCount;
      await handler.handleIncomingData(bytes, 'device-legacy');

      // Legacy 格式無簽章 → 被拒絕
      expect(handler.receivedEventCount, equals(before));
    });
  });

  group('Up Pipeline — TTL hop-limit', () {
    test('received event stored with ttl-1, served by IBLT with that ttl',
        () async {
      final id = _uid('ttl-dec');
      final payload = [1, 2, 3];
      final pubKey = await _getLocalPubKey();
      final signature =
          await Signer.signEvent(eventId: id, eventType: 0, payload: payload);
      // wire ttl=2 → 收件端消耗一跳 → 落庫 ttl=1
      final wire = Uint8List.fromList(MeshEventHandler.encodeWirePayload(
        id,
        payload,
        urgency: 0,
        eventType: 0,
        ttl: 2,
        signature: signature.toList(),
        senderPubKey: pubKey,
      ));
      await handler.handleIncomingData(wire, 'device-ttl2');

      final db = await DatabaseHelper().database;
      final rows = await db.query('Event_Logs',
          columns: ['ttl'], where: 'event_id = ?', whereArgs: [id]);
      expect(rows.length, equals(1));
      expect(rows.first['ttl'], equals(1)); // 2 → 1，未被重設成 10/9

      // 出件路徑（IBLT fast-path）必須帶 stored ttl（=1），不可回到預設 10。
      final served = await handler.getEventsByKeyHashes({_crc32(id)});
      expect(served.length, equals(1));
      expect(served.first['ttl'], equals(1));
    });

    test('received event with ttl<=0 is dropped (no DB row, not revived to 9)',
        () async {
      final id = _uid('ttl-zero');
      final payload = [4, 5, 6];
      final pubKey = await _getLocalPubKey();
      final signature =
          await Signer.signEvent(eventId: id, eventType: 0, payload: payload);
      final wire = Uint8List.fromList(MeshEventHandler.encodeWirePayload(
        id,
        payload,
        urgency: 0,
        eventType: 0,
        ttl: 0, // 已耗盡 hop budget
        signature: signature.toList(),
        senderPubKey: pubKey,
      ));
      final before = handler.receivedEventCount;
      await handler.handleIncomingData(wire, 'device-ttl0');

      expect(handler.receivedEventCount, equals(before)); // 未處理
      final db = await DatabaseHelper().database;
      final rows =
          await db.query('Event_Logs', where: 'event_id = ?', whereArgs: [id]);
      expect(rows, isEmpty); // drop，不落庫、不復活成 9
    });

    test('IBLT fast-path (getEventsByKeyHashes) excludes ttl<=0 events',
        () async {
      final live = _uid('ttl-live');
      final dead = _uid('ttl-dead');
      // ingestVerifiedEvent 存 ttl-1：ttl:5 → 4（live），ttl:1 → 0（dead）。
      await handler.ingestVerifiedEvent(
          eventId: live, eventType: 0, urgency: 0, payload: const [1], ttl: 5);
      await handler.ingestVerifiedEvent(
          eventId: dead, eventType: 0, urgency: 0, payload: const [1], ttl: 1);

      final served =
          await handler.getEventsByKeyHashes({_crc32(live), _crc32(dead)});
      final ids = served.map((e) => e['event_id']).toSet();
      expect(ids, contains(live));
      expect(ids, isNot(contains(dead)));
    });
  });
}
