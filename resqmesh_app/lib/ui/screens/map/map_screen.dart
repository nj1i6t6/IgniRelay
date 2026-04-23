import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:mbtiles/mbtiles.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_map_tiles_mbtiles/vector_map_tiles_mbtiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;
import 'package:ignirelay_app/app/mesh/mbtiles_loader.dart';
import 'package:ignirelay_app/app/mesh/event_manager.dart';
import 'package:ignirelay_app/app/mesh/event_types.dart';
import 'package:ignirelay_app/app/mesh/poi_query.dart';
import 'package:ignirelay_app/app/db/database_helper.dart';
import 'package:ignirelay_app/ui/theme/igni_colors.dart';
import 'package:ignirelay_app/ui/theme/igni_typography.dart';
import 'package:ignirelay_app/ui/widgets/ignirelay_sprites.dart';
import 'package:ignirelay_app/ui/theme/ignirelay_theme.dart';
import 'package:ignirelay_app/ui/secondary/triage_input.dart';
import 'package:ignirelay_app/ui/sheets/map_layer_settings.dart';
import 'package:ignirelay_app/ui/screens/map/widgets/event_marker_icon.dart';
import 'package:ignirelay_app/ui/screens/map/widgets/cluster_bubble.dart';
import 'package:ignirelay_app/ui/screens/map/widgets/pin_palette.dart';
import 'package:ignirelay_app/ui/screens/map/widgets/map_fab_column.dart';
import 'package:ignirelay_app/ui/screens/map/widgets/map_location_header.dart';
import 'package:ignirelay_app/ui/screens/map/widgets/poi_category.dart';
import 'package:ignirelay_app/ui/screens/map/widgets/marking_panel.dart';
import 'package:ignirelay_app/ui/screens/map/widgets/map_loading_screen.dart';
import 'package:ignirelay_app/ui/screens/map/widgets/map_error_screen.dart';
import 'package:ignirelay_app/ui/screens/map/widgets/map_legend_panel.dart';
import 'package:ignirelay_app/ui/screens/map/sheets/poi_info_sheet.dart';
import 'package:ignirelay_app/ui/screens/map/sheets/event_info_sheet.dart';
import 'package:ignirelay_app/ui/screens/map/sheets/hazard_info_sheet.dart';
import 'package:ignirelay_app/ui/screens/map/sheets/hazard_delete_dialog.dart';
import 'package:ignirelay_app/ui/screens/map/sheets/sos_cancel_dialog.dart';
import 'package:ignirelay_app/ui/screens/map/sheets/hazard_nearby_dialog.dart';
import 'package:ignirelay_app/app/mesh/mesh_event_handler.dart';
// NOTE(Stage 4d Round 2): pb.*, LocationService, supply_category_data 原用於
// _showEventInfo，現已移至 sheets/event_info_sheet.dart，故本檔不再 import。
import 'package:ignirelay_app/l10n/generated/app_localizations.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final MapController _mapController = MapController();
  late final AnimationController _refreshSpinCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );
  bool _isRefreshing = false;
  // 預設台灣中心，GPS 取得後會更新
  LatLng _center = const LatLng(23.97, 120.97);
  final _eventManager = EventManager();

  // ── 地圖底圖 ──
  bool _mbtilesLoading = true;
  bool _mbtilesAvailable = false;
  String? _mbtilesError; // stores ARB key: 'mapMbtilesNotFound' | 'mapMbtilesLoadFail'
  String? _mbtilesErrorArg; // dynamic arg for mapMbtilesLoadFail
  MbTiles? _mbTiles;
  MbTilesVectorTileProvider? _tileProvider;
  TileProviders? _tileProviders;
  vtr.Theme? _mapTheme;
  SpriteStyle? _spriteStyle;
  PoiQuery? _poiQuery;

  // ── GPS 定位 ──
  LatLng? _userLocation;
  StreamSubscription<Position>? _positionStream;
  double _gpsAccuracy = 0;

  // ── Overlays ──
  List<Polygon> _hazardPolygons = [];
  List<Marker> _hazardCenterMarkers = [];
  List<Map<String, dynamic>> _hazardData = [];
  List<Marker> _eventMarkers = [];
  // Stage 4d: 與 _eventMarkers 同步的 PinCategory 索引，供叢集 bubble 擇色用。
  List<PinCategory> _eventMarkerCategories = [];
  List<Marker> _poiMarkers = [];
  Timer? _refreshTimer;
  StreamSubscription? _meshEventSub;
  Timer? _meshDebounce;
  bool _showLegend = false;
  String _myReporterHex = '';

  // ── 圖層設定 ──
  final MapLayerSettings _layerSettings = MapLayerSettings();
  int _themeGeneration = 0;

  // ── POI 標記防抖 ──
  Timer? _poiRefreshTimer;

  // ── 危險標記模式 ──
  bool _isMarkingMode = false;
  LatLng? _markCenter;
  double _markRadius = 200.0;
  String _markType = 'ROADBLOCK';
  double _markSeverity = 3.0;
  final _markDescCtrl = TextEditingController();
  bool _markPublishing = false;
  String? _editingHazardId; // 非 null = 編輯模式


  // ── SOS 狀態追蹤 ──
  String? _activeSosEventId;
  int _activeSosUrgency = 0;
  String _activeSosDesc = '';

  /// Stage 4d 規範：hazard 一律紅（PinCategory.hazard），icon 做次分類。
  /// label 仍由 i18n 給，維持既有鍵值；color 改由 PinPalette 集中管理。
  static (String, IconData, Color) _hazardInfo(BuildContext context, String type) {
    final l = S.of(context)!;
    final color = PinPalette.color(PinCategory.hazard);
    switch (type) {
      case 'ROADBLOCK': return (l.mapHazardRoadblock, PinPalette.hazardIcon(type), color);
      case 'FIRE': return (l.mapHazardFire, PinPalette.hazardIcon(type), color);
      case 'CHEMICAL': return (l.mapHazardChemical, PinPalette.hazardIcon(type), color);
      case 'FLOOD': return (l.mapHazardFlood, PinPalette.hazardIcon(type), color);
      case 'BUILDING': return (l.mapHazardCollapse, PinPalette.hazardIcon(type), color);
      case 'LANDSLIDE': return (l.mapHazardLandslide, PinPalette.hazardIcon(type), color);
      default: return (type, Icons.help, color);
    }
  }

  @override
  void initState() {
    super.initState();
    _initMBTiles();
    _initGPS();
    _initReporterHex();
    _loadOverlays();
    // 每 15 秒自動刷新 overlay (危險區域 + Mesh 事件)
    _refreshTimer =
        Timer.periodic(const Duration(seconds: 15), (_) => _loadOverlays());
    // 監聽 Mesh 事件，即時刷新 overlay
    _meshEventSub = MeshEventHandler().events.listen((_) {
      _meshDebounce?.cancel();
      _meshDebounce = Timer(const Duration(seconds: 2), () {
        if (mounted) _loadOverlays();
      });
    });
    // 監聽圖層設定變化
    _layerSettings.addListener(_onLayerSettingsChanged);
  }

  @override
  void dispose() {
    _refreshSpinCtrl.dispose();
    _poiQuery?.dispose();
    _mbTiles?.dispose();
    _positionStream?.cancel();
    _refreshTimer?.cancel();
    _meshEventSub?.cancel();
    _meshDebounce?.cancel();
    _poiRefreshTimer?.cancel();
    _markDescCtrl.dispose();
    _layerSettings.removeListener(_onLayerSettingsChanged);
    _layerSettings.dispose();
    super.dispose();
  }

  Future<void> _initReporterHex() async {
    _myReporterHex = await _eventManager.getReporterHex();
  }

  void _onLayerSettingsChanged() {
    _rebuildTheme();
    _loadHazards();
    _refreshPoiMarkers(); // #3 Fix: 圖層控制變化時刷新 POI 圓點
  }

  void _rebuildTheme() {
    if (!_mbtilesAvailable || _mbTiles == null) return;
    final theme =
        buildIgniRelayTheme(disabledPoi: _layerSettings.disabledPoiIds);
    SpriteStyle? sprites;
    try {
      sprites = buildIgniRelaySprites();
    } catch (e) {
      debugPrint('[Map] rebuildTheme sprite 失敗 (非致命): $e');
    }
    // 重建 TileProviders → VectorTileLayer 用新 Key 完整重建
    final provider = MbTilesVectorTileProvider(mbtiles: _mbTiles!);
    if (mounted) {
      setState(() {
        _tileProvider = provider;
        _tileProviders = TileProviders({'openmaptiles': provider});
        _mapTheme = theme;
        _spriteStyle = sprites;
        _themeGeneration++;
      });
    }
  }

  // ── MBTiles 離線地圖初始化 ─────────────────────────────────────

  Future<void> _initMBTiles() async {
    try {
      final available = await MBTilesLoader.isAvailable();
      if (!available) {
        debugPrint('[Map] MBTiles NOT available');
        if (mounted) {
          setState(() {
            _mbtilesLoading = false;
            _mbtilesError = 'mapMbtilesNotFound';
          });
        }
        return;
      }

      final path = await MBTilesLoader.getLocalPath();
      await MBTilesLoader.sanitizeMetadata(path);

      // 複製 POI 詳情資料庫（首次啟動）
      final poiDbPath = await _ensurePoiDetailsDb();

      final mbTiles = MbTiles(mbtilesPath: path, gzip: true);
      final provider = MbTilesVectorTileProvider(mbtiles: mbTiles);
      final theme = buildIgniRelayTheme();

      // sprites 載入失敗不應阻止地圖渲染
      SpriteStyle? sprites;
      try {
        sprites = buildIgniRelaySprites();
      } catch (e) {
        debugPrint('[Map] Sprite 載入失敗 (非致命): $e');
      }

      // 驗證 tile 資料是否可讀取
      // MBTiles 使用 TMS 座標系 (Y 軸翻轉): tmsY = (2^z - 1) - xyzY
      // 台灣中心 z10/x859/y442(XYZ) → z10/x859/y581(TMS)
      String tileTestResult = 'untested';
      int tileTestBytes = 0;
      try {
        final tmsY = ((1 << 10) - 1) - 442; // = 581
        final testTile = mbTiles.getTile(z: 10, x: 859, y: tmsY);
        if (testTile != null) {
          tileTestBytes = testTile.length;
          tileTestResult = 'OK ${testTile.length}B';
        } else {
          // 也試試直接用 XYZ Y 看看（如果 MBTiles 是 XYZ 編碼）
          final testTileXyz = mbTiles.getTile(z: 10, x: 859, y: 442);
          if (testTileXyz != null) {
            tileTestBytes = testTileXyz.length;
            tileTestResult = 'OK(xyz) ${testTileXyz.length}B';
          } else {
            tileTestResult = 'NULL z10/859/tms$tmsY+xyz442';
          }
        }
      } catch (e) {
        tileTestResult = 'ERR: $e';
      }

      // 取得檔案大小
      final fileSize = File(path).lengthSync();
      final fileSizeMB = (fileSize / 1024 / 1024).toStringAsFixed(1);

      debugPrint(
          '[Map] MBTiles ready: path=$path, size=${fileSizeMB}MB, '
          'zoom=${provider.minimumZoom}-${provider.maximumZoom}, '
          'theme=${theme.layers.length} layers, sprites=${sprites != null ? "OK" : "NULL"}, '
          'tileTest=$tileTestResult');

      if (mounted) {
        setState(() {
          _mbTiles = mbTiles;
          _poiQuery = PoiQuery(mbtilesPath: path, poiDetailsPath: poiDbPath);
          _tileProvider = provider;
          _tileProviders = TileProviders({'openmaptiles': provider});
          _mapTheme = theme;
          _spriteStyle = sprites;
          _mbtilesAvailable = true;

        });
        _refreshPoiMarkers();
      }
    } catch (e, stack) {
      debugPrint('[Map] MBTiles init error: $e\n$stack');
      if (mounted) {
        setState(() {
        _mbtilesError = 'mapMbtilesLoadFail';
        _mbtilesErrorArg = e.toString();
      });
      }
    } finally {
      if (mounted) setState(() => _mbtilesLoading = false);
    }
  }

  /// 複製 poi_details.db 到 app 文件目錄（首次啟動）
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
        debugPrint('[Map] POI details DB copied: ${target.lengthSync()} bytes');
      }
      return target.path;
    } catch (e) {
      debugPrint('[Map] POI details DB not available: $e');
      return null; // 退化模式：只有基本 POI 資訊
    }
  }

  // ── 台灣範圍判定 ────────────────────────────────────────────────────

  /// 檢查座標是否在台灣 MBTiles 範圍內（含外島緩衝）
  bool _isInTaiwanBounds(LatLng loc) {
    return loc.latitude >= 20.5 &&
        loc.latitude <= 26.8 &&
        loc.longitude >= 117.9 &&
        loc.longitude <= 123.1;
  }
  // ── GPS 定位 ────────────────────────────────────────────────────

  Future<void> _initGPS() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[GPS] Location service disabled');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('[GPS] Permission denied');
        return;
      }

      // 取得初始位置
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        throw TimeoutException('GPS timeout');
      });

      if (mounted) {
        final loc = LatLng(pos.latitude, pos.longitude);
        setState(() {
          _userLocation = loc;
          _gpsAccuracy = pos.accuracy;
        });
        // 只在 GPS 位置落在台灣離線地圖範圍內才移動視角
        if (_isInTaiwanBounds(loc)) {
          setState(() => _center = loc);
          _mapController.move(loc, 15.0);
          _refreshPoiMarkers(); // #2 Fix: GPS 跳轉後主動刷新 POI
        }
      }

      // 持續監聽位置變化
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // 移動 10m 才更新
        ),
      ).listen((pos) {
        if (mounted) {
          setState(() {
            _userLocation = LatLng(pos.latitude, pos.longitude);
            _gpsAccuracy = pos.accuracy;
          });
        }
      });
    } catch (e) {
      debugPrint('[GPS] Init error: $e');
    }
  }

  // ── 載入 Overlay 圖層 (危險區域 + Mesh 事件標記) ────────────────

  Future<void> _loadOverlays() async {
    await Future.wait([_loadHazards(), _loadEventMarkers()]);
  }

  /// 帶旋轉動畫的重新整理
  Future<void> _refreshWithSpin() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    _refreshSpinCtrl.repeat();
    try {
      // 至少轉滿一圈 (800ms)，載入較久則繼續轉
      await Future.wait([
        _loadOverlays(),
        Future.delayed(const Duration(milliseconds: 800)),
      ]);
    } finally {
      _refreshSpinCtrl.stop();
      _refreshSpinCtrl.reset();
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _loadHazards() async {
    if (!_layerSettings.showHazards) {
      if (mounted) {
        setState(() {
          _hazardPolygons = [];
          _hazardCenterMarkers = [];
          _hazardData = [];
        });
      }
      return;
    }
    final hazards = await _eventManager.getActiveHazards();
    final polygons = <Polygon>[];
    final centerMarkers = <Marker>[];
    final filteredData = <Map<String, dynamic>>[];

    for (final h in hazards) {
      final lat = (h['lat'] as num?)?.toDouble();
      final lng = (h['lng'] as num?)?.toDouble();
      final radius = (h['radius'] as num?)?.toDouble() ?? 200.0;
      final severity = (h['severity'] as int?) ?? 3;
      final type = h['type'] as String? ?? '';
      final confirmCount = (h['confirm_count'] as int?) ?? 1;
      final reportedBy = h['reported_by'] as String? ?? '';
      if (lat == null || lng == null) continue;

      final isMine = reportedBy == _myReporterHex;

      // 篩選：不顯示他人的 / confirm_count 不夠
      if (!isMine && !_layerSettings.showOtherHazards) continue;
      if (!isMine && confirmCount < _layerSettings.minConfirmCount) continue;

      // Stage 4d Round 2 bug fix：多邊形底色保留「按 type + 嚴重度」分色
      // （這是功能：讓使用者一眼辨識災害種類與緊急度）；但中心 marker 統一
      // 改用 PinPalette.color(PinCategory.hazard) 紅，對齊 plan §Stage 4d
      // L231「hazard 大類一色」。icon 仍做次分類。
      Color polygonColor;
      switch (type) {
        case 'FIRE':
          polygonColor = Colors.red;
        case 'FLOOD':
          polygonColor = Colors.blue;
        case 'CHEMICAL':
          polygonColor = Colors.yellow;
        case 'BUILDING':
          polygonColor = Colors.brown;
        case 'LANDSLIDE':
          polygonColor = Colors.grey;
        default:
          polygonColor = Colors.orange;
      }
      if (severity >= 4) polygonColor = Colors.red;

      // 圓形多邊形 (36 邊) 取代菱形
      final points = _circlePolygonPoints(lat, lng, radius);

      // 未驗證 (confirm=1) 用虛線邊框，已驗證用實線
      polygons.add(Polygon(
        points: points,
        color: polygonColor.withValues(alpha: confirmCount >= 2 ? 0.25 : 0.12),
        borderColor: polygonColor,
        borderStrokeWidth: confirmCount >= 3 ? 3.0 : 2.0,
        pattern: confirmCount < 2
            ? const StrokePattern.dotted()
            : const StrokePattern.solid(),
      ));

      filteredData.add(h);

      // 中心標記（含確認人數 badge）—— 大類一色紅
      final (_, typeIcon, _) = _hazardInfo(context, type);
      final markerColor = PinPalette.color(PinCategory.hazard);
      centerMarkers.add(Marker(
        point: LatLng(lat, lng),
        width: 44,
        height: 44,
        child: GestureDetector(
          onTap: () => _openHazardInfo(h),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: markerColor.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isMine ? Colors.greenAccent : Colors.white,
                    width: isMine ? 2.5 : 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: markerColor.withValues(alpha: 0.5),
                        blurRadius: 6),
                  ],
                ),
                child: Icon(typeIcon, color: Colors.white, size: 18),
              ),
              if (confirmCount > 1)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange, width: 1),
                    ),
                    child: Text(
                      '×$confirmCount',
                      style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 9,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ));
    }

    if (mounted) {
      setState(() {
        _hazardPolygons = polygons;
        _hazardCenterMarkers = centerMarkers;
        _hazardData = filteredData;
      });
    }
  }

  /// 產生圓形多邊形頂點
  static List<LatLng> _circlePolygonPoints(
      double lat, double lng, double radiusM,
      {int segments = 36}) {
    final latR = lat * pi / 180;
    final latDelta = radiusM / 111320.0;
    final lngDelta = radiusM / (111320.0 * cos(latR));
    return List.generate(segments, (i) {
      final a = 2 * pi * i / segments;
      return LatLng(lat + latDelta * sin(a), lng + lngDelta * cos(a));
    });
  }

  Future<void> _loadEventMarkers() async {
    final db = await DatabaseHelper().database;
    // 載入最近 24 小時的 Mesh 事件，含座標（排除 hazardMarker，它有獨立圖層）
    final cutoff = DateTime.now().millisecondsSinceEpoch - (24 * 3600 * 1000);
    final events = await db.query(
      'Event_Logs',
      where:
          'hlc_timestamp > ? AND received_lat IS NOT NULL AND received_lng IS NOT NULL AND event_type != ?',
      whereArgs: [cutoff, EventType.hazardMarker],
      orderBy: 'urgency DESC, hlc_timestamp DESC',
      limit: 100,
    );

    final markers = <Marker>[];
    final categories = <PinCategory>[];
    if (!mounted) return;
    final evtL = S.of(context)!;
    for (final evt in events) {
      final lat = (evt['received_lat'] as num?)?.toDouble();
      final lng = (evt['received_lng'] as num?)?.toDouble();
      final urgency = (evt['urgency'] as int?) ?? 0;
      final eventType = (evt['event_type'] as int?) ?? 0;
      if (lat == null || lng == null || lat == 0 || lng == 0) continue;

      // Bug 9: 過濾 urgency=0 INFO 事件
      if (urgency == 0) continue;

      // Stage 4d: 顏色改由 PinPalette 大類一色決定，icon 只做次分類。
      PinCategory category;
      IconData markerIcon;
      double markerSize;
      String tooltip;

      switch (urgency) {
        case 3: // SOS_RED → hazard（紅）
          category = PinCategory.hazard;
          markerIcon = Icons.sos;
          markerSize = 36;
          tooltip = evtL.mapEventSosRed;
          break;
        case 2: // SOS_YELLOW → life（橘）
          category = PinCategory.life;
          markerIcon = Icons.warning_amber;
          markerSize = 32;
          tooltip = evtL.mapEventSosYellow;
          break;
        case 1: // RESOURCE → supply（綠）
          category = PinCategory.supply;
          markerIcon =
              eventType == 0 ? Icons.inventory_2 : Icons.volunteer_activism;
          markerSize = 28;
          tooltip = evtL.mapEventSupply;
          break;
        default: // INFO → life
          category = PinCategory.life;
          markerIcon = Icons.info_outline;
          markerSize = 24;
          tooltip = evtL.mapEventInfo;
      }
      final markerColor = PinPalette.color(category);

      // 解讀 payload 取得描述
      final payload = evt['payload'] as Uint8List?;
      String desc = '';
      if (payload != null) {
        try {
          desc = String.fromCharCodes(payload);
          if (desc.length > 40) desc = '${desc.substring(0, 40)}...';
        } catch (_) {}
      }

      // Bug 8: 加入事件資訊的引用資料
      final evtData = Map<String, dynamic>.from(evt);

      markers.add(Marker(
        point: LatLng(lat, lng),
        width: markerSize + 4,
        height: markerSize + 4,
        child: GestureDetector(
          onTap: () => EventInfoSheet.show(
            context,
            evtData,
            userLocation: _userLocation,
          ),
          child: EventMarkerIcon(
            icon: markerIcon,
            color: markerColor,
            size: markerSize,
            tooltip: '$tooltip${desc.isNotEmpty ? '\n$desc' : ''}',
            isSOS: urgency >= 2,
          ),
        ),
      ));
      categories.add(category);
    }

    if (mounted) {
      setState(() {
        _eventMarkers = markers;
        _eventMarkerCategories = categories;
      });
    }
  }

  // ── POI / 危險區域 點擊 ──────────────────────────────────────────

  Future<void> _onMapTap(TapPosition tapPosition, LatLng latlng) async {
    // 標記模式：點擊 = 移動標記中心
    if (_isMarkingMode) {
      setState(() => _markCenter = latlng);
      return;
    }

    // 檢查是否點到危險區域（由中心標記的 GestureDetector 處理）
    // 這裡只處理 POI 查詢
    if (_poiQuery == null) return;
    final zoom = _mapController.camera.zoom;
    if (zoom < 12) return;

    final poi = await _poiQuery!.queryNearestPoi(latlng, zoom);
    if (poi == null || !mounted) return;
    PoiInfoSheet.show(context, poi);
  }

  // Stage 4d Round 2: _showPoiInfoSheet / _poiInfoRow / _poiHoursWidget /
  // _formatOpeningHours 已移至 sheets/poi_info_sheet.dart；
  // _poiCategoryLabel/Id/Color/Icon 已移至 widgets/poi_category.dart。

  List<Marker> _buildPoiMarkers(List<Map<String, String>> pois) {
    final markers = <Marker>[];
    for (final poi in pois) {
      final lat = double.tryParse(poi['lat'] ?? '') ?? 0;
      final lng = double.tryParse(poi['lng'] ?? '') ?? 0;
      final cls = poi['class'] ?? '';
      final sub = poi['subclass'] ?? '';

      // #1 Fix: 只顯示五大救災類別的 POI
      final catId = PoiCategories.id(cls, sub);
      if (catId == null) continue;

      // #3 Fix: 圖層控制 - 檢查類別是否啟用
      if (!_layerSettings.showPoi) continue;
      if (!_layerSettings.poiIsEnabled(catId)) continue;

      final color = PoiCategories.color(cls, sub);
      final icon = PoiCategories.icon(cls, sub);

      markers.add(Marker(
        point: LatLng(lat, lng),
        width: 24,
        height: 24,
        child: GestureDetector(
          onTap: () => PoiInfoSheet.show(context, poi),
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1)),
              ],
            ),
            child: Icon(icon, size: 12, color: Colors.white),
          ),
        ),
      ));
    }
    return markers;
  }

  void _refreshPoiMarkers() {
    _poiRefreshTimer?.cancel();
    _poiRefreshTimer = Timer(const Duration(milliseconds: 300), () {
      _doRefreshPoiMarkers();
    });
  }

  Future<void> _doRefreshPoiMarkers() async {
    if (_poiQuery == null) return;
    // 圖層關閉時清空
    if (!_layerSettings.showPoi) {
      if (_poiMarkers.isNotEmpty && mounted) {
        setState(() => _poiMarkers = []);
      }
      return;
    }
    final zoom = _mapController.camera.zoom;
    if (zoom < 12) {
      if (_poiMarkers.isNotEmpty) {
        setState(() => _poiMarkers = []);
      }
      return;
    }
    final bounds = _mapController.camera.visibleBounds;
    final pois = await _poiQuery!.queryVisiblePois(
      south: bounds.south,
      west: bounds.west,
      north: bounds.north,
      east: bounds.east,
      zoom: zoom,
    );
    if (!mounted) return;
    setState(() => _poiMarkers = _buildPoiMarkers(pois));
  }

  Future<void> _onMapLongPress(TapPosition tapPosition, LatLng latlng) async {
    if (_isMarkingMode) return; // 已在標記模式
    setState(() {
      _isMarkingMode = true;
      _markCenter = latlng;
      _markRadius = 200.0;
      _markType = 'ROADBLOCK';
      _markSeverity = 3.0;
      _markDescCtrl.clear();
      _markPublishing = false;
      _editingHazardId = null;
    });
  }

  void _exitMarkingMode() {
    setState(() {
      _isMarkingMode = false;
      _markCenter = null;
      _editingHazardId = null;
    });
  }

  /// 發布或更新危險標記（含附近重複檢查）
  Future<void> _publishOrUpdateMark() async {
    if (_markCenter == null) return;
    setState(() => _markPublishing = true);

    try {
      // ── 編輯模式 ──
      if (_editingHazardId != null) {
        await _eventManager.updateHazard(
          _editingHazardId!,
          type: _markType,
          severity: _markSeverity.round(),
          lat: _markCenter!.latitude,
          lng: _markCenter!.longitude,
          radiusMeters: _markRadius,
          description: _markDescCtrl.text,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(S.of(context)!.mapHazardUpdatedSnack), backgroundColor: Colors.green),
          );
        }
        _exitMarkingMode();
        _loadOverlays();
        return;
      }

      // ── 新建模式：先查附近是否已有同類型回報 ──
      final nearby = await _eventManager.findNearbyHazard(
        _markCenter!.latitude,
        _markCenter!.longitude,
        _markType,
        searchRadius: _markRadius + 300, // 允許一些重疊
      );

      if (nearby != null && mounted) {
        final dist = (nearby['_distance'] as double).round();
        final cnt = (nearby['confirm_count'] as int?) ?? 1;
        final (typeLabel, _, _) = _hazardInfo(context, _markType);
        final action = await HazardNearbyDialog.show(
          context,
          distanceMeters: dist,
          confirmCount: cnt,
          typeLabel: typeLabel,
        );

        if (action == 'confirm') {
          await _eventManager.confirmHazard(nearby['hazard_id'] as String);
          if (mounted) {
            final (tl, _, _) = _hazardInfo(context, _markType);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(S.of(context)!.mapHazardConfirmSnack(tl, 1)),
                backgroundColor: Colors.green,
              ),
            );
          }
          _exitMarkingMode();
          _loadOverlays();
          return;
        }
        // action == 'new' 或 null (取消) → 繼續建立
        if (action == null) {
          setState(() => _markPublishing = false);
          return;
        }
      }

      // ── 發布新標記 ──
      await _eventManager.publishHazard(
        type: _markType,
        severity: _markSeverity.round(),
        lat: _markCenter!.latitude,
        lng: _markCenter!.longitude,
        radiusMeters: _markRadius,
        description: _markDescCtrl.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(S.of(context)!.mapHazardPublishedSnack), backgroundColor: Colors.orange),
        );
      }
      _exitMarkingMode();
      _loadOverlays();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context)!.mapMbtilesLoadFail(e.toString())), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _markPublishing = false);
    }
  }

  // ── 危險標記詳情面板 ──────────────────────────────────────────
  // Stage 4d Round 2：原 `_showHazardInfo` 已移至 sheets/hazard_info_sheet.dart。
  // 這個 wrapper 負責把 `_MapScreenState` 私有狀態 (`_myReporterHex`、
  // `_hazardInfo`、`_eventManager` 等) 封裝成 callback 傳入。

  void _openHazardInfo(Map<String, dynamic> h) {
    final type = h['type'] as String? ?? '';
    final confirmCount = (h['confirm_count'] as int?) ?? 1;
    final reportedBy = h['reported_by'] as String? ?? '';
    final hazardId = h['hazard_id'] as String? ?? '';
    final isMine = reportedBy == _myReporterHex;
    final (typeLabel, typeIcon, typeColor) = _hazardInfo(context, type);

    HazardInfoSheet.show(
      context,
      hazard: h,
      typeLabel: typeLabel,
      typeIcon: typeIcon,
      typeColor: typeColor,
      isMine: isMine,
      onEdit: () => _enterEditMode(h),
      onDelete: () => _deleteHazardConfirm(hazardId),
      onConfirm: () async {
        await _eventManager.confirmHazard(hazardId);
        _loadOverlays();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(S.of(context)!
                  .mapHazardConfirmSnack(typeLabel, confirmCount + 1)),
              backgroundColor: Colors.green,
            ),
          );
        }
      },
    );
  }

  // ── 事件標記詳情面板 ────────────────────────────────────────────
  // Stage 4d Round 2: 原 `_showEventInfo` 已整段移至 sheets/event_info_sheet.dart，
  // tap callback 直接呼叫 `EventInfoSheet.show(context, evt, userLocation: ...)`。

  void _enterEditMode(Map<String, dynamic> h) {
    setState(() {
      _isMarkingMode = true;
      _editingHazardId = h['hazard_id'] as String?;
      _markCenter = LatLng(
        (h['lat'] as num).toDouble(),
        (h['lng'] as num).toDouble(),
      );
      _markRadius = (h['radius'] as num?)?.toDouble() ?? 200.0;
      _markType = h['type'] as String? ?? 'ROADBLOCK';
      _markSeverity = ((h['severity'] as int?) ?? 3).toDouble();
      _markDescCtrl.text = h['description'] as String? ?? '';
      _markPublishing = false;
    });
  }

  Future<void> _deleteHazardConfirm(String hazardId) async {
    final confirmed = await HazardDeleteDialog.show(context);
    if (!confirmed || !mounted) return;
    await _eventManager.deleteHazard(hazardId);
    _loadOverlays();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(S.of(context)!.mapHazardDeletedSnack),
            backgroundColor: Colors.green),
      );
    }
  }

  // ── 圖層控制面板 ──────────────────────────────────────────────

  void _showLayerControlSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1a1a2e),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => MapLayerControlSheet(settings: _layerSettings),
    );
  }

  Future<void> _onTriageSubmit(int urgency, String desc,
      {bool attachMedicalCard = false}) async {
    try {
      final eventId = await _eventManager.publishEvent(
        urgency: urgency,
        description: desc,
        lat: _userLocation?.latitude,
        lng: _userLocation?.longitude,
        attachMedicalCard: attachMedicalCard,
      );
      if (mounted) {
        // 追蹤 SOS 狀態（urgency >= 2 為 SOS 等級）
        if (urgency >= 2) {
          setState(() {
            _activeSosEventId = eventId;
            _activeSosUrgency = urgency;
            _activeSosDesc = desc;
          });
        }
        final lTriage = S.of(context)!;
        final labels = [
          lTriage.mapTriageBroadcastLabel0,
          lTriage.mapTriageBroadcastLabel1,
          lTriage.mapTriageBroadcastLabel2,
          lTriage.mapTriageBroadcastLabel3,
        ];
        final colors = [
          Colors.blue[700],
          Colors.green[700],
          Colors.orange[700],
          Colors.red[700]
        ];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lTriage.mapTriageBroadcastSnack(labels[urgency], desc)),
            backgroundColor: colors[urgency],
          ),
        );
        _loadOverlays(); // 即時刷新事件標記
      }
    } on RateLimitException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.orange),
        );
      }
    }
  }

  /// 取消 SOS 求救
  Future<void> _cancelSos() async {
    final confirm = await SosCancelDialog.show(context);
    if (!confirm || !mounted) return;

    try {
      // 發布取消事件到 Mesh 網路
      await _eventManager.publishEvent(
        urgency: 0, // INFO level
        description: '${S.of(context)!.mapSosCancelledPrefix}$_activeSosDesc',
        lat: _userLocation?.latitude,
        lng: _userLocation?.longitude,
      );
      setState(() {
        _activeSosEventId = null;
        _activeSosUrgency = 0;
        _activeSosDesc = '';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.of(context)!.mapSosCancelledSnack),
            backgroundColor: Colors.grey[700],
          ),
        );
        _loadOverlays();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context)!.mapSosCancelFailSnack(e.toString())), backgroundColor: Colors.red[700]),
        );
      }
    }
  }

  void _centerOnUser() {
    if (_userLocation != null) {
      _mapController.moveAndRotate(_userLocation!, 15.0, 0.0);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(S.of(context)!.mapGpsNotReady),
            backgroundColor: Colors.orange),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final p = context.igni;
    return Scaffold(
      backgroundColor: p.bg0,
      appBar: AppBar(
        backgroundColor: p.bg1,
        foregroundColor: p.text0,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(S.of(context)!.mapTitle,
                style: IgniTypography.titleMedium(p.text0)),
            Text(
              '${_eventMarkers.length} EVENTS · ${_hazardCenterMarkers.length} HAZARDS',
              style: IgniTypography.monoSmall(p.text2),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.layers, color: p.text1),
            onPressed: _showLayerControlSheet,
            tooltip: S.of(context)!.mapLayerControlTooltip,
          ),
          IconButton(
            icon: Icon(Icons.legend_toggle, color: p.text1),
            onPressed: () => setState(() => _showLegend = !_showLegend),
            tooltip: S.of(context)!.mapLegendTooltip,
          ),
          IconButton(
            icon: AnimatedBuilder(
              animation: _refreshSpinCtrl,
              builder: (_, child) => Transform.rotate(
                angle: _refreshSpinCtrl.value * 2 * 3.14159265,
                child: child,
              ),
              child: Icon(Icons.refresh, color: p.text1),
            ),
            onPressed: _refreshWithSpin,
            tooltip: S.of(context)!.mapRefreshTooltip,
          ),
        ],
      ),
      body: _mbtilesLoading
          ? const MapLoadingScreen()
          : !_mbtilesAvailable
              ? MapErrorScreen(
                  errorKey: _mbtilesError,
                  errorArg: _mbtilesErrorArg,
                  onRetry: () {
                    setState(() {
                      _mbtilesLoading = true;
                      _mbtilesError = null;
                      _mbtilesErrorArg = null;
                    });
                    _initMBTiles();
                  },
                )
              : _buildMapView(),
      floatingActionButton: _isMarkingMode
          ? null
          : MapFabColumn(
              hasUserLocation: _userLocation != null,
              onCenterOnUser: _centerOnUser,
              activeSosEventId: _activeSosEventId,
              activeSosUrgency: _activeSosUrgency,
              onSosHoldActivated: _openTriageSheet,
              onCancelSos: _cancelSos,
              sosLabel: S.of(context)!.mapSosButton,
              sosActiveLabel: S.of(context)!.mapSosSentLabel,
              sosHoldHint: S.of(context)!.mapSosHoldHint,
            ),
    );
  }

  /// Stage 4d：SOS 長按 1.5s 達成後的動作 — 打開 TriageInput 抽屜。
  void _openTriageSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1a1a2e),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => TriageInputWidget(onSubmit: _onTriageSubmit),
    );
  }

  Widget _buildMapView() {
    // 建立用戶位置 Marker
    final List<Marker> locationMarkers = [];
    if (_userLocation != null) {
      locationMarkers.add(Marker(
        point: _userLocation!,
        width: 26,
        height: 26,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withValues(alpha: 0.5),
                blurRadius: 12,
                spreadRadius: 4,
              ),
            ],
          ),
        ),
      ));
    }

    // 建立精度圈
    final List<CircleMarker> accuracyCircles = [];
    if (_userLocation != null && _gpsAccuracy > 0) {
      accuracyCircles.add(CircleMarker(
        point: _userLocation!,
        radius: _gpsAccuracy,
        useRadiusInMeter: true,
        color: Colors.blue.withValues(alpha: 0.1),
        borderColor: Colors.blue.withValues(alpha: 0.3),
        borderStrokeWidth: 1,
      ));
    }

    // 預覽多邊形（標記模式）
    final List<Polygon> previewPolygons = [];
    if (_isMarkingMode && _markCenter != null) {
      final (_, _, previewColor) = _hazardInfo(context, _markType);
      previewPolygons.add(Polygon(
        points: _circlePolygonPoints(
          _markCenter!.latitude,
          _markCenter!.longitude,
          _markRadius,
        ),
        color: previewColor.withValues(alpha: 0.18),
        borderColor: previewColor,
        borderStrokeWidth: 2.5,
        pattern: const StrokePattern.dotted(),
      ));
    }

    // 預覽中心標記
    final List<Marker> previewMarkers = [];
    if (_isMarkingMode && _markCenter != null) {
      previewMarkers.add(Marker(
        point: _markCenter!,
        width: 40,
        height: 40,
        child: const Icon(Icons.location_on, color: Colors.white, size: 36),
      ));
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _center,
            initialZoom: 15.0,
            minZoom: 6.0,
            maxZoom: 18.0,
            onTap: _onMapTap,
            onLongPress: _onMapLongPress,
            onPositionChanged: (pos, hasGesture) {
              _refreshPoiMarkers(); // 任何地圖移動都刷新 POI（包含程式觸發）
            },
          ),
          children: [
            // 1. 離線向量圖磚底圖 (含自動 POI 顯示)
            if (_tileProviders != null && _mapTheme != null)
              VectorTileLayer(
                key: ValueKey('vt_$_themeGeneration'),
                tileProviders: _tileProviders!,
                theme: _mapTheme!,
                // sprites 暫時停用：sprite atlas PNG 解碼會觸發
                // Codec failed to produce an image 未處理例外，
                // 導致整個 tile 載入管線中斷 (tileset=null)
                sprites: null,
                layerMode: VectorTileLayerMode.vector,
              ),
            // 2. POI 圓點標記
            if (_poiMarkers.isNotEmpty)
              MarkerLayer(markers: _poiMarkers),
            // 3. GPS 精度圈
            if (accuracyCircles.isNotEmpty)
              CircleLayer(circles: accuracyCircles),
            // 4. 危險區域覆蓋層
            if (_hazardPolygons.isNotEmpty)
              PolygonLayer(polygons: _hazardPolygons),
            // 3.5 預覽標記多邊形
            if (previewPolygons.isNotEmpty)
              PolygonLayer(polygons: previewPolygons),
            // 4. 危險區域中心標記
            if (_hazardCenterMarkers.isNotEmpty)
              MarkerLayer(markers: _hazardCenterMarkers),
            // 4.5 預覽中心點
            if (previewMarkers.isNotEmpty) MarkerLayer(markers: previewMarkers),
            // 5. Mesh 事件標記（含 marker clustering）
            if (_eventMarkers.isNotEmpty)
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 60,
                  size: const Size(44, 44),
                  alignment: Alignment.center,
                  spiderfyCluster: false,
                  zoomToBoundsOnClick: true,
                  padding: const EdgeInsets.all(32),
                  markers: _eventMarkers,
                  polygonOptions: const PolygonOptions(
                    color: Color(0x22E8803B),
                    borderColor: Color(0x55E8803B),
                    borderStrokeWidth: 1,
                  ),
                  builder: (ctx, markers) {
                    // Stage 4d 優先級：SOS(hazard) > 避難(supply) > 醫療 > 其他
                    PinCategory top = PinCategory.life;
                    int topPri = PinPalette.clusterPriority(top);
                    for (final m in markers) {
                      final idx = _eventMarkers.indexOf(m);
                      if (idx < 0 || idx >= _eventMarkerCategories.length) {
                        continue;
                      }
                      final c = _eventMarkerCategories[idx];
                      final pri = PinPalette.clusterPriority(c);
                      if (pri < topPri) {
                        topPri = pri;
                        top = c;
                      }
                    }
                    return ClusterBubble(
                      count: markers.length,
                      highestPriority: top,
                    );
                  },
                ),
              ),
            // 6. 用戶位置
            if (locationMarkers.isNotEmpty)
              MarkerLayer(markers: locationMarkers),
          ],
        ),

        // Stage 4d：左上行政區/道路 overlay（離線反查 fallback 座標）。
        Positioned(
          top: 8,
          left: 8,
          child: MapLocationHeader(
            userLocation: _userLocation,
            district: null, // Stage 6+ 接 PoiQuery 反查；現階段走 fallback
            road: null,
          ),
        ),
        // 長按提示（非標記模式時顯示）
        if (!_isMarkingMode)
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  S.of(context)!.mapLongPressHint,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ),
        // 標記模式控制面板
        if (_isMarkingMode)
          MarkingPanel(
            isEditing: _editingHazardId != null,
            markType: _markType,
            markSeverity: _markSeverity,
            markRadius: _markRadius,
            descController: _markDescCtrl,
            isPublishing: _markPublishing,
            onTypeChanged: (v) => setState(() => _markType = v),
            onSeverityChanged: (v) => setState(() => _markSeverity = v),
            onRadiusChanged: (v) => setState(() => _markRadius = v),
            onCancel: _exitMarkingMode,
            onPublish: _publishOrUpdateMark,
            hazardInfoBuilder: _hazardInfo,
          ),
        // 圖例面板
        if (_showLegend && !_isMarkingMode) const MapLegendPanel(),
      ],
    );
  }

  // Stage 4d Round 2：_buildMarkingPanel / _buildLoadingScreen / _buildErrorScreen /
  // _buildLegendPanel / _legendItem 原於此處，已移至
  //   widgets/marking_panel.dart
  //   widgets/map_loading_screen.dart
  //   widgets/map_error_screen.dart
  //   widgets/map_legend_panel.dart
  // Legend 面板原使用 warning emoji 開頭的標題字串，違反 plan §六 L310，
  // 已換為 `Icons.warning_amber`。
}
