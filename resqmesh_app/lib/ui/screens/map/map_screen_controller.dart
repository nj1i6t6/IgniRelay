// map_screen_controller.dart
//
// Stage 7-r2：地圖頁的 single source of truth controller。
//
// 設計原則（對齊 docs/Refactoring-0.2.0-plan.md §Stage 4d 結構債）：
//
//   1. **ChangeNotifier**：state 集中於此，widget 透過 `ListenableBuilder`
//      或 `AnimatedBuilder` 訂閱；map_screen 退化為 thin shell。
//   2. **絕不持有 BuildContext / 不直接做 UI side effect**：snackbar / dialog /
//      Navigator 邊界由 widget 處理；controller 透過回傳 outcome 物件溝通。
//   3. **flutter_map MapController 不在此**：viewport 資訊由 MapView 透過
//      `setViewport(...)` 主動回報；controller 對 camera 沒有直接讀寫權。
//      避免「controller 在 map 未 ready 前誤呼叫 camera API」的時序風險。
//   4. **async race**：每族 reload 各有 generation token，舊 request 回來時
//      若 token 已被推進就直接丟棄，避免覆蓋更新狀態。
//   5. **disposed guard**：所有非同步寫回前一律檢查 `_disposed`。
//   6. **MapLayerSettings 由 controller 擁有**：避免 sheet 與 controller
//      雙 owner 互相 listen 造成 ChangeNotifier 巢狀。
//
// 範圍（搬入此 controller 的 state）：
//   - MBTiles / TileProviders / vtr.Theme / PoiQuery / themeGeneration
//   - GPS userLocation / accuracy / positionStream
//   - district / road lookup state + debounce
//   - hazards / events / pois 的 view models
//   - SOS 廣播追蹤狀態
//   - marking 草稿狀態（除 description text，由 widget 端 TextEditingController 持有）
//   - myReporterHex
//   - timer / subscription lifecycle
//
// 不在 controller：
//   - flutter_map MapController（在 MapView widget）
//   - AnimationController（_refreshSpinCtrl 由 widget 持有）
//   - TextEditingController（_markDescCtrl 由 widget 持有）
//   - showLegend toggle（純呈現，由 widget 持有）

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:mbtiles/mbtiles.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_map_tiles_mbtiles/vector_map_tiles_mbtiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

import 'package:ignirelay_app/app/db/database_helper.dart';
import 'package:ignirelay_app/app/mesh/event_manager.dart';
import 'package:ignirelay_app/app/mesh/event_types.dart';
import 'package:ignirelay_app/app/mesh/mbtiles_loader.dart';
import 'package:ignirelay_app/app/mesh/mesh_event_handler.dart';
import 'package:ignirelay_app/app/mesh/poi_query.dart';

import 'package:ignirelay_app/ui/screens/map/models/map_action_results.dart';
import 'package:ignirelay_app/ui/screens/map/models/map_view_models.dart';
import 'package:ignirelay_app/ui/screens/map/widgets/map_location_header.dart';
import 'package:ignirelay_app/ui/screens/map/widgets/pin_palette.dart';
import 'package:ignirelay_app/ui/screens/map/widgets/poi_category.dart';
import 'package:ignirelay_app/ui/sheets/map_layer_settings.dart';
import 'package:ignirelay_app/ui/theme/ignirelay_theme.dart';

class MapScreenController extends ChangeNotifier {
  MapScreenController() {
    _layerSettings.addListener(_onLayerSettingsChanged);
  }

  // ── 服務依賴（測試時可注入；目前直接拿 singleton/實例）──
  final EventManager _eventManager = EventManager();

  // ── MBTiles / 渲染 ──
  MbTilesStateVm _mbTilesState = MbTilesStateVm.initial;
  MbTilesStateVm get mbTilesState => _mbTilesState;

  MbTiles? _mbTiles;
  TileProviders? _tileProviders;
  vtr.Theme? _mapTheme;
  PoiQuery? _poiQuery;

  TileProviders? get tileProviders => _tileProviders;
  vtr.Theme? get mapTheme => _mapTheme;
  PoiQuery? get poiQuery => _poiQuery;

  // ── GPS ──
  SelfLocationVm? _selfLocation;
  SelfLocationVm? get selfLocation => _selfLocation;
  StreamSubscription<Position>? _positionStream;

  /// 第一次 GPS 定位完成且落在台灣範圍時要求 MapView centerOn 一次。
  /// MapView 訂閱此 listenable，被 trigger 後執行 camera.move 並 reset。
  final ValueNotifier<LatLng?> centerRequest = ValueNotifier<LatLng?>(null);

  // ── 行政區 / 道路反查 ──
  String? _district;
  String? _road;
  String? get district => _district;
  String? get road => _road;
  LatLng? _lastLookupLoc;
  Timer? _lookupDebounce;
  int _lookupGen = 0;

  // ── Overlays（VM 形式）──
  List<HazardVm> _hazards = const [];
  List<EventVm> _events = const [];
  List<PoiVm> _pois = const [];

  List<HazardVm> get hazards => _hazards;
  List<EventVm> get events => _events;
  List<PoiVm> get pois => _pois;

  Timer? _refreshTimer;
  StreamSubscription? _meshEventSub;
  Timer? _meshDebounce;
  Timer? _poiRefreshTimer;
  int _overlayGen = 0;
  int _poiGen = 0;

  // ── viewport（由 MapView 回報）──
  bool _mapReady = false;
  double _viewportZoom = 15.0;
  LatLngBounds? _viewportBounds;
  bool get mapReady => _mapReady;

  // ── 圖層設定 ──
  final MapLayerSettings _layerSettings = MapLayerSettings();
  MapLayerSettings get layerSettings => _layerSettings;

  // ── 標記模式 ──
  MarkingDraftVm _marking = MarkingDraftVm.idle;
  MarkingDraftVm get marking => _marking;

  // ── SOS 追蹤 ──
  SosStateVm _sos = SosStateVm.idle;
  SosStateVm get sos => _sos;

  // ── 自身識別（hazard isMine 過濾）──
  String _myReporterHex = '';
  String get myReporterHex => _myReporterHex;

  // ── 生命週期旗標 ──
  bool _disposed = false;
  bool get isDisposed => _disposed;

  // ── 啟動：由 widget 在 initState 呼叫一次 ──
  Future<void> bootstrap() async {
    await _initReporterHex();
    // MBTiles 與 GPS 並行（互不依賴），但都需要 disposed guard
    unawaited(_initMBTiles());
    unawaited(_initGPS());
    unawaited(loadOverlays());
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => loadOverlays(),
    );
    _meshEventSub = MeshEventHandler().events.listen((_) {
      _meshDebounce?.cancel();
      _meshDebounce = Timer(const Duration(seconds: 2), () {
        if (_disposed) return;
        unawaited(loadOverlays());
      });
    });
  }

  Future<void> _initReporterHex() async {
    try {
      final hex = await _eventManager.getReporterHex();
      if (_disposed) return;
      _myReporterHex = hex;
      // 不 notify：reporterHex 只影響 hazard isMine 計算，下次 loadHazards
      // 會自然吃到新值。避免單一欄位變更觸發整體 rebuild。
    } catch (e) {
      debugPrint('[MapController] reporterHex init error: $e');
    }
  }

  // ── MBTiles 初始化（容忍重試）──

  /// 由 widget 端在 retry 按鈕點擊時呼叫；亦由 bootstrap 觸發一次。
  Future<void> retryInitMbTiles() => _initMBTiles(reset: true);

  Future<void> _initMBTiles({bool reset = false}) async {
    if (reset) {
      _mbTilesState = const MbTilesStateVm(
        loading: true,
        available: false,
        errorKey: null,
        errorArg: null,
        themeGeneration: 0,
      );
      _safeNotify();
    }
    try {
      final available = await MBTilesLoader.isAvailable();
      if (_disposed) return;
      if (!available) {
        _mbTilesState = MbTilesStateVm(
          loading: false,
          available: false,
          errorKey: 'mapMbtilesNotFound',
          errorArg: null,
          themeGeneration: _mbTilesState.themeGeneration,
        );
        _safeNotify();
        return;
      }
      final path = await MBTilesLoader.getLocalPath();
      await MBTilesLoader.sanitizeMetadata(path);
      final poiDbPath = await _ensurePoiDetailsDb();
      final mbTiles = MbTiles(mbtilesPath: path, gzip: true);
      final provider = MbTilesVectorTileProvider(mbtiles: mbTiles);
      final theme = buildIgniRelayTheme();

      // tile 健檢（不致命）
      String tileTestResult = 'untested';
      try {
        const tmsY = ((1 << 10) - 1) - 442;
        final testTile = mbTiles.getTile(z: 10, x: 859, y: tmsY);
        if (testTile != null) {
          tileTestResult = 'OK ${testTile.length}B';
        } else {
          final testTileXyz = mbTiles.getTile(z: 10, x: 859, y: 442);
          tileTestResult = testTileXyz != null
              ? 'OK(xyz) ${testTileXyz.length}B'
              : 'NULL z10/859/tms$tmsY+xyz442';
        }
      } catch (e) {
        tileTestResult = 'ERR: $e';
      }
      try {
        final fileSize = File(path).lengthSync();
        final fileSizeMB = (fileSize / 1024 / 1024).toStringAsFixed(1);
        debugPrint(
            '[MapController] MBTiles ready: $path, ${fileSizeMB}MB, '
            'zoom=${provider.minimumZoom}-${provider.maximumZoom}, '
            'theme=${theme.layers.length} layers, tileTest=$tileTestResult');
      } catch (_) {}

      if (_disposed) {
        mbTiles.dispose();
        return;
      }
      _mbTiles = mbTiles;
      _poiQuery = PoiQuery(mbtilesPath: path, poiDetailsPath: poiDbPath);
      _tileProviders = TileProviders({'openmaptiles': provider});
      _mapTheme = theme;
      _mbTilesState = MbTilesStateVm(
        loading: false,
        available: true,
        errorKey: null,
        errorArg: null,
        themeGeneration: _mbTilesState.themeGeneration + 1,
      );
      _safeNotify();
      // mbtiles ready 後嘗試刷一次 POI（viewport 可能尚未到位，內部會 noop）
      requestPoiRefresh();
    } catch (e, stack) {
      debugPrint('[MapController] MBTiles init error: $e\n$stack');
      if (_disposed) return;
      _mbTilesState = MbTilesStateVm(
        loading: false,
        available: false,
        errorKey: 'mapMbtilesLoadFail',
        errorArg: e.toString(),
        themeGeneration: _mbTilesState.themeGeneration,
      );
      _safeNotify();
    }
  }

  static Future<String?> _ensurePoiDetailsDb() async {
    const assetPath = 'assets/maps/poi_details.db';
    const fileName = 'poi_details.db';
    try {
      final dir = await getApplicationDocumentsDirectory();
      final target = File('${dir.path}/$fileName');
      if (!target.existsSync()) {
        final data = await rootBundle.load(assetPath);
        final bytes =
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await target.writeAsBytes(bytes, flush: true);
        debugPrint('[MapController] POI details DB copied: '
            '${target.lengthSync()} bytes');
      }
      return target.path;
    } catch (e) {
      debugPrint('[MapController] POI details DB not available: $e');
      return null;
    }
  }

  // ── GPS 初始化 ──

  bool _isInTaiwanBounds(LatLng loc) {
    return loc.latitude >= 20.5 &&
        loc.latitude <= 26.8 &&
        loc.longitude >= 117.9 &&
        loc.longitude <= 123.1;
  }

  Future<void> _initGPS() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (_disposed) return;
      if (!serviceEnabled) {
        debugPrint('[MapController] GPS service disabled');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (_disposed) return;
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('[MapController] GPS permission denied');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        throw TimeoutException('GPS timeout');
      });
      if (_disposed) return;
      final loc = LatLng(pos.latitude, pos.longitude);
      _selfLocation =
          SelfLocationVm(location: loc, accuracyMeters: pos.accuracy);
      _safeNotify();
      _scheduleDistrictRoadLookup(loc);
      if (_isInTaiwanBounds(loc)) {
        // 請 MapView 把 camera 移到此位置（避開 controller 直接呼 camera API）
        centerRequest.value = loc;
      }
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((pos) {
        if (_disposed) return;
        final l = LatLng(pos.latitude, pos.longitude);
        _selfLocation = SelfLocationVm(location: l, accuracyMeters: pos.accuracy);
        _safeNotify();
        _scheduleDistrictRoadLookup(l);
      });
    } catch (e) {
      debugPrint('[MapController] GPS init error: $e');
    }
  }

  /// widget 端 FAB「定位」按鈕呼叫；MapView 訂閱 `centerRequest` 完成 camera move。
  bool requestCenterOnUser() {
    final s = _selfLocation;
    if (s == null) return false;
    centerRequest.value = s.location;
    return true;
  }

  // ── 行政區 / 道路反查（debounce + 80m 距離閾值 + generation token）──

  void _scheduleDistrictRoadLookup(LatLng loc) {
    final last = _lastLookupLoc;
    if (last != null) {
      final dLat = (loc.latitude - last.latitude).abs() * 111000.0;
      final dLng = (loc.longitude - last.longitude).abs() * 102000.0;
      if (dLat * dLat + dLng * dLng < 80 * 80) return;
    }
    _lookupDebounce?.cancel();
    final myGen = ++_lookupGen;
    _lookupDebounce = Timer(const Duration(milliseconds: 1500), () async {
      if (_disposed) return;
      final pq = _poiQuery;
      if (pq == null) return;
      final r = await DistrictRoadLookup.lookup(poiQuery: pq, location: loc);
      if (_disposed) return;
      if (myGen != _lookupGen) return; // 舊 request 被新一輪覆蓋，丟棄
      _district = r.$1;
      _road = r.$2;
      _lastLookupLoc = loc;
      _safeNotify();
    });
  }

  // ── viewport 契約：由 MapView 回報 ──

  void setViewport({
    required double zoom,
    required LatLngBounds bounds,
    required bool ready,
  }) {
    final wasReady = _mapReady;
    _mapReady = ready;
    _viewportZoom = zoom;
    _viewportBounds = bounds;
    if (!wasReady && ready) {
      // 第一次 ready 時刷一次 POI（viewport 已可用）
      requestPoiRefresh();
    } else if (ready) {
      requestPoiRefresh();
    }
  }

  // ── Overlays load 序列（generation guard）──

  Future<void> loadOverlays() async {
    final gen = ++_overlayGen;
    await Future.wait([
      _loadHazards(gen),
      _loadEventMarkers(gen),
    ]);
  }

  Future<void> _loadHazards(int gen) async {
    if (!_layerSettings.showHazards) {
      if (gen != _overlayGen || _disposed) return;
      if (_hazards.isNotEmpty) {
        _hazards = const [];
        _safeNotify();
      }
      return;
    }
    final raw = await _eventManager.getActiveHazards();
    if (_disposed || gen != _overlayGen) return;
    final list = <HazardVm>[];
    for (final h in raw) {
      final lat = (h['lat'] as num?)?.toDouble();
      final lng = (h['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      final reportedBy = h['reported_by'] as String? ?? '';
      final isMine = reportedBy == _myReporterHex;
      final confirmCount = (h['confirm_count'] as int?) ?? 1;
      if (!isMine && !_layerSettings.showOtherHazards) continue;
      if (!isMine && confirmCount < _layerSettings.minConfirmCount) continue;
      list.add(HazardVm(
        id: h['hazard_id'] as String? ?? '',
        lat: lat,
        lng: lng,
        radiusMeters: (h['radius'] as num?)?.toDouble() ?? 200.0,
        severity: (h['severity'] as int?) ?? 3,
        type: h['type'] as String? ?? '',
        confirmCount: confirmCount,
        reportedBy: reportedBy,
        isMine: isMine,
        description: h['description'] as String? ?? '',
        raw: Map<String, dynamic>.from(h),
      ));
    }
    if (_disposed || gen != _overlayGen) return;
    _hazards = list;
    _safeNotify();
  }

  Future<void> _loadEventMarkers(int gen) async {
    final db = await DatabaseHelper().database;
    if (_disposed || gen != _overlayGen) return;
    final cutoff = DateTime.now().millisecondsSinceEpoch - (24 * 3600 * 1000);
    final rows = await db.query(
      'Event_Logs',
      where:
          'hlc_timestamp > ? AND received_lat IS NOT NULL AND received_lng IS NOT NULL AND event_type != ?',
      whereArgs: [cutoff, EventType.hazardMarker],
      orderBy: 'urgency DESC, hlc_timestamp DESC',
      limit: 100,
    );
    if (_disposed || gen != _overlayGen) return;
    final list = <EventVm>[];
    for (final evt in rows) {
      final lat = (evt['received_lat'] as num?)?.toDouble();
      final lng = (evt['received_lng'] as num?)?.toDouble();
      final urgency = (evt['urgency'] as int?) ?? 0;
      final eventType = (evt['event_type'] as int?) ?? 0;
      if (lat == null || lng == null || lat == 0 || lng == 0) continue;
      if (urgency == 0) continue; // Bug 9: 過濾 INFO

      // urgency → 大類
      final PinCategory category;
      switch (urgency) {
        case 3:
          category = PinCategory.hazard;
          break;
        case 2:
          category = PinCategory.life;
          break;
        case 1:
          category = PinCategory.supply;
          break;
        default:
          category = PinCategory.life;
      }

      // 解 description（payload 為 UTF-8 / ASCII bytes）
      String desc = '';
      final payload = evt['payload'] as Uint8List?;
      if (payload != null) {
        try {
          desc = String.fromCharCodes(payload);
          if (desc.length > 40) desc = '${desc.substring(0, 40)}...';
        } catch (_) {}
      }

      list.add(EventVm(
        id: evt['event_id'] as String? ?? '',
        lat: lat,
        lng: lng,
        urgency: urgency,
        eventType: eventType,
        category: category,
        description: desc,
        raw: Map<String, dynamic>.from(evt),
      ));
    }
    if (_disposed || gen != _overlayGen) return;
    _events = list;
    _safeNotify();
  }

  // ── POI 刷新（debounce + viewport 守衛 + generation token）──

  void requestPoiRefresh() {
    _poiRefreshTimer?.cancel();
    _poiRefreshTimer = Timer(const Duration(milliseconds: 300), () {
      unawaited(_doRefreshPoi());
    });
  }

  Future<void> _doRefreshPoi() async {
    final pq = _poiQuery;
    if (pq == null) return;
    if (!_layerSettings.showPoi) {
      if (_pois.isNotEmpty && !_disposed) {
        _pois = const [];
        _safeNotify();
      }
      return;
    }
    final bounds = _viewportBounds;
    if (!_mapReady || bounds == null) return;
    final zoom = _viewportZoom;
    if (zoom < 12) {
      if (_pois.isNotEmpty && !_disposed) {
        _pois = const [];
        _safeNotify();
      }
      return;
    }
    final gen = ++_poiGen;
    final raw = await pq.queryVisiblePois(
      south: bounds.south,
      west: bounds.west,
      north: bounds.north,
      east: bounds.east,
      zoom: zoom,
    );
    if (_disposed || gen != _poiGen) return;
    final list = <PoiVm>[];
    for (final poi in raw) {
      final lat = double.tryParse(poi['lat'] ?? '') ?? 0;
      final lng = double.tryParse(poi['lng'] ?? '') ?? 0;
      final cls = poi['class'] ?? '';
      final sub = poi['subclass'] ?? '';
      final catId = PoiCategories.id(cls, sub);
      if (catId == null) continue;
      if (!_layerSettings.showPoi) continue;
      if (!_layerSettings.poiIsEnabled(catId)) continue;
      list.add(PoiVm(
        lat: lat,
        lng: lng,
        classKey: cls,
        subclassKey: sub,
        raw: Map<String, String>.from(poi),
      ));
    }
    if (_disposed || gen != _poiGen) return;
    _pois = list;
    _safeNotify();
  }

  // ── 圖層設定變更 ──

  void _onLayerSettingsChanged() {
    if (_disposed) return;
    _rebuildTheme();
    unawaited(loadOverlays());
    requestPoiRefresh();
  }

  void _rebuildTheme() {
    final mb = _mbTiles;
    if (!_mbTilesState.available || mb == null) return;
    final theme = buildIgniRelayTheme(disabledPoi: _layerSettings.disabledPoiIds);
    final provider = MbTilesVectorTileProvider(mbtiles: mb);
    _tileProviders = TileProviders({'openmaptiles': provider});
    _mapTheme = theme;
    _mbTilesState = MbTilesStateVm(
      loading: _mbTilesState.loading,
      available: _mbTilesState.available,
      errorKey: _mbTilesState.errorKey,
      errorArg: _mbTilesState.errorArg,
      themeGeneration: _mbTilesState.themeGeneration + 1,
    );
    _safeNotify();
  }

  // ── 標記模式 commands ──

  /// 由 widget 在 long press 時呼叫，進入新建模式。
  void enterMarkingNew(LatLng center) {
    if (_marking.isActive) return;
    _marking = const MarkingDraftVm(
      isActive: true,
      editingHazardId: null,
      center: null,
      type: 'ROADBLOCK',
      severity: 3.0,
      radiusMeters: 200.0,
      isPublishing: false,
    ).copyWith(center: center);
    _safeNotify();
  }

  /// 由 widget 在 hazard info sheet 點 edit 時呼叫，進入編輯模式。
  /// description 由 widget 端 TextEditingController 持有，所以這邊回傳給 widget 寫入。
  String enterMarkingEdit(HazardVm h) {
    _marking = MarkingDraftVm(
      isActive: true,
      editingHazardId: h.id,
      center: h.latLng,
      type: h.type,
      severity: h.severity.toDouble(),
      radiusMeters: h.radiusMeters,
      isPublishing: false,
    );
    _safeNotify();
    return h.description;
  }

  void exitMarking() {
    if (!_marking.isActive) return;
    _marking = MarkingDraftVm.idle;
    _safeNotify();
  }

  /// 標記模式時點地圖 → 移動 center。
  void updateMarkingCenter(LatLng center) {
    if (!_marking.isActive) return;
    _marking = _marking.copyWith(center: center);
    _safeNotify();
  }

  void updateMarkingType(String type) {
    _marking = _marking.copyWith(type: type);
    _safeNotify();
  }

  void updateMarkingSeverity(double severity) {
    _marking = _marking.copyWith(severity: severity);
    _safeNotify();
  }

  void updateMarkingRadius(double radius) {
    _marking = _marking.copyWith(radiusMeters: radius);
    _safeNotify();
  }

  /// 發布或更新 hazard。
  ///
  /// description 由呼叫端傳入（widget 端 TextEditingController 直接讀），
  /// 避免把 TextEditingController 搬進 controller 的常見坑。
  ///
  /// `confirmExisting` 為 widget 接到 [PublishHazardNearbyConflict] 後，使用者
  /// 選擇 confirm 既有 hazard 而再次呼叫此 method 時帶入 nearbyId；此時略過
  /// nearby 檢查直接做 confirm。
  Future<PublishHazardOutcome> publishOrUpdateMark({
    required String description,
    String? confirmExistingId,
    bool skipNearbyCheck = false,
  }) async {
    final m = _marking;
    if (!m.isActive || m.center == null) {
      return const PublishHazardNoop();
    }
    _marking = m.copyWith(isPublishing: true);
    _safeNotify();
    try {
      // 確認既有 hazard 路徑（NearbyConflict 後 widget 二次呼叫）
      if (confirmExistingId != null) {
        await _eventManager.confirmHazard(confirmExistingId);
        exitMarking();
        unawaited(loadOverlays());
        return PublishHazardConfirmedExisting(typeKey: m.type);
      }

      // 編輯模式
      if (m.isEditing) {
        await _eventManager.updateHazard(
          m.editingHazardId!,
          type: m.type,
          severity: m.severity.round(),
          lat: m.center!.latitude,
          lng: m.center!.longitude,
          radiusMeters: m.radiusMeters,
          description: description,
        );
        exitMarking();
        unawaited(loadOverlays());
        return const PublishHazardUpdated();
      }

      // 新建：先 nearby 檢查（widget 可選擇再呼叫一次帶 confirmExistingId）
      if (!skipNearbyCheck) {
        final nearby = await _eventManager.findNearbyHazard(
          m.center!.latitude,
          m.center!.longitude,
          m.type,
          searchRadius: m.radiusMeters + 300,
        );
        if (nearby != null) {
          // 還沒真的發布，把 isPublishing 收回，由 widget 跳 dialog
          _marking = _marking.copyWith(isPublishing: false);
          _safeNotify();
          return PublishHazardNearbyConflict(
            distanceMeters: (nearby['_distance'] as double).round(),
            confirmCount: (nearby['confirm_count'] as int?) ?? 1,
            typeKey: m.type,
            nearbyId: nearby['hazard_id'] as String? ?? '',
          );
        }
      }

      // 新建直接發布
      await _eventManager.publishHazard(
        type: m.type,
        severity: m.severity.round(),
        lat: m.center!.latitude,
        lng: m.center!.longitude,
        radiusMeters: m.radiusMeters,
        description: description,
      );
      exitMarking();
      unawaited(loadOverlays());
      return const PublishHazardPublished();
    } catch (e) {
      if (!_disposed) {
        _marking = _marking.copyWith(isPublishing: false);
        _safeNotify();
      }
      return PublishHazardFailure(e.toString());
    }
  }

  /// 由 hazard info sheet 的「取消發布」按鈕呼叫（編輯模式時也可手動退出）。
  void cancelMarkingPublishing() {
    if (_marking.isPublishing) {
      _marking = _marking.copyWith(isPublishing: false);
      _safeNotify();
    }
  }

  // ── Hazard interaction commands ──

  Future<ConfirmHazardOutcome> confirmHazard(HazardVm h) async {
    try {
      await _eventManager.confirmHazard(h.id);
      unawaited(loadOverlays());
      return ConfirmHazardSucceeded(
        newCount: h.confirmCount + 1,
        typeKey: h.type,
      );
    } catch (e) {
      return ConfirmHazardFailure(e.toString());
    }
  }

  Future<DeleteHazardOutcome> deleteHazard(String hazardId) async {
    try {
      await _eventManager.deleteHazard(hazardId);
      unawaited(loadOverlays());
      return const DeleteHazardSucceeded();
    } catch (e) {
      return DeleteHazardFailure(e.toString());
    }
  }

  // ── SOS / Triage commands ──

  Future<TriageOutcome> publishTriage({
    required int urgency,
    required String description,
    bool attachMedicalCard = false,
  }) async {
    try {
      final loc = _selfLocation?.location;
      final eventId = await _eventManager.publishEvent(
        urgency: urgency,
        description: description,
        lat: loc?.latitude,
        lng: loc?.longitude,
        attachMedicalCard: attachMedicalCard,
      );
      if (_disposed) {
        return TriagePublished(urgency: urgency, description: description);
      }
      if (urgency >= 2) {
        _sos = SosStateVm(
          activeEventId: eventId,
          urgency: urgency,
          description: description,
        );
        _safeNotify();
      }
      unawaited(loadOverlays());
      return TriagePublished(urgency: urgency, description: description);
    } on RateLimitException catch (e) {
      return TriageRateLimited(e.message);
    } catch (e) {
      return TriageFailure(e.toString());
    }
  }

  Future<CancelSosOutcome> cancelSos() async {
    try {
      final desc = _sos.description;
      final loc = _selfLocation?.location;
      await _eventManager.publishEvent(
        urgency: 0,
        description: '__CANCEL__:$desc',
        lat: loc?.latitude,
        lng: loc?.longitude,
      );
      if (_disposed) return const CancelSosSucceeded();
      _sos = SosStateVm.idle;
      _safeNotify();
      unawaited(loadOverlays());
      return const CancelSosSucceeded();
    } catch (e) {
      return CancelSosFailure(e.toString());
    }
  }

  // ── Lifecycle ──

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _refreshTimer?.cancel();
    _meshEventSub?.cancel();
    _meshDebounce?.cancel();
    _poiRefreshTimer?.cancel();
    _lookupDebounce?.cancel();
    _positionStream?.cancel();
    _layerSettings.removeListener(_onLayerSettingsChanged);
    _layerSettings.dispose();
    _poiQuery?.dispose();
    _mbTiles?.dispose();
    centerRequest.dispose();
    super.dispose();
  }
}

