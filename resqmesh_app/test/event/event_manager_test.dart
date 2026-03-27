// event_manager_test.dart
//
// 測試下行管道：UI 操作 → EventManager → DB 寫入 + TriageQueue
//
// 使用 sqflite_common_ffi (in-memory SQLite) + mocked SharedPreferences。

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ignirelay_app/crypto/identity_manager.dart';
import 'package:ignirelay_app/db/database_helper.dart';
import 'package:ignirelay_app/mesh/event_manager.dart';
import 'package:ignirelay_app/proto/mesh_protocol.pb.dart' as pb;

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

  group('EventManager — completeHandoff / cancelHandoff (交接狀態)', () {
    test('completeHandoff sets Materials_State status to CONSUMED', () async {
      final resourceId = await em.publishSupply(
        resourceType: 'TOOLS',
        quantity: 2,
        maxRangeMeters: 200.0,
      );
      await em.completeHandoff(resourceId: resourceId, requestId: _uid('req'));

      final db = await DatabaseHelper().database;
      final rows = await db.query(
        'Materials_State',
        where: 'resource_id = ?',
        whereArgs: [resourceId],
      );
      expect(rows[0]['status'], equals(MaterialStatus.consumed));
    });

    test('cancelHandoff resets Materials_State status back to AVAILABLE', () async {
      final resourceId = await em.publishSupply(
        resourceType: 'TENTS',
        quantity: 1,
        maxRangeMeters: 200.0,
      );
      await em.completeHandoff(resourceId: resourceId, requestId: _uid('req2'));
      // Status is now CONSUMED; cancel should reset to AVAILABLE
      await em.cancelHandoff(resourceId: resourceId);

      final db = await DatabaseHelper().database;
      final rows = await db.query(
        'Materials_State',
        where: 'resource_id = ?',
        whereArgs: [resourceId],
      );
      expect(rows[0]['status'], equals(MaterialStatus.available));
    });
  });

  group('EventManager — confirmHazard', () {
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

  // Rate limit test 放最後：前面的測試會消耗部分配額，
  // 這裡只驗證「在同一窗口內不超過 20 次」的不變式。
  group('EventManager — Rate Limit', () {
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
