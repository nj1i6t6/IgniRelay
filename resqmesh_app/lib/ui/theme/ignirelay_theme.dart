// ignore_for_file: library_private_types_in_public_api
import 'package:vector_tile_renderer/vector_tile_renderer.dart';
// lightThemeData() 不在公開 API 中，直接 import src
// ignore: implementation_imports
import 'package:vector_tile_renderer/src/themes/light_theme.dart';

/// 建立 IgniRelay 烽傳專用地圖主題
/// 基於 lightTheme (OSM Liberty) 加上：
/// 1. 移除原有 POI 層 (避免搶佔 label space 導致救災圖標無法顯示)
/// 2. 救災 POI 彩色圓形圖標 (醫院/警消/學校/藥局/物資)
/// 3. 中文名稱顯示 ({name} 取代 {name_en})
/// 4. 道路標籤文字大小優化 (減少重疊)
///
/// [disabledPoi] 傳入要隱藏的 POI category ID 集合
///   (如 {'resq_hospital', 'resq_school'})，對應的圖標+文字層會被排除。
Theme buildIgniRelayTheme({Logger? logger, Set<String>? disabledPoi}) {
  final json = lightThemeData();
  final originalLayers = json['layers'] as List;
  final layers = List<dynamic>.from(originalLayers);
  json['layers'] = layers;

  // ── 1. 修補所有現有 symbol 層：name_en → name (顯示中文) ──
  for (final layer in layers) {
    if (layer is Map<String, dynamic>) {
      final layout = layer['layout'];
      if (layout is Map<String, dynamic>) {
        final textField = layout['text-field'];
        if (textField == '{name_en}') {
          layout['text-field'] = '{name}';
        }
      }
    }
  }

  // ── 2. 【關鍵修正】移除原有 POI 層 ──
  // 原有 poi_z14/z15/z16 使用不存在的 sprite (如 hospital_11)
  // → 只渲染文字 → 佔用 label space → 我們的 resq_* 圖層被碰撞偵測擋掉
  // poi_transit 也移除 (原本亮藍色太搶眼)
  final removeIds = {'poi_z14', 'poi_z15', 'poi_z16', 'poi_transit'};
  layers.removeWhere(
      (l) => l is Map<String, dynamic> && removeIds.contains(l['id']));

  // ── 3. 道路標籤拆分：major (主幹道) + minor (小路) ──
  // 找到原 road_label，複製其定義，然後拆成兩個
  final roadLabelIdx = layers
      .indexWhere((l) => l is Map<String, dynamic> && l['id'] == 'road_label');
  Map<String, dynamic>? roadLabelOriginal;
  if (roadLabelIdx >= 0) {
    roadLabelOriginal = Map<String, dynamic>.from(layers[roadLabelIdx] as Map);
    layers.removeAt(roadLabelIdx);
  }

  // ── 4. 移除 place_other 但保留 suburb 獨立層 ──
  // place_other 含 hamlet/island/islet/neighbourhood/suburb → 全刪
  // suburb 獨立恢復為新層
  layers.removeWhere(
      (l) => l is Map<String, dynamic> && l['id'] == 'place_other');

  // ── 5. 縮小 place_village 字體避免佔太多空間 ──
  for (final layer in layers) {
    if (layer is Map<String, dynamic> && layer['id'] == 'place_village') {
      final layout = layer['layout'] as Map<String, dynamic>;
      layout['text-size'] = {
        'base': 1.2,
        'stops': [
          [10, 10],
          [15, 16],
        ]
      };
      break;
    }
  }

  // ── 水體標籤 minzoom 調高 (避免縮小時顯示太多河流名) ──
  for (final layer in layers) {
    if (layer is Map<String, dynamic>) {
      final id = layer['id'] as String? ?? '';
      final sourceLayer = layer['source-layer'] as String? ?? '';
      if (id.contains('water') ||
          sourceLayer == 'water_name' ||
          sourceLayer == 'waterway') {
        if (layer['type'] == 'symbol') {
          layer['minzoom'] = 14;
        }
      }
    }
  }

  // ── 5. 救災 POI 定義 (5 類)：vector tile symbol layer 已移除（見 7A），
  // 五大類別保留於 lib/ui/screens/map/widgets/poi_category.dart 並由 Marker 渲染。

  // ── 7. 碰撞優先權排序：POI文字 > 主幹道 > 小路 > 地名 ──
  // 先渲染的 symbol 先佔據 label space → 碰撞優先權由高到低
  //
  // 7A. 救災 POI 文字層已移除 — 改用 Flutter Marker 圓點顯示五大類別 POI
  // 不再在 vector tile 層渲染彩色文字名稱（disabledPoi 過濾改由 Marker 層處理）。

  // 7B. 主幹道路名 (次高碰撞優先，minzoom 12)
  if (roadLabelOriginal != null) {
    layers.add(_roadLabelLayer(
      id: 'road_label_major',
      minzoom: 12,
      filter: [
        'in',
        'class',
        'motorway',
        'trunk',
        'primary',
      ],
      textSizeStops: [
        [12, 9],
        [14, 10],
        [18, 13],
      ],
      symbolSpacing: 400,
    ));

    // 7C. 小路路名 (碰撞優先低於主幹道，minzoom 15)
    layers.add(_roadLabelLayer(
      id: 'road_label_minor',
      minzoom: 15,
      filter: [
        '!in',
        'class',
        'motorway',
        'trunk',
        'primary',
      ],
      textSizeStops: [
        [15, 8],
        [17, 10],
        [18, 12],
      ],
      symbolSpacing: 600,
    ));
  }

  // 7D. suburb 獨立層 (minzoom 12, 小字淺色)
  layers.add({
    'id': 'place_suburb',
    'type': 'symbol',
    'source': 'openmaptiles',
    'source-layer': 'place',
    'minzoom': 12,
    'filter': ['==', 'class', 'suburb'],
    'layout': {
      'text-field': '{name}',
      'text-font': ['Roboto Condensed Italic'],
      'text-size': {
        'base': 1.2,
        'stops': [
          [12, 9],
          [15, 13],
        ]
      },
      'text-max-width': 8,
    },
    'paint': {
      'text-color': '#666',
      'text-halo-color': '#ffffff',
      'text-halo-width': 1.5,
    },
  });

  // 7E. 救災 POI 圖標層已移除 — sprites 未啟用，改用 Flutter Marker 圓點

  return ThemeReader(logger: logger).read(json);
}

/// 產生道路標籤層 (拆分主幹道/小路，各自 minzoom + 字體大小)
Map<String, dynamic> _roadLabelLayer({
  required String id,
  required int minzoom,
  required List<dynamic> filter,
  required List<List<num>> textSizeStops,
  int symbolSpacing = 400,
}) {
  return {
    'id': id,
    'type': 'symbol',
    'source': 'openmaptiles',
    'source-layer': 'transportation_name',
    'minzoom': minzoom,
    'filter': filter,
    'layout': {
      'text-field': '{name}',
      'text-font': ['Roboto Regular'],
      'text-size': {'base': 1, 'stops': textSizeStops},
      'symbol-placement': 'line',
      'text-max-width': 15,
      'symbol-spacing': symbolSpacing,
    },
    'paint': {
      'text-color': '#765',
      'text-halo-color': 'rgba(255,255,255,0.8)',
      'text-halo-width': 1.0,
    },
  };
}

// _poiIconLayer / _poiTextLayer 已不再使用：救災 POI 改由 Flutter Marker 渲染
// （見 lib/ui/screens/map/widgets/poi_category.dart 與 map_screen 的 _refreshPoiMarkers）。
// 此處原 vector tile symbol layer 保留於 git 史。
