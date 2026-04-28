// village_geofence_sort_test.dart
//
// P0-4 回歸：VillageGeofence.query 在多個 polygon 都包含查詢點時，
// 必須以「bbox 中心離查詢點最近的兩個」回傳 — 而非任意兩個。
//
// 之前的 bug：`results.sort((a, b) => 0)` 等同不排序，take(2) 取得的
// 是 SQLite scan 順序的前兩筆。本測試造一個 4 個重疊 polygon 的合成
// SQLite 資料庫，驗證 query 真的把離得最近的兩個排在前面。

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import 'package:ignirelay_app/app/geo/village_geofence.dart';

void main() {
  // 4 個矩形 polygon，全部都包含查詢點 (lat=25.000, lng=121.500)。
  // 設計：以 bbox 中心離查詢點越遠 → 應排越後面。
  //
  //  - "very_close":   center (lat=25.001, lng=121.501) → ~140m
  //  - "close":        center (lat=25.005, lng=121.505) → ~700m
  //  - "mid":          center (lat=25.020, lng=121.520) → ~2.8km
  //  - "far":          center (lat=25.080, lng=121.580) → ~11km
  //
  // 預期排序：[very_close, close]（取最近兩個）。

  late sql.Database db;

  setUpAll(() {
    db = sql.sqlite3.openInMemory();
    db.execute('''
      CREATE TABLE villages (
        villcode TEXT PRIMARY KEY,
        towncode TEXT,
        countyname TEXT,
        townname TEXT,
        villname TEXT,
        villeng TEXT,
        rings_json TEXT,
        bbox_minx REAL,
        bbox_miny REAL,
        bbox_maxx REAL,
        bbox_maxy REAL
      )
    ''');

    // 為了讓 4 個 polygon 都包含查詢點 (25.0, 121.5)，每個都用一個
    // 涵蓋查詢點的大矩形（不同大小不同中心）。bbox 必須與 ring 相符
    // 才能通過 bounding box 預過濾。
    void insertRect(
      String code,
      double minLat, double minLng,
      double maxLat, double maxLng,
    ) {
      // ring 用 lng/lat 順序的 1e5 整數座標（與 production 對齊）
      final ring = [
        [(minLng * 1e5).round(), (minLat * 1e5).round()],
        [(maxLng * 1e5).round(), (minLat * 1e5).round()],
        [(maxLng * 1e5).round(), (maxLat * 1e5).round()],
        [(minLng * 1e5).round(), (maxLat * 1e5).round()],
        [(minLng * 1e5).round(), (minLat * 1e5).round()],
      ];
      final ringsJson = jsonEncode([ring]);
      db.execute(
        'INSERT INTO villages '
        '(villcode, towncode, countyname, townname, villname, villeng, '
        'rings_json, bbox_minx, bbox_miny, bbox_maxx, bbox_maxy) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          code, 'TOWN', 'County', 'Town', code, code,
          ringsJson, minLng, minLat, maxLng, maxLat,
        ],
      );
    }

    // 都包含 (25.000, 121.500)，bbox 中心遠近不同
    // very_close: center ≈ (25.001, 121.501)
    insertRect('very_close', 24.999, 121.499, 25.003, 121.503);
    // close:      center ≈ (25.0035, 121.5035)
    insertRect('close', 24.998, 121.498, 25.009, 121.509);
    // mid:        center ≈ (25.010, 121.510)
    insertRect('mid', 24.990, 121.490, 25.030, 121.530);
    // far:        center ≈ (25.040, 121.540)
    insertRect('far', 24.980, 121.480, 25.100, 121.600);

    VillageGeofence.debugSetDb(db);
  });

  tearDownAll(() {
    VillageGeofence.debugSetDb(null);
    db.dispose();
  });

  test('query 回傳最近兩個（不是任意兩個）', () async {
    final results = await VillageGeofence.query(25.000, 121.500);

    // 4 個都包含查詢點 → 必須排序後 take(2)
    expect(results.length, equals(2),
        reason: '當 >2 polygon 包含查詢點時應 take(2)');
    final codes = results.map((v) => v.villcode).toList();
    expect(codes, equals(['very_close', 'close']),
        reason: '回傳必須是離 bbox 中心最近的兩個（升序）');
  });

  test('query 在單一 polygon 包含查詢點時不會 take(2)', () async {
    // 查詢點只在 "far" 內（其它三個 bbox 都不含此點）
    final results = await VillageGeofence.query(25.090, 121.590);
    expect(results.length, equals(1));
    expect(results.first.villcode, equals('far'));
  });
}
