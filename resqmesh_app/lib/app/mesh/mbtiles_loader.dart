import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// MBTiles 首次啟動解壓縮管理員
/// 將 asset 中的 MBTiles 複製到 app 文件目錄供 vector_map_tiles_mbtiles 使用
class MBTilesLoader {
  static const String _assetPath = 'assets/maps/taiwan_ignirelay.mbtiles';
  static const String _fileName = 'taiwan_ignirelay.mbtiles';

  static String? _cachedPath;

  /// 回傳 MBTiles 檔案的本機路徑
  /// 若檔案不存在則從 asset 複製（首次啟動會花一點時間）
  static Future<String> getLocalPath() async {
    if (_cachedPath != null && File(_cachedPath!).existsSync()) {
      return _cachedPath!;
    }

    final dir = await getApplicationDocumentsDirectory();
    final targetPath = '${dir.path}/$_fileName';
    final target = File(targetPath);

    if (!target.existsSync()) {
      // 從 Flutter asset bundle 讀取並寫入本機
      final data = await rootBundle.load(_assetPath);
      final bytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await target.writeAsBytes(bytes, flush: true);
    }

    _cachedPath = targetPath;
    return targetPath;
  }

  /// 檢查 MBTiles 是否可用
  /// 先檢查磁碟上已複製的檔案（避免將 201MB asset 載入記憶體）
  /// 再檢查 Flutter asset bundle 是否有打包
  static Future<bool> isAvailable() async {
    // 1. 先看本機磁碟有沒有（之前已複製過就不需要再載入 asset）
    try {
      final dir = await getApplicationDocumentsDirectory();
      final target = File('${dir.path}/$_fileName');
      if (target.existsSync() && target.lengthSync() > 1024) {
        return true;
      }
    } catch (_) {}

    // 2. 再試 asset bundle（首次啟動）
    try {
      await rootBundle.load(_assetPath);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 修復 MBTiles metadata 中無法被 double.parse 解析的欄位
  /// 例如 version = "3.16.0" 含多個小數點會導致 FormatException
  /// 使用 sqlite3 (同 mbtiles 套件) 避免不同 driver 造成鎖定/不一致
  static Future<void> sanitizeMetadata(String path) async {
    try {
      final db = sqlite3.sqlite3.open(path);
      try {
        final rows = db.select('SELECT name, value FROM metadata');
        for (final row in rows) {
          final name = row['name'] as String? ?? '';
          final value = row['value'] as String? ?? '';
          // 檢查 mbtiles 庫會嘗試 double.parse 的欄位
          if (['version', 'minzoom', 'maxzoom', 'center', 'bounds']
              .contains(name)) {
            // version 型如 "3.16.0" → 含多個小數點
            if (name == 'version' &&
                value.isNotEmpty &&
                '.'.allMatches(value).length > 1) {
              final parts = value.split('.');
              final fixed = '${parts[0]}.${parts[1]}';
              db.execute("UPDATE metadata SET value = ? WHERE name = ?",
                  [fixed, name]);
              debugPrint('[MBTiles] Fixed metadata $name: "$value" → "$fixed"');
            }
            // minzoom / maxzoom 應為整數，清除多餘小數點
            if ((name == 'minzoom' || name == 'maxzoom') &&
                value.isNotEmpty &&
                '.'.allMatches(value).length > 1) {
              final fixed = value.split('.').first;
              db.execute("UPDATE metadata SET value = ? WHERE name = ?",
                  [fixed, name]);
              debugPrint('[MBTiles] Fixed metadata $name: "$value" → "$fixed"');
            }
          }
        }
      } finally {
        db.dispose();
      }
    } catch (e) {
      debugPrint('[MBTiles] sanitizeMetadata error (non-fatal): $e');
    }
  }

  /// 強制重新複製（更新時用）
  static Future<void> forceRefresh() async {
    _cachedPath = null;
    final dir = await getApplicationDocumentsDirectory();
    final target = File('${dir.path}/$_fileName');
    if (target.existsSync()) await target.delete();
    await getLocalPath();
  }
}
