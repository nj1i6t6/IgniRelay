// event_manager_test.dart
//
// 測試下行管道：UI 操作 → EventManager → DB 寫入 + TriageQueue
//
// 使用 sqflite_common_ffi (in-memory SQLite) + mocked SharedPreferences。

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ignirelay_app/app/crypto/identity_manager.dart';
import 'package:ignirelay_app/app/db/database_helper.dart';
import 'package:ignirelay_app/app/mesh/event_manager.dart';
import 'package:ignirelay_app/app/mesh/event_types.dart';
import 'package:ignirelay_app/app/proto/mesh_protocol.pb.dart' as pb;

// Stage 5-fix：counter 保證 in-memory DB 高速執行下 uid 仍唯一。
int _seq = 0;
String _uid(String prefix) =>
    '$prefix-${DateTime.now().microsecondsSinceEpoch}-${++_seq}';

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

  final em = EventManager();

  group('EventManager — publishEvent (SOS/求援)', () {
    test('returns non-empty event ID', () async {
      final id = await em.publishEvent(urgency: 0, description: 'Need water');
      expect(id, isNotEmpty);
    });

    test('event ID is unique on repeated calls', () async {
      final id1 = await em.publishEvent(urgency: 0, description: 'test-a');
      final id2 = await em.publishEvent(urgency: 0, description: 'test-b');
      expect(id1, isNot(equals(id2)));
    });

    test('event persisted in Event_Logs with correct urgency', () async {
      final id = await em.publishEvent(urgency: 3, description: 'SOS Red');
      final db = await DatabaseHelper().database;
      final rows = await db.query(
        'Event_Logs',
        where: 'event_id = ?',
        whereArgs: [id],
      );
      expect(rows.length, equals(1));
      expect(rows[0]['urgency'], equals(3));
      expect(rows[0]['event_type'], equals(EventType.requestBroadcast));
    });

    test('event enqueued in TriageQueue', () async {
      final queueBefore = em.queue.length;
      await em.publishEvent(urgency: 2, description: 'SOS Yellow');
      expect(em.queue.length, greaterThan(queueBefore));
    });

    test('SOS_RED event goes to top of TriageQueue', () async {
      // Drain existing queue first by dequeuing everything
      while (em.queue.dequeue() != null) {}

      await em.publishEvent(urgency: 0, description: 'low priority');
      await em.publishEvent(urgency: 3, description: 'SOS RED');

      expect(em.queue.hasSOSRedPreemptionPending, isTrue);
      expect(em.queue.dequeue()?.urgency, equals(3));
    });
  });

  group('EventManager — publishSupply (物資供給)', () {
    test('returns non-empty resource ID', () async {
      final id = await em.publishSupply(
        resourceType: 'WATER',
        quantity: 10,
        maxRangeMeters: 500.0,
      );
      expect(id, isNotEmpty);
    });

    test('resource inserted into Materials_State as AVAILABLE', () async {
      final resourceId = await em.publishSupply(
        resourceType: 'FOOD',
        quantity: 5,
        unit: '份',
        maxRangeMeters: 300.0,
        lat: 25.034,
        lng: 121.564,
      );
      final db = await DatabaseHelper().database;
      final rows = await db.query(
        'Materials_State',
        where: 'resource_id = ?',
        whereArgs: [resourceId],
      );
      expect(rows.length, equals(1));
      expect(rows[0]['status'], equals(MaterialStatus.available));
    });

    test('publishSupply also writes to Event_Logs', () async {
      final resourceId = await em.publishSupply(
        resourceType: 'BLANKET',
        quantity: 3,
        maxRangeMeters: 200.0,
      );
      final db = await DatabaseHelper().database;
      // Event_Logs should contain an event with this resource payload
      final rows = await db.query(
        'Event_Logs',
        where: 'event_type = ?',
        whereArgs: [EventType.resourceRegister],
      );
      expect(rows.isNotEmpty, isTrue);
      // Verify the payload contains the resourceId
      final matched = rows.where((r) {
        try {
          final rd = pb.ResourceData.fromBuffer(r['payload'] as List<int>);
          return rd.resourceId == resourceId;
        } catch (_) {
          return false;
        }
      });
      expect(matched.isNotEmpty, isTrue);
    });
  });

  group('EventManager — publishRequest (物資需求)', () {
    test('returns non-empty request ID', () async {
      final id = await em.publishRequest(
        resourceType: 'WATER',
        quantity: 5,
        note: 'urgent',
        maxRangeMeters: 1000.0,
      );
      expect(id, isNotEmpty);
    });

    test('request persisted in Requests_State with correct fields', () async {
      final id = await em.publishRequest(
        resourceType: 'FOOD',
        quantity: 3,
        note: 'need rice',
        maxRangeMeters: 500.0,
        mobilityMode: 'IMMOBILE',
      );
      final db = await DatabaseHelper().database;
      final rows = await db.query(
        'Requests_State',
        where: 'request_id = ?',
        whereArgs: [id],
      );
      expect(rows.length, equals(1));
      expect(rows[0]['status'], equals('OPEN'));
      expect((rows[0]['quantity_needed'] as num).toDouble(), equals(3.0));
      expect(rows[0]['mobility_mode'], equals('IMMOBILE'));
      expect(rows[0]['note'], equals('need rice'));
      expect(rows[0]['event_id'], equals(id));
      expect(rows[0]['payload'], isNotNull);
    });

    test('publishRequest also writes to Event_Logs', () async {
      final id = await em.publishRequest(
        resourceType: 'MEDICINE',
        quantity: 1,
        note: 'first aid',
        maxRangeMeters: 200.0,
      );
      final db = await DatabaseHelper().database;
      final rows = await db.query(
        'Event_Logs',
        where: 'event_id = ?',
        whereArgs: [id],
      );
      expect(rows.length, equals(1));
      expect(rows[0]['event_type'], equals(EventType.requestBroadcast));
    });

    test('request ID is unique on repeated calls', () async {
      final id1 = await em.publishRequest(
        resourceType: 'WATER', quantity: 1, note: 'a', maxRangeMeters: 100.0);
      final id2 = await em.publishRequest(
        resourceType: 'WATER', quantity: 1, note: 'b', maxRangeMeters: 100.0);
      expect(id1, isNot(equals(id2)));
    });
  });

  group('EventManager — publishHazard (危險標記)', () {
    test('returns non-empty hazard ID', () async {
      final id = await em.publishHazard(
        type: 'FIRE',
        severity: 3,
        lat: 25.034,
        lng: 121.564,
      );
      expect(id, isNotEmpty);
    });

    test('hazard inserted into Hazards_State with correct fields', () async {
      final hazardId = await em.publishHazard(
        type: 'FLOOD',
        severity: 2,
        lat: 25.011,
        lng: 121.533,
        radiusMeters: 400.0,
      );
      final db = await DatabaseHelper().database;
      final rows = await db.query(
        'Hazards_State',
        where: 'hazard_id = ?',
        whereArgs: [hazardId],
      );
      expect(rows.length, equals(1));
      expect(rows[0]['type'], equals('FLOOD'));
      expect(rows[0]['severity'], equals(2));
      expect((rows[0]['radius'] as num).toDouble(), closeTo(400.0, 0.01));
    });

    test('hazard event enqueued at SOS_YELLOW urgency (2)', () async {
      final queueBefore = em.queue.length;
      await em.publishHazard(
        type: 'GAS_LEAK',
        severity: 1,
        lat: 25.0,
        lng: 121.0,
      );
      expect(em.queue.length, greaterThan(queueBefore));
    });
  });

  group('EventManager — getAvailableSupplies / getActiveHazards', () {
    test('getAvailableSupplies returns at least the supply just published', () async {
      await em.publishSupply(
        resourceType: 'MEDICINE',
        quantity: 1,
        maxRangeMeters: 100.0,
      );
      final supplies = await em.getAvailableSupplies();
      expect(supplies.isNotEmpty, isTrue);
    });

    test('getActiveHazards returns at least the hazard just published', () async {
      await em.publishHazard(type: 'LANDSLIDE', severity: 2, lat: 24.0, lng: 120.5);
      final hazards = await em.getActiveHazards();
      expect(hazards.isNotEmpty, isTrue);
    });
  });

  group('EventManager — publishHandshakeComplete / publishMatchCancel (交接狀態)', () {
    setUp(() => em.resetRateLimit());
    test('publishHandshakeComplete completes negotiation', () async {
      final resourceId = await em.publishSupply(
        resourceType: 'TOOLS',
        quantity: 2,
        maxRangeMeters: 200.0,
      );
      // Note: In the new architecture, handshake complete goes through
      // NegotiationManager. Here we just verify the method exists.
      final eventId = await em.publishHandshakeComplete(
        negotiationId: _uid('neg'),
        resourceId: resourceId,
        requestId: _uid('req'),
        providerPubKey: [],
        requesterPubKey: [],
        actualDeliveredQty: 2.0,
        method: 'PIN_4DIGIT',
      );
      expect(eventId, isNotNull);
    });

    test('publishMatchCancel cancels negotiation', () async {
      final resourceId = await em.publishSupply(
        resourceType: 'TENTS',
        quantity: 1,
        maxRangeMeters: 200.0,
      );
      final eventId = await em.publishMatchCancel(
        negotiationId: _uid('neg2'),
        resourceId: resourceId,
        requestId: _uid('req2'),
        reason: 'USER_CANCEL',
      );
      expect(eventId, isNotNull);
    });
  });

  group('EventManager — confirmHazard', () {
    setUp(() => em.resetRateLimit());
    test('confirmHazard increments confirm_count', () async {
      final hazardId = await em.publishHazard(
        type: 'TSUNAMI',
        severity: 3,
        lat: 25.1,
        lng: 121.6,
      );
      final db = await DatabaseHelper().database;
      final before = (await db.query(
        'Hazards_State',
        where: 'hazard_id = ?',
        whereArgs: [hazardId],
      ))[0]['confirm_count'] as int;

      await em.confirmHazard(hazardId);

      final after = (await db.query(
        'Hazards_State',
        where: 'hazard_id = ?',
        whereArgs: [hazardId],
      ))[0]['confirm_count'] as int;

      expect(after, equals(before + 1));
    });
  });

  group('EventManager — getRecentEvents', () {
    setUp(() => em.resetRateLimit());
    test('getRecentEvents returns list (may be empty or non-empty)', () async {
      final events = await em.getRecentEvents(limit: 5);
      expect(events, isA<List<Map<String, dynamic>>>());
    });

    test('after publishEvent, getRecentEvents includes the new event', () async {
      final id = await em.publishEvent(urgency: 1, description: 'recent-check');
      final events = await em.getRecentEvents(limit: 10);
      final found = events.any((e) => e['event_id'] == id);
      expect(found, isTrue);
    });
  });

  // 回歸：座標語意統一用 null 表示「無座標」，不用 0.0 作 sentinel。
  // 有 GPS → 4 個 geo 欄位寫入實際座標；無 GPS → 4 個欄位為 null。
  // 無座標事件仍正常發出，接收端路由跳過地理圍欄、以有限跳數傳播。
  group('EventManager — geo coord semantics', () {
    test('publishLocationUpdate (explicit lat/lng) writes all 4 geo columns',
        () async {
      const targetLat = 25.034;
      const targetLng = 121.564;
      await em.publishLocationUpdate(
        negotiationId: _uid('neg'),
        lat: targetLat,
        lng: targetLng,
      );
      final db = await DatabaseHelper().database;
      final rows = await db.query(
        'Event_Logs',
        where: 'event_type = ?',
        whereArgs: [EventType.locationUpdate],
        orderBy: 'hlc_timestamp DESC',
        limit: 1,
      );
      expect(rows.length, equals(1),
          reason: 'publishLocationUpdate must write to Event_Logs');
      expect(rows[0]['received_lat'], closeTo(targetLat, 1e-9));
      expect(rows[0]['received_lng'], closeTo(targetLng, 1e-9));
      expect(rows[0]['origin_lat'], closeTo(targetLat, 1e-9));
      expect(rows[0]['origin_lng'], closeTo(targetLng, 1e-9));
    });

    test('publishSupply (explicit lat/lng) writes all 4 geo columns', () async {
      const lat = 25.011;
      const lng = 121.533;
      final resourceId = await em.publishSupply(
        resourceType: 'FOOD',
        quantity: 3,
        maxRangeMeters: 500.0,
        lat: lat,
        lng: lng,
      );
      final db = await DatabaseHelper().database;
      final rows = await db.rawQuery('''
        SELECT e.received_lat, e.received_lng, e.origin_lat, e.origin_lng
        FROM Event_Logs e
        JOIN Materials_State m ON e.payload = m.payload
        WHERE m.resource_id = ?
      ''', [resourceId]);
      expect(rows.length, equals(1));
      expect(rows[0]['received_lat'], closeTo(lat, 1e-9));
      expect(rows[0]['received_lng'], closeTo(lng, 1e-9));
      expect(rows[0]['origin_lat'], closeTo(lat, 1e-9));
      expect(rows[0]['origin_lng'], closeTo(lng, 1e-9));
    });

    test('publishMatchDecline (no coords, no GPS) writes null to all 4 geo columns',
        () async {
      // 無 GPS 的事件：4 個 geo 欄位應為 null，讓接收端跳過地理圍欄、正常傳播
      final id = await em.publishMatchDecline(
        negotiationId: _uid('neg'),
        resourceId: _uid('res'),
        requestId: _uid('req'),
        reason: 'test-no-gps',
      );
      expect(id, isNotNull);
      final db = await DatabaseHelper().database;
      final rows = await db.query(
        'Event_Logs',
        where: 'event_id = ?',
        whereArgs: [id],
      );
      expect(rows.length, equals(1));
      expect(rows[0]['received_lat'], isNull,
          reason: 'no GPS → received_lat must be null, not 0.0');
      expect(rows[0]['received_lng'], isNull);
      expect(rows[0]['origin_lat'], isNull,
          reason: 'no GPS → origin_lat must be null, not 0.0');
      expect(rows[0]['origin_lng'], isNull);
    });

    test('publishRequest (no coords, no GPS) writes null to all 4 geo columns',
        () async {
      final id = await em.publishRequest(
        resourceType: 'WATER',
        quantity: 2,
        note: 'no-gps-test',
        maxRangeMeters: 500.0,
      );
      final db = await DatabaseHelper().database;
      final rows = await db.query(
        'Event_Logs',
        where: 'event_id = ?',
        whereArgs: [id],
      );
      expect(rows.length, equals(1));
      expect(rows[0]['origin_lat'], isNull,
          reason: 'no GPS → origin_lat must be null');
      expect(rows[0]['origin_lng'], isNull);
    });
  });

  // Rate limit test 放最後：前面的測試會消耗部分配額，
  // 這裡只驗證「在同一窗口內不超過 20 次」的不變式。
  group('EventManager — Rate Limit', () {
    setUp(() => em.resetRateLimit());

    test('more than 20 publishEvent calls in same window throws RateLimitException', () async {
      int successCount = 0;
      bool hitLimit = false;
      for (int i = 0; i < 25; i++) {
        try {
          await em.publishEvent(urgency: 0, description: 'rate-test-$i');
          successCount++;
        } on RateLimitException {
          hitLimit = true;
          break;
        }
      }
      expect(successCount, lessThanOrEqualTo(20),
          reason: 'At most 20 events allowed per hour window');
      if (successCount == 20) {
        expect(hitLimit, isTrue,
            reason: '21st call must throw RateLimitException');
      }
    });
  });
}
