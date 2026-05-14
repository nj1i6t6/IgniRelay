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
import 'dart:ui' show Brightness, Locale;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:latlong2/latlong.dart';
import 'package:mbtiles/mbtiles.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_map_tiles_mbtiles/vector_map_tiles_mbtiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

import 'package:ignirelay_app/app/controllers/event_publisher.dart';
import 'package:ignirelay_app/app/controllers/event_stream.dart';
import 'package:ignirelay_app/app/services/event_store.dart';
import 'package:ignirelay_app/app/services/rate_limit_exception.dart';
import 'package:ignirelay_app/app/map/mbtiles_loader.dart';
import 'package:ignirelay_app/app/map/poi_query.dart';
import 'package:ignirelay_app/app/services/location_service.dart';

import 'package:ignirelay_app/ui/screens/map/models/map_action_results.dart';
import 'package:ignirelay_app/ui/screens/map/models/map_view_models.dart';
import 'package:ignirelay_app/ui/screens/map/widgets/map_location_header.dart';
import 'package:ignirelay_app/ui/screens/map/widgets/pin_palette.dart';
import 'package:ignirelay_app/ui/screens/map/widgets/poi_category.dart';
import 'package:ignirelay_app/ui/sheets/map_layer_settings.dart';
import 'package:ignirelay_app/ui/theme/ignirelay_theme.dart';

class MapCenterRequest {
  const MapCenterRequest({
    required this.location,
    this.zoom,
    this.resetRotation = false,
  });

  final LatLng location;
  final double? zoom;
  final bool resetRotation;
}

class MapScreenController extends ChangeNotifier {
  MapScreenController({
    required EventPublisher eventPublisher,
    required EventStream eventStream,
    required EventStore eventStore,
    required LocationService locationService,
  })  : _eventPublisher = eventPublisher,
        _eventStream = eventStream,
        _eventStore = eventStore,
        _locationService = locationService {
    _layerSettings.addListener(_onLayerSettingsChanged);
  }

  final EventPublisher _eventPublisher;
  final EventStream _eventStream;
  final EventStore _eventStore;
  final LocationService _locationService;

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
  StreamSubscription<LatLng>? _locationSub;
  bool _initialFixCentered = false;

  /// 第一次 GPS 定位完成且落在台灣範圍時要求 MapView centerOn 一次。
  /// MapView 訂閱此 listenable，被 trigger 後執行 camera.move 並 reset。
  final ValueNotifier<MapCenterRequest?> centerRequest =
      ValueNotifier<MapCenterRequest?>(null);

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

  /// POI 專用 notifier（Phase 2 拆出）。POI 更新只 push 到此 notifier，不再
  /// 觸發 controller-level notifyListeners，避免外層 ListenableBuilder rebuild
  /// 整個 FlutterMap（含 VectorTileLayer 與 hazard / event / self / marking 計算）。
  /// MapView 對應位置以 ValueListenableBuilder 訂閱本 notifier 重建 POI MarkerLayer。
  final ValueNotifier<List<PoiVm>> poiNotifier =
      ValueNotifier<List<PoiVm>>(const []);

  Timer? _refreshTimer;
  StreamSubscription<EventLogChanged>? _meshEventSub;
  Timer? _meshDebounce;
  Timer? _poiRefreshTimer;
  Timer? _poiIdleTimer;
  int _overlayGen = 0;
  int _poiGen = 0;

  // ── viewport（由 MapView 回報）──
  bool _mapReady = false;
  double _viewportZoom = 15.0;
  LatLngBounds? _viewportBounds;
  bool get mapReady => _mapReady;

  // ── 地圖呈現參數（由 MapScreen.didChangeDependencies 回報）──
  // Phase 4：地圖 label 多語要求 theme 建立時必須知道 UI locale；
  // Phase 5（後續）會把 brightness 也納入 theme 推導，這裡先平行追蹤以避免
  // 兩階段交替時的 plumbing churn。
  // 不寫死 fallback locale（如 zh_TW）：避免英文系統首次進地圖先中文後英文閃爍。
  Locale? _mapLocale;
  Brightness? _mapBrightness;
  Locale? get mapLocale => _mapLocale;
  Brightness? get mapBrightness => _mapBrightness;

  /// 當前 viewport zoom（由 MapView 透過 [setViewport] 回報）。
  /// widget 端在「點擊地圖空白處查 POI」這種需要 zoom guard 的地方使用，
  /// 用以保留舊版「zoom < 12 不查」的行為與「以實際 zoom 為 nearest tolerance」的契約。
  double get viewportZoom => _viewportZoom;

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
    // 地圖 overlay 需要在 hazard / sos / supply 任一變動後重新讀 DB；改訂閱
    // 通用 anyEventChanges 通知 stream，避免 production UI 直接接觸原始 BLE
    // event 串流（後者 Stage 1 spec 僅允許 survival_mode_screen debug 用）。
    _meshEventSub = _eventStream.anyEventChanges.listen((_) {
      _meshDebounce?.cancel();
      _meshDebounce = Timer(const Duration(seconds: 2), () {
        if (_disposed) return;
        unawaited(loadOverlays());
      });
    });
  }

  Future<void> _initReporterHex() async {
    try {
      final hex = await _eventPublisher.getReporterHex();
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
      // Phase 4/5：theme 需要 UI locale + brightness；若 didChangeDependencies 尚未
      // 把兩者送入（極快的啟動路徑可能 race），保留 _mapTheme=null，等
      // updateMapPresentation 觸發 _rebuildTheme()。MapView children 會 gate 在
      // `mapTheme != null` 上不渲染 VectorTileLayer，避免閃爍中文後英文 / 亮色後暗色。
      final locale = _mapLocale;
      final brightness = _mapBrightness;
      final theme = (locale == null || brightness == null)
          ? null
          : buildIgniRelayTheme(
              locale: locale,
              brightness: brightness,
              disabledPoi: _layerSettings.disabledPoiIds,
            );

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
        final themeDesc =
            theme == null ? 'pending(locale)' : '${theme.layers.length} layers';
        debugPrint(
            '[MapController] MBTiles ready: $path, ${fileSizeMB}MB, '
            'zoom=${provider.minimumZoom}-${provider.maximumZoom}, '
            'theme=$themeDesc, tileTest=$tileTestResult');
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
    final locService = _locationService;

    // Subscribe first — broadcast stream delivers future events only,
    // so an early subscribe catches the first add() even if init() hasn't
    // completed yet. Without this, a race between MapScreen mount and
    // LocationService.init() leaves the map permanently deaf to GPS.
    _locationSub = locService.locationStream.listen((loc) {
      if (_disposed) return;
      _selfLocation = SelfLocationVm(location: loc, accuracyMeters: 0);
      _safeNotify();
      _scheduleDistrictRoadLookup(loc);
      _requestInitialCenter(loc);
    });

    // Read existing location if init() already completed
    final existing = locService.currentLocation;
    if (existing != null) {
      _selfLocation = SelfLocationVm(
        location: existing,
        accuracyMeters: 0,
      );
      _safeNotify();
      _scheduleDistrictRoadLookup(existing);
      _requestInitialCenter(existing);
    }
  }

  void _requestInitialCenter(LatLng loc) {
    if (_initialFixCentered || !_isInTaiwanBounds(loc)) return;
    _initialFixCentered = true;
    centerRequest.value = MapCenterRequest(
      location: loc,
      zoom: 15.0,
      resetRotation: true,
    );
  }

  /// widget 端 FAB「定位」按鈕呼叫；MapView 訂閱 `centerRequest` 完成 camera move。
  bool requestCenterOnUser() {
    final s = _selfLocation;
    if (s == null) return false;
    centerRequest.value = MapCenterRequest(location: s.location);
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
    bool hasGesture = false,
  }) {
    final wasReady = _mapReady;
    _mapReady = ready;
    _viewportZoom = zoom;
    _viewportBounds = bounds;

    if (!ready) return;

    if (!wasReady) {
      // 第一次 ready：viewport 剛可用，立即排一次刷新（仍走 300ms request debounce，
      // 因為 onMapReady 後可能還會有同 frame 的 onPositionChanged 補位）。
      requestPoiRefresh();
      return;
    }

    // 後續 viewport 變動：拖曳 idle 後才刷 POI；不再每次 setViewport 都打 query。
    // 拖曳期間（hasGesture=true）給 500ms idle window，避免使用者手滑頻繁觸發；
    // 程式化動作（hasGesture=false，例如 centerOn / 縮放動畫）給 350ms。
    _schedulePoiRefreshAfterIdle(
      hasGesture
          ? const Duration(milliseconds: 500)
          : const Duration(milliseconds: 350),
    );
  }

  void _schedulePoiRefreshAfterIdle(Duration delay) {
    // 取消任何先前由 requestPoiRefresh() 排下的 300ms debounce timer，避免在拖曳
    // 開始前剛好排了一個（例如 _initMBTiles 完成、或 _onLayerSettingsChanged）
    // 仍會在拖曳中觸發 _doRefreshPoi()，違反 Phase 1「拖曳期間不查 visible POI」契約。
    _poiRefreshTimer?.cancel();
    _poiRefreshTimer = null;

    _poiIdleTimer?.cancel();
    _poiIdleTimer = Timer(delay, () {
      if (_disposed) return;
      // 直接打 _doRefreshPoi()，不再經 requestPoiRefresh 的 300ms debounce，
      // 否則停止拖曳要等 idle + request debounce 雙倍延遲（最壞 800ms）。
      unawaited(_doRefreshPoi());
    });
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
    final raw = await _eventPublisher.getActiveHazards();
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
    final rows = await _eventStore.queryNonHazardMarkersWithLocation(
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
        // Phase 2：POI 更新只 push 到 poiNotifier，不再 _safeNotify()，
        // 避免拖曳結束 idle refresh 還順便重建整個 FlutterMap / VectorTileLayer。
        poiNotifier.value = const [];
      }
      return;
    }
    final bounds = _viewportBounds;
    if (!_mapReady || bounds == null) return;
    final zoom = _viewportZoom;
    if (zoom < 12) {
      if (_pois.isNotEmpty && !_disposed) {
        _pois = const [];
        poiNotifier.value = const [];
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
    poiNotifier.value = list;
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
    final locale = _mapLocale;
    final brightness = _mapBrightness;
    if (locale == null || brightness == null) {
      return; // 等 updateMapPresentation 把 locale + brightness 送入
    }
    final theme = buildIgniRelayTheme(
      locale: locale,
      brightness: brightness,
      disabledPoi: _layerSettings.disabledPoiIds,
    );
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

  /// 由 [MapScreen.didChangeDependencies] 在每次 inherited locale / theme 變動
  /// 時呼叫。Phase 4 只用 [locale] 影響 theme（label 多語）；[brightness] 已 plumb
  /// 進來但 theme 還沒吃，留給 Phase 5（地圖深淺色 theme）填上。
  ///
  /// 同 locale + brightness 重入會 short-circuit，避免每次 build 都重建 theme。
  void updateMapPresentation({
    required Locale locale,
    required Brightness brightness,
  }) {
    if (_disposed) return;
    final localeChanged = _mapLocale != locale;
    final brightnessChanged = _mapBrightness != brightness;
    if (!localeChanged && !brightnessChanged) return;
    _mapLocale = locale;
    _mapBrightness = brightness;
    // Phase 5：locale 或 brightness 任一變動都重建 theme；首次（_mapTheme == null）
    // 也走這條路。
    if (localeChanged || brightnessChanged || _mapTheme == null) {
      _rebuildTheme();
    }
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
        await _eventPublisher.confirmHazard(confirmExistingId);
        exitMarking();
        unawaited(loadOverlays());
        return PublishHazardConfirmedExisting(typeKey: m.type);
      }

      // 編輯模式
      if (m.isEditing) {
        await _eventPublisher.updateHazard(
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
        final nearby = await _eventPublisher.findNearbyHazard(
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
      await _eventPublisher.publishHazard(
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
      await _eventPublisher.confirmHazard(h.id);
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
      await _eventPublisher.deleteHazard(hazardId);
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
      final eventId = await _eventPublisher.publishEvent(
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

  /// 發布「SOS 取消」事件。
  ///
  /// 設計考量：
  ///   - r2 第一版曾把 description 寫成 `__CANCEL__:$desc` 這種內部 sentinel 字串，
  ///     但 repo 內沒有 consumer 解析這個 prefix；event log / detail UI 反而會直接
  ///     露出 `__CANCEL__:` 給使用者看。同時 r1 原本是用 i18n key
  ///     `mapSosCancelledPrefix`（"【SOS 已取消】"/"[SOS Cancelled]"）組 human-readable
  ///     文案，這個格式仍是 wire 上唯一被認得的取消標記。
  ///   - 為避免 controller 直接吃 BuildContext / l10n，由 widget 端把已本地化的
  ///     prefix 字串傳進來；controller 仍保持「無 BuildContext」的純度。
  ///
  /// [descriptionPrefix] 通常是 `context.l10n.mapSosCancelledPrefix`。
  Future<CancelSosOutcome> cancelSos({required String descriptionPrefix}) async {
    try {
      final desc = _sos.description;
      final loc = _selfLocation?.location;
      await _eventPublisher.publishEvent(
        urgency: 0,
        description: '$descriptionPrefix$desc',
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
    _poiIdleTimer?.cancel();
    _lookupDebounce?.cancel();
    _locationSub?.cancel();
    _layerSettings.removeListener(_onLayerSettingsChanged);
    _layerSettings.dispose();
    _poiQuery?.dispose();
    _mbTiles?.dispose();
    centerRequest.dispose();
    poiNotifier.dispose();
    super.dispose();
  }
}
