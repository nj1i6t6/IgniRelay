import 'package:sqflite/sqflite.dart';
import 'package:ignirelay_app/app/db/database_helper.dart';

class ProfileRepo {
  ProfileRepo({required DatabaseHelper databaseHelper})
      : _dbHelper = databaseHelper;

  final DatabaseHelper _dbHelper;
  Future<Database> get _database => _dbHelper.database;

  Future<List<Map<String, dynamic>>> exportDebugLogs() async {
    return _dbHelper.exportDebugLogs();
  }

  Future<void> purgeDebugLogs() async {
    await _dbHelper.purgeDebugLogs();
  }

  Future<void> writeDebugLog(String tag, String message) async {
    await _dbHelper.writeDebugLog(tag, message);
  }

  Future<Map<String, dynamic>?> queryLocalProfile(List<int> pubKey) async {
    final db = await _database;
    final rows =
        await db.query('Local_Users', where: 'pub_key = ?', whereArgs: [pubKey]);
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<String?> getMedicalCard(List<int> pubKey) async {
    return _dbHelper.getMedicalCard(pubKey);
  }
}
