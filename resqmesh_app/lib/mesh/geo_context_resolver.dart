import 'dart:math';

enum EnvironmentType { urban, suburban, ruralMountain }

/// 台灣主要都市區中心座標 (lat, lng, 半徑 km)
class _UrbanZone {
  final String name;
  final double lat;
  final double lng;
  final double radiusKm;
  const _UrbanZone(this.name, this.lat, this.lng, this.radiusKm);
}

class GeoContextResolver {
  // ── 台灣主要都市區 ──────────────────────────────────────────
  static const _urbanZones = [
    _UrbanZone('台北市', 25.0330, 121.5654, 12),
    _UrbanZone('新北市', 25.0120, 121.4650, 20),
    _UrbanZone('桃園市', 24.9936, 121.3010, 15),
    _UrbanZone('台中市', 24.1477, 120.6736, 15),
    _UrbanZone('台南市', 22.9998, 120.2270, 14),
    _UrbanZone('高雄市', 22.6273, 120.3014, 16),
    _UrbanZone('基隆市', 25.1276, 121.7392, 6),
    _UrbanZone('新竹市', 24.8138, 120.9675, 7),
    _UrbanZone('嘉義市', 23.4801, 120.4491, 5),
    _UrbanZone('屏東市', 22.6820, 120.4889, 6),
    _UrbanZone('花蓮市', 23.9769, 121.6044, 6),
    _UrbanZone('宜蘭市', 24.7570, 121.7533, 5),
  ];

  // ── 台灣中央山脈高海拔區域 (粗略邊界) ────────────────────────
  // lat 範圍大致 22.5~24.5, lng 範圍 120.8~121.3 且內陸
  static bool _isHighMountain(double lat, double lng) {
    // 中央山脈主脊線 (粗估)
    if (lat < 22.3 || lat > 24.6) return false;
    if (lng < 120.7 || lng > 121.4) return false;

    // 計算距離西海岸線的比例 (粗估)
    // 台灣西岸約 120.2°E，東岸約 121.6°E
    final westRatio = (lng - 120.2) / (121.6 - 120.2);
    // 中部山區約佔 0.35~0.75 的東西向範圍
    return westRatio > 0.35 && westRatio < 0.75 && lat > 22.5 && lat < 24.5;
  }

  static double _haversineKm(
      double lat1, double lng1, double lat2, double lng2) {
    const R = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLng = (lng2 - lng1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLng / 2) *
            sin(dLng / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  /// 根據座標判斷地理環境類型，回傳建議覆蓋半徑
  /// URBAN: 1000m, SUBURBAN: 5000m, MOUNTAIN: 15000m
  Future<Map<String, dynamic>> resolveContext(double lat, double lng) async {
    // 1. 先檢查是否在高山區域
    if (_isHighMountain(lat, lng)) {
      return {
        'environment_type': 'RURALMOUNTAIN',
        'suggested_range_meters': 15000.0,
        'nearest_place_class': 'mountain',
      };
    }

    // 2. 檢查距離最近的都市中心
    double minDistKm = double.infinity;
    String nearestCity = 'unknown';
    double nearestRadius = 0;

    for (final zone in _urbanZones) {
      final dist = _haversineKm(lat, lng, zone.lat, zone.lng);
      if (dist < minDistKm) {
        minDistKm = dist;
        nearestCity = zone.name;
        nearestRadius = zone.radiusKm;
      }
    }

    // 3. 根據距離都市中心判斷環境類型
    if (minDistKm <= nearestRadius) {
      return {
        'environment_type': 'URBAN',
        'suggested_range_meters': 1000.0,
        'nearest_place_class': nearestCity,
      };
    } else if (minDistKm <= nearestRadius * 2.5) {
      return {
        'environment_type': 'SUBURBAN',
        'suggested_range_meters': 5000.0,
        'nearest_place_class': nearestCity,
      };
    } else {
      return {
        'environment_type': 'RURALMOUNTAIN',
        'suggested_range_meters': 15000.0,
        'nearest_place_class': nearestCity,
      };
    }
  }
}
