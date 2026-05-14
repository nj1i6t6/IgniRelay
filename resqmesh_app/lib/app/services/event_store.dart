import 'package:sqflite/sqflite.dart';
import 'package:ignirelay_app/app/db/database_helper.dart';
import 'package:ignirelay_app/app/mesh/event_types.dart';

class EventStore {
  EventStore({required DatabaseHelper databaseHelper})
      : _dbHelper = databaseHelper;

  final DatabaseHelper _dbHelper;
  Future<Database> get _database => _dbHelper.database;

  Future<List<Map<String, dynamic>>> queryRecentSos({
    Duration window = const Duration(hours: 24),
    int minUrgency = 2,
  }) async {
    final db = await _database;
    final cutoff = DateTime.now().subtract(window).millisecondsSinceEpoch;
    return db.query(
      'Event_Logs',
      where: 'event_type = ? AND urgency >= ? AND hlc_timestamp > ?',
      whereArgs: [EventType.requestBroadcast, minUrgency, cutoff],
      orderBy: 'hlc_timestamp DESC',
    );
  }

  Future<List<Map<String, dynamic>>> queryByType(int eventType,
      {int limit = 100}) async {
    final db = await _database;
    return db.query(
      'Event_Logs',
      where: 'event_type = ?',
      whereArgs: [eventType],
      orderBy: 'hlc_timestamp DESC',
      limit: limit,
    );
  }

  Future<Map<String, dynamic>?> queryById(String eventId) async {
    final db = await _database;
    final rows =
        await db.query('Event_Logs', where: 'event_id = ?', whereArgs: [eventId]);
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<List<Map<String, dynamic>>> queryRecent({int limit = 20}) async {
    final db = await _database;
    return db.query('Event_Logs', orderBy: 'hlc_timestamp DESC', limit: limit);
  }

  Future<List<Map<String, dynamic>>> queryMarkersInBounds({
    required double south,
    required double west,
    required double north,
    required double east,
    List<int>? eventTypes,
  }) async {
    final db = await _database;
    String where = 'lat >= ? AND lat <= ? AND lng >= ? AND lng <= ?';
    List<dynamic> whereArgs = [south, north, west, east];
    if (eventTypes != null && eventTypes.isNotEmpty) {
      final placeholders = List.filled(eventTypes.length, '?').join(',');
      where += ' AND event_type IN ($placeholders)';
      whereArgs.addAll(eventTypes);
    }
    return db.query('Event_Logs',
        where: where, whereArgs: whereArgs, orderBy: 'hlc_timestamp DESC');
  }

  Future<List<Map<String, dynamic>>> queryMarkersWithLocation({
    int limit = 100,
    int? excludeEventType,
  }) async {
    final db = await _database;
    final cutoff = DateTime.now().millisecondsSinceEpoch - (24 * 3600 * 1000);
    String where = 'hlc_timestamp > ? AND received_lat IS NOT NULL AND received_lng IS NOT NULL';
    List<dynamic> whereArgs = [cutoff];
    if (excludeEventType != null) {
      where += ' AND event_type != ?';
      whereArgs.add(excludeEventType);
    }
    return db.query(
      'Event_Logs',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'urgency DESC, hlc_timestamp DESC',
      limit: limit,
    );
  }

  /// 查詢具備座標的「非 hazard」事件 marker（給地圖 overlay 用）。
  ///
  /// Stage 1 corrective：原本 UI 端要傳 `excludeEventType: EventType.hazardMarker`，
  /// 但這會強迫 UI import `app/mesh/event_types.dart` 違反 `ui-cannot-import-mesh`。
  /// 這裡把語意收進來，UI 不再需要懂 EventType 數值。
  Future<List<Map<String, dynamic>>> queryNonHazardMarkersWithLocation({
    int limit = 100,
  }) {
    return queryMarkersWithLocation(
      limit: limit,
      excludeEventType: EventType.hazardMarker,
    );
  }

  /// 查詢「resourceRegister」型事件（給據點物資畫面列出我發布的據點）。
  Future<List<Map<String, dynamic>>> queryResourceRegisters({int limit = 100}) {
    return queryByType(EventType.resourceRegister, limit: limit);
  }
}
