// up_pipeline_test.dart
//
// 測試上行管道：BLE raw bytes → MeshEventHandler → DB + stream
//
// 使用 sqflite_common_ffi (in-memory SQLite) 取代平台 sqflite plugin。
// LocationService().currentLocation 在測試中為 null，
// 因此 originLat = 0 的封包可完全跳過 VillageGeofence zone check。

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ignirelay_app/crypto/identity_manager.dart';
import 'package:ignirelay_app/db/database_helper.dart';
import 'package:ignirelay_app/mesh/mesh_event_handler.dart';
import 'package:ignirelay_app/mesh/mesh_transport.dart';
import 'package:ignirelay_app/proto/mesh_protocol.pb.dart' as pb;

// 每次呼叫回傳帶毫秒時間戳的唯一 event ID
String _uid(String prefix) =>
    '$prefix-${DateTime.now().microsecondsSinceEpoch}';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    SharedPreferences.setMockInitialValues({});
    await IdentityManager().initialize();
  });

  final handler = MeshEventHandler();

  // 建構一個不含 originLat/Lng 的 wire payload（zone routing 自動跳過）
  Uint8List makeWire(String id, List<int> payload, {int urgency = 0, int eventType = 0}) =>
      Uint8List.fromList(MeshEventHandler.encodeWirePayload(
        id, payload,
        urgency: urgency,
        eventType: eventType,
        // originLat/Lng 不設定 → 預設 0 → decoded.originLat = null → 跳過 zone check
      ));

  group('Up Pipeline — Normal receive', () {
    test('valid event: stream emits MeshDataReceived', () async {
      final id = _uid('up-stream');
      final payload = [1, 2, 3];
      final wire = makeWire(id, payload, urgency: 1);

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
      final wire = makeWire(id, [9]);
      final before = handler.receivedEventCount;

      await handler.handleIncomingData(wire, 'device-b');

      expect(handler.receivedEventCount, equals(before + 1));
    });

    test('valid event: event_id marked as seen after processing', () async {
      final id = _uid('up-seen');
      final wire = makeWire(id, []);

      expect(handler.hasSeen(id), isFalse);
      await handler.handleIncomingData(wire, 'device-c');
      expect(handler.hasSeen(id), isTrue);
    });

    test('valid event: persisted in Event_Logs DB', () async {
      final id = _uid('up-db');
      final wire = makeWire(id, [42], urgency: 2, eventType: 1);

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
      final wire = Uint8List.fromList(MeshEventHandler.encodeWirePayload(
        id, [], ttl: 8,
      ));

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
      final wire = makeWire(id, [5, 6, 7], urgency: 1);

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
      final wire = makeWire(id, []);

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

      final wire = Uint8List.fromList(MeshEventHandler.encodeWirePayload(
        eventId,
        hazardProto.writeToBuffer(),
        urgency: 2,
        eventType: 4, // hazardMarker
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
    test('legacy format event: stream emits correctly', () async {
      final id = _uid('legacy-up');
      final payload = [0x42, 0x43];
      final bytes = Uint8List.fromList([...utf8.encode(id), 0x7C, ...payload]);

      MeshDataReceived? received;
      final sub = handler.events.listen((e) => received = e);

      await handler.handleIncomingData(bytes, 'device-legacy');
      await Future.delayed(Duration.zero);

      expect(received, isNotNull);
      expect(received!.data, equals(payload));
      await sub.cancel();
    });
  });
}
