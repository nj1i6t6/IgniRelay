import 'dart:io' show gzip;
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:sqlite3/sqlite3.dart' as sql;
import 'package:vector_tile/vector_tile.dart';

/// 點擊地圖後從 MBTiles 離線圖磚中查詢最近的 POI 資訊
/// 並從獨立 poi_details.db 補充電話/營業時間/地址
class PoiQuery {
  final String mbtilesPath;
  final String? poiDetailsPath;
  PoiQuery({required this.mbtilesPath, this.poiDetailsPath});

  void dispose() {
    // DB 連線在 isolate 內管理，此處無需清理
  }

  /// 查詢可視範圍內所有 POI（用於地圖標記顯示）
  /// [bounds] 可視範圍的四個角：south, west, north, east
  /// [zoom] 當前地圖縮放等級
  /// 回傳所有 POI 屬性 Map 列表
  Future<List<Map<String, String>>> queryVisiblePois({
    required double south,
    required double west,
    required double north,
    required double east,
    required double zoom,
  }) async {
    return compute(
        _queryVisibleInIsolate,
        _VisibleQueryParams(
          dbPath: mbtilesPath,
          poiDbPath: poiDetailsPath ?? '',
          south: south,
          west: west,
          north: north,
          east: east,
          zoom: zoom,
        ));
  }

  /// 查詢點擊座標附近的最近 POI
  /// [point] 點擊的經緯度
  /// [zoom] 當前地圖縮放等級
  /// [toleranceMeters] 點擊容差（公尺），預設 50m
  /// 回傳最近的 POI 屬性 Map，找不到則回傳 null
  Future<Map<String, String>?> queryNearestPoi(
    LatLng point,
    double zoom, {
    double toleranceMeters = 50.0,
  }) async {
    return compute(
        _queryInIsolateCombined,
        _QueryParams(
          dbPath: mbtilesPath,
          poiDbPath: poiDetailsPath ?? '',
          lat: point.latitude,
          lon: point.longitude,
          zoom: zoom,
          toleranceMeters: toleranceMeters,
        ));
  }

  /// 查詢給定座標的「行政區 + 最近道路」（離線、純 MBTiles）。
  ///
  /// Stage 7：對應 plan §「DistrictRoadLookup 真實實作」。
  ///   - 行政區從 `place` 圖層擷取（取最近的 town/village/suburb 等）；
  ///   - 道路從 `transportation_name` 圖層擷取（取最近的具名 LineString）。
  ///
  /// 任一查詢失敗皆回 null（呼叫端 fallback 顯示座標）。
  Future<({String? district, String? road})> queryDistrictAndRoad(
    LatLng point, {
    double districtRadiusMeters = 8000,
    double roadRadiusMeters = 300,
  }) async {
    return compute(
        _queryDistrictRoadInIsolate,
        _DistrictRoadParams(
          dbPath: mbtilesPath,
          lat: point.latitude,
          lon: point.longitude,
          districtRadiusMeters: districtRadiusMeters,
          roadRadiusMeters: roadRadiusMeters,
        ));
  }

  /// 在 isolate 中執行行政區與道路反查。
  ///
  /// 設計重點：
  ///   - place 用 z=12（鄉鎮層級），掃 1×1 tile 已足夠涵蓋 ~3km；
  ///   - transportation_name 用 z=14（街道層級），掃 3×3 tiles 涵蓋 ~1.5km；
  ///   - 道路為 LineString，距離取「所有頂點到目標點的最小 haversine」。
  static ({String? district, String? road}) _queryDistrictRoadInIsolate(
      _DistrictRoadParams params) {
    final db = sql.sqlite3.open(params.dbPath, mode: sql.OpenMode.readOnly);
    try {
      final district =
          _findNearestPlace(db, params.lat, params.lon, params.districtRadiusMeters);
      final road =
          _findNearestRoad(db, params.lat, params.lon, params.roadRadiusMeters);
      return (district: district, road: road);
    } catch (_) {
      return (district: null, road: null);
    } finally {
      db.dispose();
    }
  }

  static String? _findNearestPlace(
      sql.Database db, double lat, double lon, double radiusM) {
    const z = 12;
    final tileX = _lngToTileX(lon, z);
    final tileY = _latToTileY(lat, z);
    final tileYtms = (1 << z) - 1 - tileY;

    String? bestName;
    double bestDist = double.infinity;

    for (int dx = -1; dx <= 1; dx++) {
      for (int dy = -1; dy <= 1; dy++) {
        final cx = tileX + dx;
        final cy = tileYtms + dy;
        if (cx < 0 || cy < 0) continue;

        final rows = db.select(
          'SELECT tile_data FROM tiles WHERE zoom_level=? AND tile_column=? AND tile_row=? LIMIT 1',
          [z, cx, cy],
        );
        if (rows.isEmpty) continue;

        Uint8List bytes;
        try {
          final raw = rows.first['tile_data'] as Uint8List;
          bytes = Uint8List.fromList(gzip.decode(raw));
        } catch (_) {
          continue;
        }
        final tile = VectorTile.fromBytes(bytes: bytes);
        for (final layer in tile.layers) {
          if (layer.name != 'place') continue;
          final extent = layer.extent;
          for (final feature in layer.features) {
            if (feature.type != VectorTileGeomType.POINT) continue;
            final geom = feature.decodeGeometry();
            if (geom == null) continue;
            List<double>? coords;
            if (geom is GeometryPoint) {
              coords = geom.coordinates;
            } else if (geom is GeometryMultiPoint) {
              final pts = geom.coordinates;
              if (pts.isNotEmpty) coords = pts.first;
            }
            if (coords == null || coords.length < 2) continue;
            final actualTileY = (1 << z) - 1 - cy;
            final fLon =
                _tileXToLng(cx, coords[0], actualTileY, z, extent, isX: true);
            final fLat = _tileYToLat(cy, coords[1], actualTileY, z, extent);
            final dist = _haversineMeters(lat, lon, fLat, fLon);
            if (dist > radiusM || dist >= bestDist) continue;

            final props = feature.decodeProperties();
            final klass = _vtStr(props['class']);
            // 偏好行政區層級：suburb > town > village > city > hamlet > 其他
            // 不接受 country/state/continent（過於宏觀）
            if (klass == 'country' || klass == 'state' || klass == 'continent') {
              continue;
            }
            final name = _vtStr(props['name']);
            if (name.isEmpty) continue;
            bestDist = dist;
            bestName = name;
          }
        }
      }
    }
    return bestName;
  }

  static String? _findNearestRoad(
      sql.Database db, double lat, double lon, double radiusM) {
    const z = 14;
    final tileX = _lngToTileX(lon, z);
    final tileY = _latToTileY(lat, z);
    final tileYtms = (1 << z) - 1 - tileY;

    String? bestName;
    double bestDist = double.infinity;

    for (int dx = -1; dx <= 1; dx++) {
      for (int dy = -1; dy <= 1; dy++) {
        final cx = tileX + dx;
        final cy = tileYtms + dy;
        if (cx < 0 || cy < 0) continue;

        final rows = db.select(
          'SELECT tile_data FROM tiles WHERE zoom_level=? AND tile_column=? AND tile_row=? LIMIT 1',
          [z, cx, cy],
        );
        if (rows.isEmpty) continue;

        Uint8List bytes;
        try {
          final raw = rows.first['tile_data'] as Uint8List;
          bytes = Uint8List.fromList(gzip.decode(raw));
        } catch (_) {
          continue;
        }
        final tile = VectorTile.fromBytes(bytes: bytes);
        for (final layer in tile.layers) {
          if (layer.name != 'transportation_name') continue;
          final extent = layer.extent;
          for (final feature in layer.features) {
            if (feature.type != VectorTileGeomType.LINESTRING) continue;
            final geom = feature.decodeGeometry();
            if (geom == null) continue;

            // 收集 line(s) 所有頂點
            List<List<double>> verts = [];
            if (geom is GeometryLineString) {
              verts = geom.coordinates;
            } else if (geom is GeometryMultiLineString) {
              for (final line in geom.coordinates) {
                verts.addAll(line);
              }
            }
            if (verts.isEmpty) continue;

            final actualTileY = (1 << z) - 1 - cy;
            double minDist = double.infinity;
            for (final v in verts) {
              if (v.length < 2) continue;
              final fLon =
                  _tileXToLng(cx, v[0], actualTileY, z, extent, isX: true);
              final fLat = _tileYToLat(cy, v[1], actualTileY, z, extent);
              final d = _haversineMeters(lat, lon, fLat, fLon);
              if (d < minDist) minDist = d;
            }
            if (minDist > radiusM || minDist >= bestDist) continue;

            final props = feature.decodeProperties();
            final name = _vtStr(props['name']);
            if (name.isEmpty) continue;
            bestDist = minDist;
            bestName = name;
          }
        }
      }
    }
    return bestName;
  }

  /// 在 isolate 中執行：避免解碼圖磚阻塞 UI
  static Map<String, String>? _queryInIsolate(_QueryParams params) {
    final db = sql.sqlite3.open(params.dbPath, mode: sql.OpenMode.readOnly);
    try {
      final z = params.zoom.floor().clamp(12, 14); // POI 只在 z12-14
      final tileX = _lngToTileX(params.lon, z);
      final tileY = _latToTileY(params.lat, z);
      final tileYtms = (1 << z) - 1 - tileY; // TMS 翻轉

      // 搜尋 3x3 鄰近 tiles 確保邊緣 POI 也找得到
      Map<String, String>? best;
      double bestDist = double.infinity;

      for (int dx = -1; dx <= 1; dx++) {
        for (int dy = -1; dy <= 1; dy++) {
          final cx = tileX + dx;
          final cy = tileYtms + dy;
          if (cx < 0 || cy < 0) continue;

          final rows = db.select(
            'SELECT tile_data FROM tiles WHERE zoom_level=? AND tile_column=? AND tile_row=? LIMIT 1',
            [z, cx, cy],
          );
          if (rows.isEmpty) continue;

          final raw = rows.first['tile_data'] as Uint8List;
          final bytes = Uint8List.fromList(gzip.decode(raw));
          final tile = VectorTile.fromBytes(bytes: bytes);

          for (final layer in tile.layers) {
            if (layer.name != 'poi') continue;
            final extent = layer.extent;

            for (final feature in layer.features) {
              if (feature.type != VectorTileGeomType.POINT) continue;
              final geom = feature.decodeGeometry();
              if (geom == null) continue;

              // 取得 tile 內座標
              List<double>? coords;
              if (geom is GeometryPoint) {
                coords = geom.coordinates;
              } else if (geom is GeometryMultiPoint) {
                final pts = geom.coordinates;
                if (pts.isNotEmpty) coords = pts.first;
              }
              if (coords == null || coords.length < 2) continue;

              // tile-local → 經緯度
              final actualTileY = (1 << z) - 1 - cy; // TMS → XYZ
              final featureLon =
                  _tileXToLng(cx, coords[0], actualTileY, z, extent, isX: true);
              final featureLat =
                  _tileYToLat(cy, coords[1], actualTileY, z, extent);

              // 計算距離
              final dist = _haversineMeters(
                params.lat,
                params.lon,
                featureLat,
                featureLon,
              );
              if (dist > params.toleranceMeters || dist >= bestDist) continue;

              final props = feature.decodeProperties();
              // 只挑有名字的 POI
              final name = _vtStr(props['name']);
              if (name.isEmpty) continue;

              bestDist = dist;
              best = {
                'name': name,
                'class': _vtStr(props['class']),
                'subclass': _vtStr(props['subclass']),
                'phone': _vtStr(props['phone']),
                'opening_hours': _vtStr(props['opening_hours']),
                'housenumber': _vtStr(props['housenumber']),
                'addr_street': _vtStr(props['addr_street']),
                'addr_city': _vtStr(props['addr_city']),
                'addr_district': _vtStr(props['addr_district']),
                'addr_full': _vtStr(props['addr_full']),
                'distance': '${dist.round()}m',
              };
            }
          }
        }
      }
      return best;
    } finally {
      db.dispose();
    }
  }

  /// 從 poi_details.db 查詢附近有詳情的 POI
  static Map<String, String>? _queryPoiDetailsDb(_QueryParams params) {
    if (params.poiDbPath.isEmpty) return null;
    final db = sql.sqlite3.open(params.poiDbPath, mode: sql.OpenMode.readOnly);
    try {
      // 用經緯度 ±0.005 (約 500m) 縮小範圍，再精確篩選
      const delta = 0.005;
      final rows = db.select(
        'SELECT lat, lon, name, class, subclass, phone, opening_hours, '
        'housenumber, addr_street, addr_city, addr_district, addr_full '
        'FROM poi_details '
        'WHERE lat BETWEEN ? AND ? AND lon BETWEEN ? AND ? '
        'LIMIT 200',
        [
          params.lat - delta,
          params.lat + delta,
          params.lon - delta,
          params.lon + delta,
        ],
      );
      if (rows.isEmpty) return null;

      Map<String, String>? best;
      double bestDist = double.infinity;

      for (final row in rows) {
        final lat = (row['lat'] as num).toDouble();
        final lon = (row['lon'] as num).toDouble();
        final dist = _haversineMeters(params.lat, params.lon, lat, lon);
        if (dist > params.toleranceMeters || dist >= bestDist) continue;

        bestDist = dist;
        best = {
          'name': (row['name'] as String?) ?? '',
          'class': (row['class'] as String?) ?? '',
          'subclass': (row['subclass'] as String?) ?? '',
          'phone': (row['phone'] as String?) ?? '',
          'opening_hours': (row['opening_hours'] as String?) ?? '',
          'housenumber': (row['housenumber'] as String?) ?? '',
          'addr_street': (row['addr_street'] as String?) ?? '',
          'addr_city': (row['addr_city'] as String?) ?? '',
          'addr_district': (row['addr_district'] as String?) ?? '',
          'addr_full': (row['addr_full'] as String?) ?? '',
          'distance': '${dist.round()}m',
        };
      }
      return best;
    } finally {
      db.dispose();
    }
  }

  /// 綜合查詢：先從 MVT 圖磚找最近 POI，再嘗試用 poi_details.db 補充詳情
  static Map<String, String>? _queryInIsolateCombined(_QueryParams params) {
    // 1. MVT 圖磚查詢 → 拿到 POI 名稱 / class / subclass
    final mvtResult = _queryInIsolate(params);

    // 2. 從 poi_details.db 查附近 POI 詳情
    final detailResult = _queryPoiDetailsDb(params);

    if (mvtResult == null && detailResult == null) return null;
    if (mvtResult == null) return detailResult;
    if (detailResult == null) return mvtResult;

    // 3. 合併：MVT 結果為底，detail DB 補充空欄位
    //    如果名稱相同或距離很近，合併 phone/hours/address
    final mvtName = mvtResult['name'] ?? '';
    final detName = detailResult['name'] ?? '';
    final namesMatch = mvtName.isNotEmpty &&
        detName.isNotEmpty &&
        (mvtName == detName ||
            mvtName.contains(detName) ||
            detName.contains(mvtName));

    final result = Map<String, String>.from(mvtResult);

    if (namesMatch ||
        (int.tryParse(detailResult['distance']?.replaceAll('m', '') ?? '999') ??
                999) <
            30) {
      // 用 detail DB 的值填充空欄位
      for (final key in [
        'phone',
        'opening_hours',
        'housenumber',
        'addr_street',
        'addr_city',
        'addr_district',
        'addr_full',
      ]) {
        if ((result[key] ?? '').isEmpty &&
            (detailResult[key] ?? '').isNotEmpty) {
          result[key] = detailResult[key]!;
        }
      }
    }

    return result;
  }

  /// 在 isolate 中查詢可視範圍內所有 POI
  static List<Map<String, String>> _queryVisibleInIsolate(
      _VisibleQueryParams params) {
    final db = sql.sqlite3.open(params.dbPath, mode: sql.OpenMode.readOnly);
    try {
      final z = params.zoom.floor().clamp(12, 14);
      final minTileX = _lngToTileX(params.west, z);
      final maxTileX = _lngToTileX(params.east, z);
      final minTileY = _latToTileY(params.north, z); // north = smaller Y
      final maxTileY = _latToTileY(params.south, z);

      final results = <Map<String, String>>[];
      final seen = <String>{};

      for (int tx = minTileX; tx <= maxTileX; tx++) {
        for (int ty = minTileY; ty <= maxTileY; ty++) {
          final tileYtms = (1 << z) - 1 - ty;
          if (tx < 0 || tileYtms < 0) continue;

          final rows = db.select(
            'SELECT tile_data FROM tiles WHERE zoom_level=? AND tile_column=? AND tile_row=? LIMIT 1',
            [z, tx, tileYtms],
          );
          if (rows.isEmpty) continue;

          final raw = rows.first['tile_data'] as Uint8List;
          final bytes = Uint8List.fromList(gzip.decode(raw));
          final tile = VectorTile.fromBytes(bytes: bytes);

          for (final layer in tile.layers) {
            if (layer.name != 'poi') continue;
            final extent = layer.extent;

            for (final feature in layer.features) {
              if (feature.type != VectorTileGeomType.POINT) continue;
              final geom = feature.decodeGeometry();
              if (geom == null) continue;

              List<double>? coords;
              if (geom is GeometryPoint) {
                coords = geom.coordinates;
              } else if (geom is GeometryMultiPoint) {
                final pts = geom.coordinates;
                if (pts.isNotEmpty) coords = pts.first;
              }
              if (coords == null || coords.length < 2) continue;

              final featureLon =
                  _tileXToLng(tx, coords[0], ty, z, extent, isX: true);
              final featureLat =
                  _tileYToLat(tileYtms, coords[1], ty, z, extent);

              // 確認在可視範圍內
              if (featureLat < params.south ||
                  featureLat > params.north ||
                  featureLon < params.west ||
                  featureLon > params.east) {
                continue;
              }

              final props = feature.decodeProperties();
              final name = _vtStr(props['name']);
              if (name.isEmpty) continue;

              // 去重（同名同位置）
              final key = '$name|${featureLat.toStringAsFixed(5)}|${featureLon.toStringAsFixed(5)}';
              if (seen.contains(key)) continue;
              seen.add(key);

              results.add({
                'name': name,
                'class': _vtStr(props['class']),
                'subclass': _vtStr(props['subclass']),
                'lat': featureLat.toString(),
                'lng': featureLon.toString(),
              });
            }
          }
        }
      }
      return results;
    } finally {
      db.dispose();
    }
  }

  // ── 工具函式 ──

  static String _vtStr(VectorTileValue? v) {
    if (v == null) return '';
    final val = v.value;
    return val.toString();
  }

  static int _lngToTileX(double lon, int z) {
    return ((lon + 180.0) / 360.0 * (1 << z)).floor();
  }

  static int _latToTileY(double lat, int z) {
    final latRad = lat * pi / 180.0;
    return ((1.0 - log(tan(latRad) + 1.0 / cos(latRad)) / pi) / 2.0 * (1 << z))
        .floor();
  }

  /// tile-local X → 經度
  static double _tileXToLng(
      int tileCol, double localX, int tileYxyz, int z, int extent,
      {bool isX = true}) {
    if (!isX) return 0;
    final tileLon = tileCol / (1 << z) * 360.0 - 180.0;
    final tileLonNext = (tileCol + 1) / (1 << z) * 360.0 - 180.0;
    return tileLon + (localX / extent) * (tileLonNext - tileLon);
  }

  /// tile-local Y → 緯度 (TMS tile_row)
  static double _tileYToLat(
      int tileRowTms, double localY, int tileYxyz, int z, int extent) {
    // XYZ tileY
    final yTop = tileYxyz;
    final latTop = _tileYToLatitude(yTop, z);
    final latBottom = _tileYToLatitude(yTop + 1, z);
    return latTop + (localY / extent) * (latBottom - latTop);
  }

  static double _tileYToLatitude(int y, int z) {
    final n = pi - 2.0 * pi * y / (1 << z);
    return 180.0 / pi * atan(0.5 * (exp(n) - exp(-n)));
  }

  static double _haversineMeters(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * pi / 180.0;
    final dLon = (lon2 - lon1) * pi / 180.0;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180.0) *
            cos(lat2 * pi / 180.0) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }
}

class _QueryParams {
  final String dbPath;
  final String poiDbPath;
  final double lat;
  final double lon;
  final double zoom;
  final double toleranceMeters;

  const _QueryParams({
    required this.dbPath,
    required this.poiDbPath,
    required this.lat,
    required this.lon,
    required this.zoom,
    required this.toleranceMeters,
  });
}

class _DistrictRoadParams {
  final String dbPath;
  final double lat;
  final double lon;
  final double districtRadiusMeters;
  final double roadRadiusMeters;

  const _DistrictRoadParams({
    required this.dbPath,
    required this.lat,
    required this.lon,
    required this.districtRadiusMeters,
    required this.roadRadiusMeters,
  });
}

class _VisibleQueryParams {
  final String dbPath;
  final String poiDbPath;
  final double south;
  final double west;
  final double north;
  final double east;
  final double zoom;

  const _VisibleQueryParams({
    required this.dbPath,
    required this.poiDbPath,
    required this.south,
    required this.west,
    required this.north,
    required this.east,
    required this.zoom,
  });
}
