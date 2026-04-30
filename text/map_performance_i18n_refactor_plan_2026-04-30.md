# 地圖效能與多語系重構實作企畫書

日期：2026-04-30

專案位置：`C:\Users\radio\Downloads\IDE\CoReM\resqmesh_app`

目的：提供給實作 Agent 依階段完成重構。範圍限於地圖效能、地圖多語、地圖深淺色、聊天室名稱多語。

## 1. 實作目標

### 1.1 地圖效能

完成後應達到：

1. 拖曳地圖期間不查 visible POI。
2. 拖曳地圖期間不因 POI 更新重建整個 `FlutterMap`。
3. 拖曳停止約 400 至 500ms 後才刷新 POI。
4. POI 更新只重建 POI layer。
5. `VectorTileLayer` 只在 MBTiles ready、theme generation、locale、brightness 或圖層設定改變時重建。
6. 保留現有 hazard、event、self marker、marking preview 功能。

### 1.2 地圖 label 多語

完成後應達到：

1. UI locale 是中文時，地圖 label 使用繁體中文。
2. UI locale 非中文時，若 MBTiles 支援該語言，地圖 label 使用該語言。
3. UI locale 非中文且 MBTiles 不支援該語言時，地圖 label fallback 英文。
4. 若 renderer 支援 Mapbox expression，使用 per-feature fallback。
5. 若 renderer 不支援 expression，使用 locale-level 欄位切換並記錄限制。

### 1.3 地圖深淺色

完成後應達到：

1. UI light mode 顯示亮色地圖。
2. UI dark mode 顯示暗色地圖。
3. 切換深淺色時重建 map theme，但不重新載入 MBTiles。
4. hazard、event、POI、self marker 在 light / dark 地圖上都清楚可辨識。

### 1.4 聊天室名稱多語

完成後應達到：

1. UI locale 是中文時，聊天室名稱顯示繁體中文。
2. UI locale 非中文時，聊天室名稱一律顯示英文。
3. `Chat_Rooms.room_name` 只作 fallback，不作為本地化顯示唯一來源。
4. 已存在 DB 裡的中文 `room_name` 不影響切換英文顯示。
5. 自訂聊天室保留使用者原輸入名稱，不自動翻譯。

## 2. 目前架構與資料來源

### 2.1 地圖相關檔案

| 類型 | 檔案 |
| --- | --- |
| 地圖頁 | `lib/ui/screens/map/map_screen.dart` |
| 地圖狀態控制器 | `lib/ui/screens/map/map_screen_controller.dart` |
| FlutterMap 渲染 widget | `lib/ui/screens/map/widgets/map_view.dart` |
| 地圖 VM | `lib/ui/screens/map/models/map_view_models.dart` |
| 地圖 theme builder | `lib/ui/theme/ignirelay_theme.dart` |
| POI 查詢 | `lib/app/mesh/poi_query.dart` |
| 圖層設定 | `lib/ui/sheets/map_layer_settings.dart` |

### 2.2 聊天室相關檔案

| 類型 | 檔案 |
| --- | --- |
| 聊天室服務 | `lib/app/services/chat_service.dart` |
| 聊天室列表 | `lib/ui/screens/chat/chat_list_screen.dart` |
| 聊天室房間頁 | `lib/ui/screens/chat/chat_room_screen.dart` |
| 加入聊天室頁 | `lib/ui/screens/chat/chat_join_screen.dart` |
| 村里地理圍欄 | `lib/app/geo/village_geofence.dart` |
| DB schema | `lib/app/db/database_helper.dart` |

### 2.3 資料檔

| 資料 | 檔案 | 用途 |
| --- | --- | --- |
| 離線向量地圖 | `assets/maps/taiwan_ignirelay.mbtiles` | 底圖與地圖 label |
| POI 詳情 | `assets/maps/poi_details.db` | POI sheet 詳情 |
| 村里界 | `assets/geodata/village_boundary.db` | 聊天室地理範圍與村里英文名 |
| 亮色地圖樣式 | `assets/style/bright_map_style.json` | light map style 候選來源 |
| 暗色地圖樣式 | `assets/style/dark_map_style.json` | dark map style 候選來源 |

### 2.4 已確認資料能力

MBTiles 是 OpenMapTiles schema。主要 label layer 有多語欄位：

| layer | 語言欄位 |
| --- | --- |
| `place` | `name`, `name:en`, `name_en`, `name:zh`, `name:zh-Hans`, `name:zh-Hant` 及多種其他語言 |
| `transportation_name` | `name`, `name:en`, `name_en`, `name:zh`, `name:zh-Hans`, `name:zh-Hant` 等 |
| `poi` | `name`, `name:en`, `name_en`, `name:zh`, `name:zh-Hans`, `name:zh-Hant` 等 |
| `water_name` | 多語欄位可用 |
| `waterway` | 多語欄位可用 |
| `park` | 多語欄位可用 |
| `mountain_peak` | 多語欄位可用 |

`village_boundary.db` 的 `villages` 表有 `villeng`，但沒有 `countyeng` 或 `towneng`。聊天室完整英文名稱需要補縣市與鄉鎮區英文對照。

## 3. 實作階段總覽

| Phase | 目標 | 必做 | 主要檔案 |
| --- | --- | --- | --- |
| Phase 0 | 基線與測試保護 | 是 | tests |
| Phase 1 | 拖曳 idle refresh | 是 | `map_view.dart`, `map_screen_controller.dart` |
| Phase 2 | 拆 MapView rebuild 邊界 | 是，POI notifier 必做，其餘 notifier 視實測追加 | `map_view.dart`, `map_screen_controller.dart` |
| Phase 3 | POI 查詢空間索引 | 條件式，Phase 1+2 後 idle refresh 仍 > 500ms 才做 | `poi_query.dart`, `tool/`, `assets/maps/` |
| Phase 4 | 地圖 label 多語 | 是 | `ignirelay_theme.dart`, `map_screen_controller.dart`, `map_screen.dart` |
| Phase 5 | 地圖 light/dark theme | 是 | `ignirelay_theme.dart` |
| Phase 6 | 聊天室名稱多語 | 是 | chat screens, resolvers, l10n |
| Phase 7 | 整合驗收 | 是 | app build / emulator |

## 4. Phase 0：基線與測試保護

### 4.1 目的

建立目前狀態基線，讓後續跨檔案重構可驗證。

### 4.2 必跑指令

在 `resqmesh_app` 執行：

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

若現有測試已失敗，需記錄原始失敗項目後再開始修改。

### 4.3 測試規劃

Phase 0 只記錄測試計畫與目前基線，不要求先建立尚未有 source 的測試檔。各測試應在對應 Phase 內先寫測試再實作。

| 測試檔 | 目的 |
| --- | --- |
| `test/map_label_language_test.dart` | 驗證 locale 到 map label 欄位的解析規則 |
| `test/admin_name_resolver_test.dart` | 驗證 county/town/village 名稱解析 |
| `test/room_display_name_resolver_test.dart` | 驗證聊天室名稱中英文規則 |
| `test/ignirelay_theme_test.dart` | 驗證 theme builder 可在不同 locale / brightness 產生 theme |

### 4.4 完成標準

1. 已記錄 analyze/test/build 基線。
2. 必要測試檔已規劃清楚，並安排到對應 Phase 建立。
3. 未改變 app runtime 行為。

## 5. Phase 1：拖曳期間停止 POI refresh

### 5.1 目的

解決最主要的卡頓來源：拖曳中持續排 POI 查詢。

### 5.2 修改檔案

| 檔案 | 修改內容 |
| --- | --- |
| `lib/ui/screens/map/widgets/map_view.dart` | `_reportViewport()` 接收 `hasGesture`，`onPositionChanged` 傳入 `hasGesture` |
| `lib/ui/screens/map/map_screen_controller.dart` | `setViewport()` 接收 `hasGesture`，改成 idle debounce 後刷新 POI |

### 5.3 建議實作

`map_view.dart`：

```dart
void _reportViewport({bool hasGesture = false}) {
  if (!mounted) return;
  try {
    final cam = _flutterMapController.camera;
    widget.controller.setViewport(
      zoom: cam.zoom,
      bounds: cam.visibleBounds,
      ready: _ready,
      hasGesture: hasGesture,
    );
  } catch (e) {
    debugPrint('[MapView] viewport read skipped: $e');
  }
}
```

`onMapReady`：

```dart
_reportViewport(hasGesture: false);
```

`onPositionChanged`：

```dart
onPositionChanged: (pos, hasGesture) {
  _reportViewport(hasGesture: hasGesture);
},
```

`map_screen_controller.dart`：

```dart
Timer? _poiIdleTimer;

void setViewport({
  required double zoom,
  required LatLngBounds bounds,
  required bool ready,
  bool hasGesture = false,
}) {
  final wasReady = _mapReady;
  _mapReady = ready;
  _viewportZoom = zoom;
  _viewportBounds = bounds;

  if (!ready) return;

  if (!wasReady) {
    requestPoiRefresh();
    return;
  }

  _schedulePoiRefreshAfterIdle(
    hasGesture ? const Duration(milliseconds: 500) : const Duration(milliseconds: 350),
  );
}

void _schedulePoiRefreshAfterIdle(Duration delay) {
  _poiIdleTimer?.cancel();
  _poiIdleTimer = Timer(delay, () {
    unawaited(_doRefreshPoi());
  });
}
```

### 5.4 注意事項

1. `dispose()` 必須 cancel `_poiIdleTimer`。
2. 拖曳中不要清空 `_pois`。
3. zoom < 12 的清空邏輯保留，但只在 idle 後執行。
4. idle timer 到時直接呼叫 `unawaited(_doRefreshPoi())`，不要再走 `requestPoiRefresh()`，避免 500ms idle 加 300ms request debounce 變成 800ms 延遲。
5. 初次 map ready 與圖層設定變更仍可使用 `requestPoiRefresh()`，拖曳 idle refresh 才需要跳過二次 debounce。

### 5.5 完成標準

1. 連續拖曳期間 `_doRefreshPoi()` 不連續觸發。
2. 停止拖曳約 400 至 500ms 後 POI 開始更新，不再額外等待 `requestPoiRefresh()` 的 300ms debounce。
3. 拖曳期間 marker 不閃爍、不清空。
4. `flutter analyze` 通過。

## 6. Phase 2：拆分 MapView rebuild 邊界

### 6.1 目的

先避免 POI 更新重建整個 `FlutterMap` 與 `VectorTileLayer`。POI 是拖曳卡頓的高頻來源，必須先拆。self、hazards、events、base map notifier 的 ROI 較低，可在 POI 拆分驗收後依實測結果追加。

### 6.2 修改檔案

| 檔案 | 修改內容 |
| --- | --- |
| `lib/ui/screens/map/map_screen_controller.dart` | 新增 POI notifier，視實測追加其他 notifier |
| `lib/ui/screens/map/widgets/map_view.dart` | 讓 POI layer 獨立 listen，避免 POI 更新觸發整張 map rebuild |
| `lib/ui/screens/map/models/map_view_models.dart` | 只有要拆 base map notifier 時才新增 `MapBaseVm` |

### 6.3 Notifier 設計

第一階段只加 POI notifier：

```dart
final ValueNotifier<List<PoiVm>> poiNotifier = ValueNotifier<List<PoiVm>>(const []);
```

POI 拆分驗收後，若仍有明顯 rebuild 卡頓，再追加：

```dart
final ValueNotifier<List<HazardVm>> hazardNotifier = ValueNotifier<List<HazardVm>>(const []);
final ValueNotifier<List<EventVm>> eventNotifier = ValueNotifier<List<EventVm>>(const []);
final ValueNotifier<SelfLocationVm?> selfLocationNotifier = ValueNotifier<SelfLocationVm?>(null);
final ValueNotifier<MarkingDraftVm> markingNotifier = ValueNotifier<MarkingDraftVm>(MarkingDraftVm.idle);
```

base map notifier 暫列後續優化，不作為 Phase 2 必做。通常只要 POI notifier 拆出來即可達成主要效能改善。若實測仍需要，再新增 base map VM：

```dart
class MapBaseVm {
  const MapBaseVm({
    required this.mbTilesState,
    required this.tileProviders,
    required this.mapTheme,
  });

  final MbTilesStateVm mbTilesState;
  final TileProviders? tileProviders;
  final vtr.Theme? mapTheme;
}
```

若採用 base map notifier，再在 controller 加入：

```dart
final ValueNotifier<MapBaseVm> baseMapNotifier = ValueNotifier<MapBaseVm>(MapBaseVm.initial());
```

### 6.4 實作順序

1. 必做：先拆 POI。
2. 驗收：拖曳是否已足夠流暢。
3. 若仍有明顯 rebuild 卡頓，再拆 self location。
4. 若 mesh overlay 更新仍造成卡頓，再拆 hazards / events。
5. base map notifier 最後再做，且只在必要時做。

POI 更新時：

```dart
_pois = list;
poiNotifier.value = list;
```

不要再因 POI 更新呼叫 `_safeNotify()`。

若需要拆 hazards / events，更新時：

```dart
_hazards = list;
hazardNotifier.value = list;
```

```dart
_events = list;
eventNotifier.value = list;
```

若需要拆 self location，GPS 更新時：

```dart
_selfLocation = SelfLocationVm(location: l, accuracyMeters: pos.accuracy);
selfLocationNotifier.value = _selfLocation;
```

### 6.5 `map_view.dart` 目標結構

第一階段保留 `map_view.dart` 目前外層 `ListenableBuilder(listenable: c)`，不要直接移除。只把 POI layer 改成內層 `ValueListenableBuilder<List<PoiVm>>`，並讓 `_doRefreshPoi()` 更新 `poiNotifier` 時不呼叫 `_safeNotify()`。如此 POI 更新不會觸發外層 builder，但 hazards/events/self/marking/base map 仍維持原本 controller notify 行為。

目標結構：

```dart
return ListenableBuilder(
  listenable: c,
  builder: (ctx, _) {
    return FlutterMap(
      mapController: _flutterMapController,
      options: MapOptions(...),
      children: [
        ...baseMapHazardEventSelfAndMarkingLayersFromController,
        ValueListenableBuilder<List<PoiVm>>(
          valueListenable: c.poiNotifier,
          builder: (_, pois, __) {
            final markers = PoiOverlay.build(pois: pois, onTap: widget.onPoiTap);
            return MarkerLayer(markers: markers);
          },
        ),
      ],
    );
  },
);
```

上述 `...baseMapHazardEventSelfAndMarkingLayersFromController` 是文字占位，意思是保留目前 `MapView.build()` 中已有的 `VectorTileLayer`、`CircleLayer`、`PolygonLayer`、`MarkerLayer`、`MarkerClusterLayerWidget` 等 layer 計算原樣，不是現有 method 名稱，也不要求新增這個 method。

後續若實測仍卡，再逐一把 hazards/events/self/marking 從外層 builder 中拆成各自 notifier，並同步移除對應資料更新時的 `_safeNotify()`。

### 6.6 注意事項

1. 不要移除 `map_view.dart` 現有外層 `ListenableBuilder(listenable: c)`，除非同一階段也已把 base map、hazards、events、self、marking 全部改成獨立 notifier。
2. 本階段重點是「POI 更新不要觸發外層 ListenableBuilder」，而不是「立刻移除外層 ListenableBuilder」。
3. `VectorTileLayer` 的 key 仍使用 `themeGeneration`。
4. `FlutterMap.children` 內優先回傳 map layer widget。POI 空狀態用 `MarkerLayer(markers: const [])`，不要直接用 `SizedBox.shrink()`，避免 `flutter_map` 7.0.2 children 不接受非 layer widget。
5. 所有新增 notifier 在 controller dispose 時都要 dispose。
6. 不要移除 `map_screen.dart` 頁面層級的 `ListenableBuilder(listenable: _ctrl)`。
7. `map_screen.dart` 的 AppBar 統計、`MapLocationHeader`、`HazardReportFlow`、legend 顯示條件、FAB/SOS 狀態仍依賴 controller notify 更新。Phase 2 完成後必須確認這些非地圖 UI 仍會更新。
8. 若未來要降低整頁 rebuild，再另行拆頁面級 UI notifier；不要在本階段順手移除頁面級更新來源。

### 6.7 完成標準

1. POI 更新不重建 `VectorTileLayer`。
2. POI 更新不重跑整個 `MapView` 的 marker / polygon 計算。
3. 若只拆 POI 後拖曳已足夠流暢，self / hazards / events / base map notifier 可保留為後續優化，不阻塞本階段驗收。
4. themeGeneration 只在 base map theme 變更時更新。
5. `MapLocationHeader` 的 district / road、AppBar event/hazard count、FAB/SOS 狀態、legend 顯示條件仍正常更新。
6. `flutter analyze` 通過。
7. 手測拖曳比 Phase 1 更穩。

## 7. Phase 3：POI 查詢空間索引 DB

### 7.1 目的

讓拖曳停止後的 POI refresh 也足夠快，避免每次 visible query 都解 MBTiles vector tile。

### 7.2 執行條件

此階段不是第一輪必做。完成 Phase 1 idle refresh 與 Phase 2 POI notifier 後，先實測 idle 後 visible POI refresh 耗時。只有在停止拖曳後 POI refresh 穩定超過 500ms，或仍明顯造成 UI 卡頓時，才實作 `poi_overlay.db`。

若 Phase 1+2 後拖曳與 idle refresh 已足夠流暢，此階段可延後，避免為了低頻 idle 查詢增加額外 asset、build script 與 fallback 維護成本。

### 7.3 新增資料檔

新增：

```text
assets/maps/poi_overlay.db
```

建議 schema：

```sql
CREATE TABLE pois (
  id INTEGER PRIMARY KEY,
  lat REAL NOT NULL,
  lon REAL NOT NULL,
  name TEXT,
  name_en TEXT,
  name_zh_hant TEXT,
  class TEXT NOT NULL,
  subclass TEXT,
  rank INTEGER
);

CREATE VIRTUAL TABLE poi_rtree USING rtree(
  id,
  min_lon, max_lon,
  min_lat, max_lat
);

CREATE INDEX idx_pois_class_subclass ON pois(class, subclass);
```

### 7.4 新增工具

新增：

```text
tool/build_poi_overlay_db.dart
```

工具職責：

1. 讀 `assets/maps/taiwan_ignirelay.mbtiles`。
2. 掃 `poi` layer。
3. 抽出 point geometry。
4. 抽出 `name`、`name:en`、`name_en`、`name:zh-Hant`、`name:zh`、`class`、`subclass`、`rank`。
5. 寫入 `poi_overlay.db`。
6. 建立 rtree。
7. 輸出可重跑且 deterministic。

### 7.5 Runtime 修改

`PoiQuery` 新增 optional path：

```dart
PoiQuery({
  required this.mbtilesPath,
  this.poiDetailsPath,
  this.poiOverlayPath,
});
```

`MapScreenController._initMBTiles()` 新增 `_ensurePoiOverlayDb()`，流程比照 `_ensurePoiDetailsDb()`。

`queryVisiblePois()` 查詢順序：

1. 若 `poi_overlay.db` 存在，用 rtree 查 bbox。
2. 若 `poi_overlay.db` 不存在或查詢失敗，fallback 舊 `_queryVisibleInIsolate()`。

### 7.6 查詢限制

| zoom | 行為 |
| --- | --- |
| `< 12` | 不顯示 POI |
| `12-13` | limit 100，優先救災相關類別或 rank 高者 |
| `14-15` | limit 200 |
| `>= 16` | limit 300，必要時可調到 500 |

不要一次畫上千個 Flutter marker。

### 7.7 完成標準

1. `poi_overlay.db` 已納入 assets。
2. App 可從 `poi_overlay.db` 查 visible POI。
3. `poi_overlay.db` 不存在時 fallback 舊 MBTiles 解碼路徑。
4. 查詢結果受 limit 控制。
5. POI 類別過濾仍尊重 `MapLayerSettings`。
6. `flutter analyze`、`flutter test`、`flutter build apk --debug` 通過。

## 8. Phase 4：地圖 label 多語

### 8.1 修改檔案

| 檔案 | 修改內容 |
| --- | --- |
| `lib/ui/theme/ignirelay_theme.dart` | `buildIgniRelayTheme()` 加 locale/language 參數 |
| `lib/ui/screens/map/map_screen_controller.dart` | 儲存目前 map locale，locale 變更時 rebuild theme |
| `lib/ui/screens/map/map_screen.dart` | 從 `Localizations.localeOf(context)` 傳入 controller |
| `test/map_label_language_test.dart` | 驗證語言 fallback |

### 8.2 新增 resolver

新增：

```text
lib/ui/theme/map_label_language.dart
```

建議模型：

```dart
class MapLabelLanguage {
  const MapLabelLanguage({
    required this.languageCode,
    required this.preferredFields,
  });

  final String languageCode;
  final List<String> preferredFields;
}
```

解析規則：

| UI locale | preferred fields |
| --- | --- |
| `zh_*` | `name:zh-Hant`, `name:zh`, `name`, `name_en` |
| `en_*` | `name_en`, `name:en`, `name_int`, `name` |
| MBTiles 支援的非中文語言 | `name:<languageCode>`, `name_en`, `name:en`, `name_int`, `name` |
| MBTiles 不支援的非中文語言 | `name_en`, `name:en`, `name_int`, `name` |

目前已知 MBTiles 支援語言可先用常數 set。未來可用 build-time script 從 metadata 產生。

### 8.3 Theme builder 修改

將：

```dart
Theme buildIgniRelayTheme({Logger? logger, Set<String>? disabledPoi})
```

改為以下其中一種。

方案 A：直接傳 Flutter 型別：

```dart
Theme buildIgniRelayTheme({
  required Locale locale,
  required Brightness brightness,
  Logger? logger,
  Set<String>? disabledPoi,
})
```

方案 B：避免 theme 檔 import material：

```dart
Theme buildIgniRelayTheme({
  required String languageCode,
  required bool dark,
  Logger? logger,
  Set<String>? disabledPoi,
})
```

### 8.4 text-field fallback 策略

`vector_tile_renderer` 5.2.1 支援 `coalesce` expression，token regex 可解析 `{name:en}` 這類含冒號 property。第一版直接使用 per-feature fallback，不需要先做 `{name_en}` / `{name:en}` 的手動試錯流程。

建議 expression：

中文：

```json
["coalesce", ["get", "name:zh-Hant"], ["get", "name:zh"], ["get", "name"], ["get", "name_en"], ["get", "name:en"]]
```

英文：

```json
["coalesce", ["get", "name_en"], ["get", "name:en"], ["get", "name_int"], ["get", "name"]]
```

其他支援語言，例如日文：

```json
["coalesce", ["get", "name:ja"], ["get", "name_en"], ["get", "name:en"], ["get", "name_int"], ["get", "name"]]
```

不支援語言：使用英文 expression。

若實作時發現某個 layer 不接受 expression，再對該 layer fallback locale-level field：

| 解析結果 | text-field |
| --- | --- |
| 中文 | 優先 `{name}`，或測試 `{name:zh-Hant}` 可用後切換 |
| 英文 | 優先 `{name_en}`；目前 theme 已使用過 `{name_en}` token，成功機率高於冒號版 `{name:en}` |
| 其他支援語言 | `{name:<lang>}` |
| 不支援語言 | 優先 `{name_en}`，再測 `{name:en}` |

### 8.5 Controller integration

`MapScreenController` 新增：

```dart
Locale? _mapLocale;
Brightness? _mapBrightness;
```

新增方法：

```dart
void updateMapPresentation({
  required Locale locale,
  required Brightness brightness,
}) {
  if (_mapLocale == locale && _mapBrightness == brightness) return;
  _mapLocale = locale;
  _mapBrightness = brightness;
  _rebuildTheme();
}
```

`MapScreen` 在 `didChangeDependencies()` 取得：

```dart
final locale = Localizations.localeOf(context);
final brightness = Theme.of(context).brightness;
```

再呼叫 controller 更新。必須避免每次 build 都重建 theme。

初始化順序：

1. `MapScreen.didChangeDependencies()` 必須在首次 theme 建立前把 locale / brightness 傳給 controller。
2. `_initMBTiles()` 完成 `MbTiles`、`MbTilesVectorTileProvider` 與 `TileProviders` 後，若 `_mapLocale` / `_mapBrightness` 尚未設定，先不要 build theme。
3. `updateMapPresentation(...)` 是首次 build map theme 的入口；`MapScreen.didChangeDependencies()` 必須是 first caller。
4. `_rebuildTheme()` 需要在 locale / brightness 已知後建立 theme，並更新 `themeGeneration`。
5. 不要把 `_mapLocale` 初始寫死成 `Locale('zh', 'TW')`，否則英文系統首次進地圖可能先中文後英文，造成閃爍。
6. 若極端情況下 `Localizations` 不可用，才使用 fallback locale / brightness；一般 app 流程不應走 fallback。

### 8.6 完成標準

1. 中文 UI 下地圖 label 顯示繁中。
2. 英文 UI 下地圖 label 顯示英文。
3. 支援語言如日文可使用對應欄位。
4. 不支援語言 fallback 英文。
5. 切語言只重建 theme，不重新初始化 MBTiles。
6. `flutter analyze` 通過。

## 9. Phase 5：地圖深淺色 theme

### 9.1 修改檔案

| 檔案 | 修改內容 |
| --- | --- |
| `lib/ui/theme/ignirelay_theme.dart` | 支援 brightness |
| `lib/ui/screens/map/map_screen_controller.dart` | brightness 變更時 rebuild theme |

### 9.2 實作策略

第一版直接使用 `lightThemeData()` 加 dark palette patch，不要先花時間 debug `bright_map_style.json` / `dark_map_style.json` 的 ThemeReader parse 問題。原因是 `vector_tile_renderer` 只支援 Mapbox Style Spec 子集，完整 style JSON 可能含 sources、glyphs、sprite 或 expression 差異，容易拖慢主線。

實作要求：

1. 保留現有 `ignirelay_theme.dart` 的功能 patch：移除原 POI layer、道路 label 拆 major/minor、水體 label minzoom、suburb layer。
2. 在同一個 theme builder 內依 brightness 套用 light / dark palette。
3. 等地圖效能與 i18n 核心穩定後，再評估是否改用 `bright_map_style.json` / `dark_map_style.json` 作為 base style。

### 9.3 Dark palette 最小需求

| 類型 | dark 建議 |
| --- | --- |
| background | `#0F1419` |
| landuse / landcover | `#172027` / `#1B2A22` |
| water | `#0A2540` |
| road minor | `#2B3440` |
| road major | `#3A4452` |
| road casing | `#111820` |
| building | `#1E2630` |
| boundary | `#56606B` |
| label text | `#C8CDD3` |
| secondary label text | `#9AA3AD` |
| label halo | `rgba(0,0,0,0.60)` |
| suburb text | `#8FA0B0` |

### 9.4 完成標準

1. UI light mode 顯示亮色地圖。
2. UI dark mode 顯示暗色地圖。
3. 切換不 crash。
4. marker 與 label 在兩種模式下可辨識。
5. `flutter analyze` 通過。

## 10. Phase 6：聊天室名稱多語

### 10.1 修改檔案

| 檔案 | 修改內容 |
| --- | --- |
| `lib/app/services/chat_service.dart` | 保留 `room_name` fallback，不讓它負責 i18n |
| `lib/ui/screens/chat/chat_list_screen.dart` | 顯示名稱改由 resolver 產生 |
| `lib/ui/screens/chat/chat_room_screen.dart` | title 改由 resolver 產生或處理 locale change |
| `lib/ui/screens/chat/chat_join_screen.dart` | 搜尋與成功訊息使用 localized display name |
| `lib/app/geo/village_geofence.dart` | 新增依 villcode 查單筆 village 的 API |
| `assets/geodata/taiwan_admin_names.json` | 新增 county/town 英文對照 |
| `lib/app/geo/admin_name_resolver.dart` | 新增行政區名稱 resolver |
| `lib/app/services/room_display_name_resolver.dart` | 新增聊天室顯示名稱 resolver |
| `lib/l10n/app_zh.arb` | 新增繁中聊天室名稱格式 |
| `lib/l10n/app_en.arb` | 新增英文聊天室名稱格式 |

### 10.2 新增 admin names 資料

新增：

```text
assets/geodata/taiwan_admin_names.json
```

格式：

```json
{
  "counties": {
    "65000": { "zhHant": "新北市", "en": "New Taipei City" }
  },
  "towns": {
    "65000050": {
      "countyCode": "65000",
      "zhHant": "新莊區",
      "en": "Xinzhuang District"
    }
  }
}
```

`pubspec.yaml` 已包含 `assets/geodata/`，通常不需額外列出單檔。

資料來源要求：

1. `taiwan_admin_names.json` 必須由政府公開資料產生，例如內政部戶政司行政區域代碼表。
2. 不要人工手打一整份 22 縣市與 368 鄉鎮市區資料。
3. 產生資料時保留 county code、town code、繁中名稱、英文名稱。
4. 若資料來源英文名格式與 UI 預期不一致，先保留來源原文，不在 runtime 做複雜轉換。

新增工具：

```text
tool/build_admin_names_json.dart
```

工具職責：

1. 從政府公開行政區域代碼資料輸入檔產生 `assets/geodata/taiwan_admin_names.json`。
2. 輸入可以是已下載到 repo 外或 `tmp/` 的 CSV / JSON，不要在 app runtime 連網。
3. 輸出排序 deterministic，方便 review diff。
4. 在工具檔註解中寫明資料來源名稱、下載網址與資料日期。
5. 產物包含 22 縣市與 368 鄉鎮市區。

### 10.3 AdminNameResolver

新增：

```text
lib/app/geo/admin_name_resolver.dart
```

職責：

1. 載入 `taiwan_admin_names.json`。
2. 依 countyCode 回傳 county 中文 / 英文。
3. 依 townCode 回傳 town 中文 / 英文。
4. missing code 不 throw，回傳 null。
5. eager cache 載入結果，避免每次 resolve 都讀 asset。
6. 對 nation / county / township 的名稱解析應盡量在 cache ready 後走同步查表，不要每個 room 都做不必要的 async asset I/O。

API 形狀：

```dart
class AdminNameResolver {
  Future<void> ensureLoaded();
  ({String? zhHant, String? en})? county(String code);
  ({String? zhHant, String? en})? town(String code);
}
```

`ensureLoaded()` 第一次呼叫載入 asset 並建立 cache，後續呼叫 no-op。`county(...)` / `town(...)` 在 cache ready 後只做同步 Map lookup。

### 10.4 Village 查詢補強

`VillageGeofence` 新增：

```dart
static Future<VillageInfo?> queryByCode(String villcode)
```

SQL：

```sql
SELECT villcode, towncode, countyname, townname, villname, villeng
FROM villages
WHERE villcode = ?
LIMIT 1
```

`village_boundary.db` 目前以 `sql.OpenMode.readOnly` 開啟，因此 runtime 不可在 `VillageGeofence.init()` 執行 `CREATE INDEX`。`villcode` 索引必須在 build-time 建入 asset DB。

build-time 對 `assets/geodata/village_boundary.db` 執行：

```sql
CREATE INDEX IF NOT EXISTS idx_villages_villcode ON villages(villcode);
```

`queryByCode()` 是依代碼查單筆資料，不使用空間 R-tree。聊天室列表可能會對多個房間呼叫 resolver，因此必須避免無索引全表掃描。實作 Agent 需確認 asset DB 本身已有 `idx_villages_villcode`，不要在 read-only runtime 連線上建立索引。

若 asset DB 尚未有此索引，可在開發機以 sqlite3 CLI 對 `resqmesh_app/assets/geodata/village_boundary.db` 執行：

```sql
CREATE INDEX IF NOT EXISTS idx_villages_villcode ON villages(villcode);
VACUUM;
```

完成後 commit 更新後的 DB asset。不要新增 runtime 程式碼建索引。

### 10.5 RoomDisplayNameResolver

新增：

```text
lib/app/services/room_display_name_resolver.dart
```

API：

```dart
class RoomDisplayNameResolver {
  Future<String> resolve({
    required String roomId,
    required String roomType,
    required String fallbackRoomName,
    required Locale locale,
  });
}
```

效能要求：

1. `resolve(...)` 對外維持 async API，因為首次需要等待 cache load 或 village DB 查詢。
2. `ChatListScreen._loadRooms()` 不應先顯示 DB fallback 名稱再逐筆跳成 localized 名稱，避免列表閃爍。
3. 載入聊天室列表時，先 await resolver 完成所有 room display name，再一次 setState 更新列表。
4. `AdminNameResolver.ensureLoaded()` 應在 chat list init / first load 早於第一次批次 resolve 執行；cache ready 後 county/town 查詢是同步 Map lookup。
5. nation / county / township 的解析只需要 code + cached admin names，不應查 `VillageGeofence`。
6. village 才需要 `VillageGeofence.queryByCode()` 查 `villeng` 與 towncode/countycode。
7. 可選優化：resolver 內部 cache `villcode -> VillageInfo`，避免反覆進出聊天室列表時重查 DB。

中文判斷：

```dart
bool useChinese(Locale locale) => locale.languageCode.toLowerCase() == 'zh';
```

中文模式：

| roomType | 顯示 |
| --- | --- |
| `nation` | `全國公告` |
| `county` | `{countyZh} 公告` |
| `township` | `{countyZh}{townZh} 公告` |
| `village` | `{countyZh}{townZh}{villZh} 聊天室` |
| `custom` | `fallbackRoomName` |

非中文模式：

| roomType | 顯示 |
| --- | --- |
| `nation` | `National Announcements` |
| `county` | `{countyEn} Announcements`，缺資料則 `County Announcements` |
| `township` | `{countyEn} {townEn} Announcements`，缺資料則 `Township Announcements` |
| `village` | `{countyEn} {townEn} {villEng} Chat`，缺資料則 `{villEng} Chat` 或 `Village Chat` |
| `custom` | `fallbackRoomName` |

room_id 解析：

| roomType | roomId 格式 | 解析 |
| --- | --- | --- |
| `nation` | `TW_NATION` | 固定 |
| `county` | `TW_` + 5 碼 county code | 去掉 `TW_` |
| `township` | `TW_` + 8 碼 town code | 去掉 `TW_` |
| `village` | 11 碼 villcode | 直接查 `villages` |

### 10.6 ChatListScreen 修改

目前 `_loadRooms()` 直接使用 DB `room_name`。改為：

1. 取得 `locale = Localizations.localeOf(context)`。
2. 對每個 room 呼叫 `RoomDisplayNameResolver.resolve(...)`。
3. 使用 `Future.wait` 或順序 await 完成所有名稱解析後，一次 setState 更新 `_rooms`。
4. `_RoomTile.roomName` 存 localized display name。
5. `didChangeDependencies()` 偵測 locale 變更後重新 resolve。
6. 不要先 render fallback `room_name` 再逐筆替換，避免列表閃爍。

### 10.7 ChatRoomScreen 修改

目前 AppBar title 顯示 `widget.roomName`。改為：

1. `widget.roomName` 保留作 fallback。
2. state 內新增 `_displayRoomName`。
3. `initState()` 與 `didChangeDependencies()` 呼叫 resolver。
4. AppBar 顯示 `_displayRoomName ?? widget.roomName`。

### 10.8 ChatJoinScreen 修改

手動搜尋 SQL 加入 `villeng`：

```sql
WHERE countyname LIKE ? OR townname LIKE ? OR villname LIKE ? OR villeng LIKE ?
```

搜尋結果顯示：

| locale | 顯示 |
| --- | --- |
| zh | `village.fullName` |
| non-zh | `{countyEn} {townEn} {villEng}`，缺資料時 fallback `{villEng}` |

加入成功 snackbar 使用 localized display name。

### 10.9 L10n keys

新增 ARB keys：

| key | zh | en |
| --- | --- | --- |
| `chatRoomNameNation` | `全國公告` | `National Announcements` |
| `chatRoomNameCountyGeneric` | `縣市公告` | `County Announcements` |
| `chatRoomNameTownshipGeneric` | `鄉鎮區公告` | `Township Announcements` |
| `chatRoomNameVillageGeneric` | `村里聊天室` | `Village Chat` |
| `chatRoomNameCountyAnnouncements` | `{county} 公告` | `{county} Announcements` |
| `chatRoomNameTownshipAnnouncements` | `{county}{town} 公告` | `{county} {town} Announcements` |
| `chatRoomNameVillageChat` | `{county}{town}{village} 聊天室` | `{county} {town} {village} Chat` |

### 10.10 完成標準

1. 中文 UI 聊天室名稱為繁中。
2. 英文 UI 聊天室名稱為英文。
3. 其他非中文 UI 聊天室名稱仍英文。
4. 舊 DB 的中文 `room_name` 不影響英文顯示。
5. 自訂聊天室名稱保持原樣。
6. 手動搜尋可搜中文村里與英文 `villeng`。
7. `flutter analyze`、`flutter test` 通過。

## 11. Phase 7：整合驗收

### 11.1 必跑指令

```powershell
flutter analyze
flutter test
flutter build apk --debug
```

### 11.2 模擬器 smoke test

1. 安裝 debug APK。
2. 啟動 app。
3. 進地圖頁。
4. 連續拖曳 30 秒。
5. 停止拖曳，確認 POI 稍後刷新。
6. 切換英文 UI，確認地圖 label 英文化。
7. 切換中文 UI，確認地圖 label 回繁中。
8. 切換 dark mode，確認地圖暗色。
9. 切換 light mode，確認地圖亮色。
10. 進聊天室列表，確認中文模式繁中名稱。
11. 切英文 UI，確認聊天室名稱英文。
12. 進聊天室 detail，確認 AppBar 名稱也英文。
13. 測自訂聊天室仍顯示原名稱。
14. 查 logcat 無 fatal crash。

logcat：

```powershell
& "C:\Users\radio\Android\Sdk\platform-tools\adb.exe" -s emulator-5554 logcat -d AndroidRuntime:E flutter:E *:S
```

### 11.3 效能驗收

1. 拖曳期間不連續觸發 visible POI query。
2. POI 更新不造成 `VectorTileLayer` rebuild。
3. 拖曳體感不再固定節奏頓挫。
4. 停止拖曳後 POI 正常更新。
5. marker 沒有大量閃爍或清空再出現。
6. 切換 locale / brightness 時才重建 base map theme。

## 12. 跨檔案實作順序

### Step 1：基線與測試

修改範圍：tests only 或不修改 runtime。

### Step 2：拖曳 idle refresh

修改範圍：

```text
lib/ui/screens/map/widgets/map_view.dart
lib/ui/screens/map/map_screen_controller.dart
```

### Step 3：notifier 拆分

修改範圍：

```text
lib/ui/screens/map/map_screen_controller.dart
lib/ui/screens/map/widgets/map_view.dart
lib/ui/screens/map/models/map_view_models.dart
```

先 POI 並驗收效能；若仍有明顯 rebuild 卡頓，再追加 self、hazards/events。base map notifier 不作為優先項。

### Step 4：POI overlay DB

執行條件：只有 Phase 1+2 後 idle refresh 仍穩定超過 500ms 或造成明顯卡頓時才做。

修改範圍：

```text
tool/build_poi_overlay_db.dart
assets/maps/poi_overlay.db
lib/app/mesh/poi_query.dart
lib/ui/screens/map/map_screen_controller.dart
```

### Step 5：地圖 label i18n

修改範圍：

```text
lib/ui/theme/ignirelay_theme.dart
lib/ui/theme/map_label_language.dart
lib/ui/screens/map/map_screen_controller.dart
lib/ui/screens/map/map_screen.dart
test/map_label_language_test.dart
```

### Step 6：地圖 light/dark

修改範圍：

```text
lib/ui/theme/ignirelay_theme.dart
lib/ui/screens/map/map_screen_controller.dart
lib/ui/screens/map/map_screen.dart
```

第一版走 `lightThemeData()` 加 dark palette patch；不要先修改 `assets/style/bright_map_style.json` 或 `assets/style/dark_map_style.json`。

### Step 7：聊天室名稱 i18n

修改範圍：

```text
assets/geodata/taiwan_admin_names.json
tool/build_admin_names_json.dart
lib/app/geo/admin_name_resolver.dart
lib/app/geo/village_geofence.dart
lib/app/services/room_display_name_resolver.dart
lib/ui/screens/chat/chat_list_screen.dart
lib/ui/screens/chat/chat_room_screen.dart
lib/ui/screens/chat/chat_join_screen.dart
lib/l10n/app_zh.arb
lib/l10n/app_en.arb
```

### Step 8：整合驗收

跑 analyze/test/build/smoke test。

## 13. 最終完成狀態

1. 地圖拖曳期間只移動畫面，不做 visible POI 查詢。
2. 地圖停止拖曳後才刷新 POI。
3. POI 更新只重建 POI layer。
4. POI rebuild 邊界清楚；self、hazard、event 若實測需要則一併拆分。
5. 中文 UI 下地圖 label 使用繁中。
6. 非中文 UI 下地圖 label 使用該語言；若 MBTiles 不支援則英文。
7. UI light/dark mode 能切換地圖亮暗色。
8. 中文 UI 下聊天室名稱為繁中。
9. 非中文 UI 下聊天室名稱一律英文。
10. 舊 DB 已存在的中文 `room_name` 不影響英文顯示。
11. 自訂聊天室保留原名稱。
12. analyze/test/build/smoke test 通過。
