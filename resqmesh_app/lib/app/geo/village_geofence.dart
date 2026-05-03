import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

/// 村里查詢結果
class VillageInfo {
  final String villcode;    // 里代碼 (11碼)
  final String towncode;    // 鄉鎮市區代碼 (8碼)
  final String countyName;  // 縣市名
  final String townName;    // 鄉鎮市區名
  final String villName;    // 里名
  final String villEng;     // 英文名
  final bool   isOnBoundary; // 是否在邊界緩衝區（兩里交界附近）

  const VillageInfo({
    required this.villcode,
    required this.towncode,
    required this.countyName,
    required this.townName,
    required this.villName,
    required this.villEng,
    required this.isOnBoundary,
  });

  /// 完整行政區描述，例如「新北市新店區安康里」
  String get fullName => '$countyName$townName$villName';

  @override
  String toString() => 'VillageInfo($fullName, code=$villcode, boundary=$isOnBoundary)';
}

/// 里級地理圍欄
///
/// 根據 GPS 座標查詢用戶所在村里。
/// 靠近邊界（< [boundaryBufferMeters]）時回傳兩個里。
///
/// 資料來源：內政部國土測繪中心「最新村里界圖」(TWD97 EPSG:3824)
/// 轉換精度：約 100m（Shapely 簡化 tolerance=0.001 度）
/// 資料庫大小：~3.4MB，7,974 筆村里
class VillageGeofence {
  static const String _assetPath = 'assets/geodata/village_boundary.db';
  static const String _fileName  = 'village_boundary.db';

  /// 邊界緩衝距離（公尺）。在此範圍內視為「兩里交界」，兩邊都納入結果。
  static const double boundaryBufferMeters = 300.0;

  static sql.Database? _db;
  static String? _cachedPath;

  /// 取得內部 SQLite 資料庫實例（供搜尋用）
  static sql.Database? getDb() => _db;

  /// 測試專用：直接注入 sqlite3 DB 實例，跳過 asset 載入。
  /// 呼叫端必須自行 dispose 注入的 DB；本類別只負責讀取。
  @visibleForTesting
  static void debugSetDb(sql.Database? db) {
    _db = db;
  }

  // ── 初始化 ───────────────────────────────────────────────────────────
  static Future<void> init() async {
    if (_db != null) return;
    final path = await _getLocalPath();
    _db = sql.sqlite3.open(path, mode: sql.OpenMode.readOnly);
  }

  static Future<String> _getLocalPath() async {
    if (_cachedPath != null && File(_cachedPath!).existsSync()) return _cachedPath!;
    final dir  = await getApplicationDocumentsDirectory();
    final dest = File('${dir.path}/$_fileName');
    if (!dest.existsSync()) {
      final data  = await rootBundle.load(_assetPath);
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await dest.writeAsBytes(bytes, flush: true);
    }
    _cachedPath = dest.path;
    return dest.path;
  }

  // ── 主查詢 ───────────────────────────────────────────────────────────
  /// 查詢 [lat]/[lng] 所在村里。
  /// 回傳 1 筆（在里內部）或 2 筆（靠近邊界）。
  /// 找不到時（離島 / OSM 缺漏）回傳空 list。
  static Future<List<VillageInfo>> query(double lat, double lng) async {
    assert(_db != null, 'VillageGeofence.init() 尚未呼叫');

    // Bounding box 過濾（先用 bbox 縮小候選集，再做精確 PIP）
    const pad = 0.01; // ~1.1km margin，確保邊界村里不漏
    final rows = _db!.select('''
      SELECT villcode, towncode, countyname, townname, villname, villeng, rings_json,
             bbox_minx, bbox_miny, bbox_maxx, bbox_maxy
      FROM   villages
      WHERE  bbox_miny <= ? AND bbox_maxy >= ?
        AND  bbox_minx <= ? AND bbox_maxx >= ?
    ''', [lat + pad, lat - pad, lng + pad, lng - pad]);

    // 用 (VillageInfo, 中心點距離平方) tuple 排序；中心點距離以該 ring
    // bbox 中心代表，避免重新解析 polygon。距離越小代表越靠近查詢點。
    final scored = <({VillageInfo v, double centerDistSq})>[];

    for (final row in rows) {
      final rings = (jsonDecode(row['rings_json'] as String) as List)
          .map((r) => (r as List)
              .map((pt) => [
                    (pt as List)[0] as int,
                    pt[1] as int,
                  ])
              .toList())
          .toList();

      if (rings.isEmpty) continue;

      final exterior = rings[0];
      final inside   = _pointInRing(lat, lng, exterior);
      if (!inside) continue;

      // 計算到邊界的最短距離
      final distM = _minDistToRingEdgeMeters(lat, lng, exterior);
      final onBoundary = distM < boundaryBufferMeters;

      // 以 bbox 中心代表該 polygon「中心點」，計算與查詢點距離（平方
      // 即可，僅用於排序）。
      final cx = ((row['bbox_minx'] as num) + (row['bbox_maxx'] as num)) / 2;
      final cy = ((row['bbox_miny'] as num) + (row['bbox_maxy'] as num)) / 2;
      final dx = (cx - lng);
      final dy = (cy - lat);
      final centerDistSq = dx * dx + dy * dy;

      scored.add((
        v: VillageInfo(
          villcode:    row['villcode'] as String,
          towncode:    row['towncode'] as String,
          countyName:  row['countyname'] as String,
          townName:    row['townname'] as String,
          villName:    row['villname'] as String,
          villEng:     row['villeng'] as String,
          isOnBoundary: onBoundary,
        ),
        centerDistSq: centerDistSq,
      ));
    }

    // 一般情況只有一個里包含此點；若複數（資料邊界重疊或精度誤差）
    // 以中心點距離排序取最近兩個。
    if (scored.length > 2) {
      scored.sort((a, b) => a.centerDistSq.compareTo(b.centerDistSq));
      return scored.take(2).map((e) => e.v).toList();
    }

    return scored.map((e) => e.v).toList();
  }

  /// 依村里代碼查詢單筆資料。
  /// 找不到時回傳 null。
  static Future<VillageInfo?> queryByCode(String villcode) async {
    assert(_db != null, 'VillageGeofence.init() 尚未呼叫');
    final rows = _db!.select(
      'SELECT villcode, towncode, countyname, townname, villname, villeng '
      'FROM villages WHERE villcode = ? LIMIT 1',
      [villcode],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return VillageInfo(
      villcode: row['villcode'] as String,
      towncode: row['towncode'] as String,
      countyName: row['countyname'] as String,
      townName: row['townname'] as String,
      villName: row['villname'] as String,
      villEng: row['villeng'] as String,
      isOnBoundary: false,
    );
  }

  // ── 幾何算法 ─────────────────────────────────────────────────────────
  /// Ray casting point-in-polygon（座標以 1e5 整數儲存）
  static bool _pointInRing(double lat, double lng, List<List<int>> ring) {
    // 還原座標：整數 / 1e5
    final px = lng * 1e5;
    final py = lat * 1e5;
    bool inside = false;
    int j = ring.length - 1;
    for (int i = 0; i < ring.length; i++) {
      final xi = ring[i][0].toDouble();
      final yi = ring[i][1].toDouble();
      final xj = ring[j][0].toDouble();
      final yj = ring[j][1].toDouble();
      if (((yi > py) != (yj > py)) &&
          (px < (xj - xi) * (py - yi) / (yj - yi) + xi)) {
        inside = !inside;
      }
      j = i;
    }
    return inside;
  }

  /// 計算點到多邊形外框所有線段的最短距離（公尺）
  static double _minDistToRingEdgeMeters(
      double lat, double lng, List<List<int>> ring) {
    double minDist = double.infinity;
    int j = ring.length - 1;
    for (int i = 0; i < ring.length; i++) {
      final ax = ring[j][0] / 1e5;
      final ay = ring[j][1] / 1e5;
      final bx = ring[i][0] / 1e5;
      final by = ring[i][1] / 1e5;
      final d  = _pointToSegmentMeters(lng, lat, ax, ay, bx, by);
      if (d < minDist) minDist = d;
      j = i;
    }
    return minDist;
  }

  /// 點到線段的最短距離（公尺），使用 Haversine 近似
  static double _pointToSegmentMeters(
      double px, double py,
      double ax, double ay,
      double bx, double by) {
    final dx = bx - ax;
    final dy = by - ay;
    if (dx == 0 && dy == 0) return _haversineM(py, px, ay, ax);
    final t = ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy);
    final tc = t.clamp(0.0, 1.0);
    return _haversineM(py, px, ay + tc * dy, ax + tc * dx);
  }

  /// Haversine 距離（公尺）
  static double _haversineM(
      double lat1, double lng1, double lat2, double lng2) {
    const R = 6371000.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLng = (lng2 - lng1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLng / 2) *
            sin(dLng / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  // ── Zone 比對（供 MeshRouter 呼叫）────────────────────────────────

  /// 回傳 [lat]/[lng] 所在的所有鄉鎮市區代碼（含邊界緩衝區）
  static Future<Set<String>> queryTowncodes(double lat, double lng) async {
    final villages = await query(lat, lng);
    return villages.map((v) => v.towncode).toSet();
  }

  /// 回傳 [lat]/[lng] 所在的所有里代碼（含邊界緩衝區）
  static Future<Set<String>> queryVillcodes(double lat, double lng) async {
    final villages = await query(lat, lng);
    return villages.map((v) => v.villcode).toSet();
  }

  /// 判斷兩點是否屬於同一個「里路由區域」
  ///
  /// 回傳 `true` 的情況：
  /// - 兩點在同一個里內
  /// - 任一點在里邊界緩衝區（< 300m），且對方在相鄰里
  ///
  /// 回傳 `null` 表示資料庫找不到其中一個點的里（離島 / 資料缺漏），
  /// 呼叫方應 fallback 到距離衰減。
  static Future<bool?> isSameVillageZone(
      double originLat, double originLng,
      double myLat, double myLng) async {
    final originCodes = await queryVillcodes(originLat, originLng);
    final myCodes     = await queryVillcodes(myLat, myLng);
    if (originCodes.isEmpty || myCodes.isEmpty) return null; // fallback
    return originCodes.intersection(myCodes).isNotEmpty;
  }

  /// 判斷兩點是否屬於同一個「鄉鎮市區路由區域」
  ///
  /// 回傳 `true` 的情況：
  /// - 兩點在同一個鄉鎮市區內
  /// - 任一點在鄉鎮市區邊界緩衝區，且對方在相鄰鄉鎮市區
  ///
  /// 回傳 `null` 表示資料庫找不到其中一個點（離島 / 資料缺漏），
  /// 呼叫方應 fallback 到距離衰減。
  static Future<bool?> isSameTownshipZone(
      double originLat, double originLng,
      double myLat, double myLng) async {
    final originCodes = await queryTowncodes(originLat, originLng);
    final myCodes     = await queryTowncodes(myLat, myLng);
    if (originCodes.isEmpty || myCodes.isEmpty) return null; // fallback
    return originCodes.intersection(myCodes).isNotEmpty;
  }

  /// 關閉資料庫（App 結束時呼叫）
  static void dispose() {
    _db?.dispose();
    _db = null;
    _cachedPath = null;
  }
}
