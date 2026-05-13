import 'package:sqflite/sqflite.dart';
import 'package:ignirelay_app/app/db/database_helper.dart';

class StationSupplyRepo {
  StationSupplyRepo({required DatabaseHelper databaseHelper})
      : _dbHelper = databaseHelper;

  final DatabaseHelper _dbHelper;
  Future<Database> get _database => _dbHelper.database;

  Future<List<Map<String, dynamic>>> queryStationQuotas(
      {String? stationId}) async {
    final db = await _database;
    if (stationId != null) {
      return db.query('Station_Quotas',
          where: 'station_resource_id = ?', whereArgs: [stationId]);
    }
    return db.query('Station_Quotas');
  }

  Future<void> updateStationQuota(
      String stationId, String category, int newQuota) async {
    final db = await _database;
    await db.update(
      'Station_Quotas',
      {
        'used_quantity': newQuota,
        'last_reset_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'station_resource_id = ? AND category = ?',
      whereArgs: [stationId, category],
    );
  }

  Future<void> resetStationUsage(String stationId) async {
    final db = await _database;
    await db.update(
      'Station_Quotas',
      {
        'used_quantity': 0,
        'last_reset_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'station_resource_id = ?',
      whereArgs: [stationId],
    );
  }

  Future<Map<String, dynamic>?> queryStation(String stationId) async {
    final db = await _database;
    final rows = await db.query('Station_Quotas',
        where: 'station_resource_id = ?', whereArgs: [stationId]);
    return rows.isNotEmpty ? rows.first : null;
  }
}
