import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';
import 'package:ignirelay_app/app/db/database_helper.dart';

class MedicalCardRepo {
  final DatabaseHelper _dbHelper;

  MedicalCardRepo(this._dbHelper);

  /// 儲存醫療卡 (JSON 字串)
  /// 使用 upsert 策略：先確保 Local_Users 記錄存在，再更新 medical_card
  Future<void> saveMedicalCard(List<int> pubKey, String medicalCardJson) async {
    final db = await _dbHelper.database;
    final pubKeyBytes = Uint8List.fromList(pubKey);
    // 先確保用戶記錄存在（ConflictAlgorithm.ignore = 已存在則不動）
    await db.insert(
      'Local_Users',
      {
        'pub_key': pubKeyBytes,
        'alias': '',
        'identity_level': 0,
        'medical_card': medicalCardJson,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    // 再更新 medical_card 欄位（此時記錄一定存在）
    await db.update(
      'Local_Users',
      {'medical_card': medicalCardJson},
      where: 'pub_key = ?',
      whereArgs: [pubKeyBytes],
    );
  }

  /// 讀取醫療卡 (JSON 字串)
  Future<String?> getMedicalCard(List<int> pubKey) async {
    final db = await _dbHelper.database;
    final pubKeyBytes = Uint8List.fromList(pubKey);
    final result = await db.query(
      'Local_Users',
      columns: ['medical_card'],
      where: 'pub_key = ?',
      whereArgs: [pubKeyBytes],
    );
    if (result.isEmpty) return null;
    return result.first['medical_card'] as String?;
  }
}
