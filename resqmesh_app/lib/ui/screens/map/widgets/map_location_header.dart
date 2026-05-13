import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'package:ignirelay_app/app/map/poi_query.dart';
import 'package:ignirelay_app/ui/theme/igni_colors.dart';
import 'package:ignirelay_app/ui/theme/igni_typography.dart';

/// Stage 4d：地圖左上「你在哪」覆蓋層。
///
/// plan §Stage 4d L223：
/// > 左上改行政區+最近道路（離線反查；做不到 fallback 座標 mono 小字）。
///
/// 實作策略（離線、無網路）：
///   1. 若 `poiQuery` 非 null 且使用者位置已知，嘗試以半徑 300m 內最近的
///      「place/road/boundary」圖徵作行政區與路名推測。
///   2. 任一步失敗就 fallback 成座標 mono（`lat, lng` 六位小數）。
///   3. `userLocation` 為 null 時顯示「--- , ---」佔位字樣，維持版面穩定。
///
/// 此 widget 是 presentation-only：所有非同步查詢由父層執行並以 [district]
/// 與 [road] 注入，以便測試與效能調優（避免 rebuild 時重跑 query）。
class MapLocationHeader extends StatelessWidget {
  const MapLocationHeader({
    super.key,
    required this.userLocation,
    required this.district,
    required this.road,
  });

  final LatLng? userLocation;

  /// 行政區名稱（e.g.「花蓮縣光復鄉」）。查詢不到請傳 null。
  final String? district;

  /// 最近道路（e.g.「中山路」）。查詢不到請傳 null。
  final String? road;

  @override
  Widget build(BuildContext context) {
    final p = context.igni;
    final hasLookup = district != null || road != null;

    String primary;
    String? secondary;
    if (userLocation == null) {
      primary = '---';
    } else if (hasLookup) {
      primary = [district, road].whereType<String>().join(' · ');
      secondary = _coordMono(userLocation!);
    } else {
      // fallback：座標 mono 小字
      primary = _coordMono(userLocation!);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: p.bg1.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: p.border1, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            primary,
            style: hasLookup
                ? IgniTypography.labelLarge(p.text0)
                : IgniTypography.monoSmall(p.text1),
          ),
          if (secondary != null)
            Text(secondary, style: IgniTypography.monoSmall(p.text3)),
        ],
      ),
    );
  }

  static String _coordMono(LatLng l) =>
      '${l.latitude.toStringAsFixed(5)}, ${l.longitude.toStringAsFixed(5)}';
}

/// 以 PoiQuery 嘗試反查行政區與道路。離線 MBTiles 無此能力時回 (null,null)。
///
/// 放在此檔是為了讓 header widget 的資料依賴集中，避免 map_screen 再長。
class DistrictRoadLookup {
  DistrictRoadLookup._();

  static Future<(String?, String?)> lookup({
    required PoiQuery? poiQuery,
    required LatLng location,
  }) async {
    if (poiQuery == null) return (null, null);
    try {
      // Stage 7：實接 PoiQuery.queryDistrictAndRoad（離線 vector tile 反查）。
      // place 圖層 → 行政區，transportation_name 圖層 → 最近道路。
      final result = await poiQuery.queryDistrictAndRoad(location);
      return (result.district, result.road);
    } catch (_) {
      return (null, null);
    }
  }
}
