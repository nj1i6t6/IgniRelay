// debug_log_test.dart
//
// Bug 2 驗證：Debug log 持久化到 SQLite + 24h TTL + 全量匯出
// 確保 writeDebugLog / exportDebugLogs / purgeDebugLogs 正常運作

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:ignirelay_app/app/db/database_helper.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    DatabaseHelper.testDatabasePathOverride = inMemoryDatabasePath;
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() async {
    await DatabaseHelper().resetForTest();
  });

  group('DatabaseHelper — Debug Log Persistence (Bug 2)', () {
    test('writeDebugLog inserts a record', () async {
      final dbHelper = DatabaseHelper();
      // Stage 7：writeDebugLog 已可 await，移除 Future.delayed 等待 flake
      await dbHelper.writeDebugLog('TEST', 'unit test log entry');

      final logs = await dbHelper.exportDebugLogs();
      final found = logs.where((r) => r['message'] == 'unit test log entry');
      expect(found.isNotEmpty, isTrue);
    });

    test('exportDebugLogs returns records in insertion order', () async {
      final dbHelper = DatabaseHelper();
      await dbHelper.writeDebugLog('TEST', 'order-A');
      await dbHelper.writeDebugLog('TEST', 'order-B');
      await dbHelper.writeDebugLog('TEST', 'order-C');

      final logs = await dbHelper.exportDebugLogs();
      final testLogs =
          logs.where((r) => (r['message'] as String).startsWith('order-')).toList();
      expect(testLogs.length, greaterThanOrEqualTo(3));

      // 確認 A 在 B 之前，B 在 C 之前
      final idxA = testLogs.indexWhere((r) => r['message'] == 'order-A');
      final idxB = testLogs.indexWhere((r) => r['message'] == 'order-B');
      final idxC = testLogs.indexWhere((r) => r['message'] == 'order-C');
      expect(idxA, lessThan(idxB));
      expect(idxB, lessThan(idxC));
    });

    test('writeDebugLog stores source field correctly', () async {
      final dbHelper = DatabaseHelper();
      final ts = DateTime.now().microsecondsSinceEpoch;
      await dbHelper.writeDebugLog('BLE', 'ble source test $ts');
      await dbHelper.writeDebugLog('MESH', 'mesh source test $ts');

      final logs = await dbHelper.exportDebugLogs();
      final bleLogs = logs.where(
          (r) => r['source'] == 'BLE' && r['message'] == 'ble source test $ts');
      final meshLogs = logs.where(
          (r) => r['source'] == 'MESH' && r['message'] == 'mesh source test $ts');
      expect(bleLogs.isNotEmpty, isTrue);
      expect(meshLogs.isNotEmpty, isTrue);
    });

    test('purgeDebugLogs removes old entries (≥24h)', () async {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      // 插入一筆 48 小時前的記錄
      final oldTimestamp =
          DateTime.now().millisecondsSinceEpoch - (48 * 60 * 60 * 1000);
      await db.insert('Debug_Logs', {
        'timestamp': oldTimestamp,
        'source': 'TEST',
        'message': 'old-entry-for-purge-test',
      });

      final deleted = await dbHelper.purgeDebugLogs();
      expect(deleted, greaterThanOrEqualTo(1));

      // 確認舊記錄已刪除
      final logs = await dbHelper.exportDebugLogs();
      final old =
          logs.where((r) => r['message'] == 'old-entry-for-purge-test');
      expect(old.isEmpty, isTrue);
    });

    test('purgeDebugLogs keeps recent entries (<24h)', () async {
      final dbHelper = DatabaseHelper();
      await dbHelper.writeDebugLog('TEST', 'recent-keep-test');

      await dbHelper.purgeDebugLogs();

      final logs = await dbHelper.exportDebugLogs();
      final recent =
          logs.where((r) => r['message'] == 'recent-keep-test');
      expect(recent.isNotEmpty, isTrue);
    });
  });
}
